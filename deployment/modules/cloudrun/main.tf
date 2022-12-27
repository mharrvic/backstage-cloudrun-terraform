resource "google_cloud_run_service" "tm_engineering_map" {
  provider = google-beta

  name     = "backstage"
  location = var.region
  project  = var.project_id



  template {
    spec {
      containers {
        image = "${var.artifact_registry_url}/${var.project_id}/${var.artifact_repo}/${var.artifact_repo}:dev"
        env {
          name  = "BACKSTAGE_BASE_URL"
          value = ""
        }
        env {
          name  = "POSTGRES_HOST"
          value = "/cloudsql/${var.cloudsql_instance_connection_name}"
        }
        env {
          name  = "POSTGRES_USER"
          value = "postgres"
        }
        env {
          name  = "POSTGRES_PORT"
          value = "5432"
        }
        env {
          name = "POSTGRES_PASSWORD"
          value_from {
            secret_key_ref {
              name = "postgres-password"
              key  = "latest"
            }
          }
        }
      }

      service_account_name = var.service_account_email
    }

    metadata {
      annotations = {
        "run.googleapis.com/cloudsql-instances"   = var.cloudsql_instance_connection_name
        "run.googleapis.com/client-name"          = "terraform"
        "run.googleapis.com/vpc-access-connector" = "projects/${var.project_id}/locations/${var.region}/connectors/${var.vpc_connector_name}"
        "run.googleapis.com/vpc-access-egress"    = "all-traffic"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }


  autogenerate_revision_name = true
}





data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location = var.region
  project  = var.project_id
  service  = google_cloud_run_service.tm_engineering_map.name

  policy_data = data.google_iam_policy.noauth.policy_data
}
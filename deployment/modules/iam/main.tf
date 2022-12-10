resource "google_service_account" "backstage" {
  project      = var.project_id
  account_id   = "backstage"
  display_name = "Backstage"
}

resource "google_project_iam_member" "backstage" {
  project = var.project_id
  for_each = toset([
    "roles/cloudsql.admin",
    "roles/run.admin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/iam.serviceAccountUser",
    "roles/secretmanager.secretAccessor",
  ])
  role   = each.key
  member = "serviceAccount:${google_service_account.backstage.email}"
}


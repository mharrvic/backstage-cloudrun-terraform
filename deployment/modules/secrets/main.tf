resource "google_secret_manager_secret" "postgres_password" {
  secret_id = "postgres-password"

  labels = {
    label = "postgres-password"
  }

  replication {
    automatic = true
  }
}



resource "google_secret_manager_secret_version" "postgres_password" {
  secret = google_secret_manager_secret.postgres_password.id

  secret_data = var.postgres_password
}

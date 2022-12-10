resource "random_id" "user-password" {
  byte_length = 8
}

resource "google_sql_database" "backstage_db" {
  project  = var.backstage_project
  name     = google_sql_database_instance.backstage.name
  instance = google_sql_database_instance.backstage.name
}

resource "google_sql_database_instance" "backstage" {
  provider         = google-beta
  project          = var.backstage_project
  name             = "backstage-db"
  database_version = "POSTGRES_14"
  region           = var.region


  settings {
    tier = "db-g1-small"
    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
      require_ssl     = true
    }
  }

  deletion_protection = var.deletion_protection
}


resource "google_sql_user" "backstage_user" {
  name     = "postgres"
  instance = google_sql_database_instance.backstage.name
  password = var.user_password == "" ? random_id.user-password.hex : var.user_password
}
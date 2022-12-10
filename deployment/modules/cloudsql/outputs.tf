output "sql_instance_name" {
  value       = google_sql_database_instance.backstage.name
  description = "Backstage sql instance name"
}

output "sql_instance_connection_name" {
  value       = google_sql_database_instance.backstage.connection_name
  description = "Backstage sql instance connection name"
}

output "generated_user_password" {
  description = "The auto generated default user password if no input password was provided"
  value       = random_id.user-password.hex
  sensitive   = true
}

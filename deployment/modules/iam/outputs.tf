output "backstage_service_account_email" {
  value       = google_service_account.backstage.email
  description = "Backstage service account email"
}

output "backstage_service_account_id" {
  value       = google_service_account.backstage.id
  description = "Backstage service account id"
}
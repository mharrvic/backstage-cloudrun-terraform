output "network" {
  value       = module.vpc_network
  description = "Backstage VPC Network"
}

output "backstage_serverless_vpc_connector_name" {
  value       = google_vpc_access_connector.connector.name
  description = "Backstage Serverless VPC Connector"
}
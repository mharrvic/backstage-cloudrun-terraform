variable "project_id" {
  type        = string
  description = "GCP Project for Backstage"
}

variable "region" {
  type = string
}

variable "vpc_connector_name" {
  type        = string
  description = "Serverless VPC Connector"
}

variable "cloudsql_instance_name" {
  type        = string
  description = "Cloud SQL Instance Name"
}

variable "cloudsql_instance_connection_name" {
  type        = string
  description = "Cloud SQL Instance Connection Name"
}

variable "artifact_registry_url" {
  type        = string
  description = "Artifact Registry URL"
}

variable "artifact_repo" {
  type        = string
  description = "Artifact Registry Repo"
}

variable "service_account_email" {
  type        = string
  description = "Service Account Email"

}
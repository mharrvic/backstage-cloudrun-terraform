variable "project" {
  type        = string
  description = "The project ID to deploy to"
}

variable "region" {
  type        = string
  description = "The region to deploy to"
}

variable "zone" {
  type        = string
  description = "The zone to deploy to"
}

variable "artifact_registry_url" {
  type        = string
  description = "The URL of the Artifact Registry repository"
}

variable "artifact_registry_repository" {
  type        = string
  description = "The name of the Artifact Registry repository"
}

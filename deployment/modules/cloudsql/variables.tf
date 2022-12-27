variable "project_id" {
  type        = string
  description = "GCP Project for Backstage"
}


variable "region" {
  type = string
}


variable "network_id" {
  type = string
}


variable "deletion_protection" {
  type        = bool
  description = "Sets delete_protection of the Instance"
  default     = false
}


variable "user_password" {
  type        = string
  description = "The password for the default user. If not set, a random one will be generated and available in the generated_user_password output variable."
}

variable "region" {
  type        = string
  description = "The region to deploy to"
}

variable "project_id" {
  type        = string
  description = "The project ID to deploy to"
}

variable "subnet_ip" {
  type        = string
  description = "The IP and CIDR range of the subnet being created"
  default     = "10.0.0.0/16"
}


variable "network_name" {
  type        = string
  description = "Network name"
  default     = "backstage-main"
}
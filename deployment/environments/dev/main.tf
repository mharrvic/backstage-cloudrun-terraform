locals {
  env = "dev"
}

provider "google" {
  project = var.project
}

module "vpc" {
  source     = "../../modules/vpc"
  region     = var.region
  project_id = var.project
}

module "iam" {
  source       = "../../modules/iam"
  project_id   = var.project
}

module "cloudsql" {
  source            = "../../modules/cloudsql"
  region            = var.region
  project_id        = var.project
  network_id        = "projects/${var.project}/global/networks/${module.vpc.vpc_network.network_name}"
  depends_on = [
    module.vpc
  ]
}
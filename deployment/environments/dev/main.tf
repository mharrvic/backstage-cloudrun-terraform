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
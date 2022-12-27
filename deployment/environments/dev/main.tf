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

module "cloudsql" {
  source        = "../../modules/cloudsql"
  region        = var.region
  project_id    = var.project
  network_id    = "projects/${var.project}/global/networks/${module.vpc.vpc_network.network_name}"
  user_password = ""
  depends_on = [
    module.vpc, module.vpc.backstage_private_vpc_connection
  ]
}

module "secrets" {
  source            = "../../modules/secrets"
  postgres_password = module.cloudsql.generated_user_password
  depends_on = [
    module.cloudsql
  ]
}

module "iam" {
  source     = "../../modules/iam"
  project_id = var.project
}
module "cloudrun" {
  source                            = "../../modules/cloudrun"
  project_id                        = var.project
  region                            = var.region
  vpc_connector_name                = module.vpc.backstage_serverless_vpc_connector_name
  artifact_registry_url             = var.artifact_registry_url
  artifact_repo                     = var.artifact_registry_repository
  cloudsql_instance_name            = module.cloudsql.sql_instance_name
  cloudsql_instance_connection_name = module.cloudsql.sql_instance_connection_name
  service_account_email             = module.iam.backstage_service_account_email


  depends_on = [
    module.cloudsql, module.vpc, module.secrets
  ]
}
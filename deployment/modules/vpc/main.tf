module "vpc_network" {
  source  = "terraform-google-modules/network/google"
  version = "~> 6.0"

  network_name = var.network_name
  project_id   = var.project_id

  subnets = [
      {
        subnet_name           = "${module.vpc_network.network_name}-subnetwork"
        subnet_ip             = var.subnet_ip
        subnet_region         = var.region
        subnet_private_access = "true"
        subnet_flow_logs      = "false"
      }
    ]
}

resource "google_vpc_access_connector" "connector" {
  name          = "backstage-connector"
  project       = var.project_id
  region        = var.region
  ip_cidr_range = var.serverless_vpc_ip_cidr_range
  network       = module.vpc_network.network_name
}

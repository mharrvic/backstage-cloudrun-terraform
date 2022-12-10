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

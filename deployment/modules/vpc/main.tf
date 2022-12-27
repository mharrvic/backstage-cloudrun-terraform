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

resource "google_compute_global_address" "backstage_private_ip_address" {
  provider = google-beta

  project       = var.project_id
  name          = "backstage-private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = "projects/${var.project_id}/global/networks/${module.vpc_network.network_name}"
}

resource "google_service_networking_connection" "backstage_private_vpc_connection" {
  provider = google-beta

  network                 = "projects/${var.project_id}/global/networks/${module.vpc_network.network_name}"
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.backstage_private_ip_address.name]
}

resource "google_vpc_access_connector" "connector" {
  name          = "backstage-connector"
  project       = var.project_id
  region        = var.region
  ip_cidr_range = var.serverless_vpc_ip_cidr_range
  network       = module.vpc_network.network_name
}

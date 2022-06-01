provider "google" {
  project = var.gcp_project_id
}
provider "google-beta" {
  project = var.gcp_project_id
}


module "project" {
  source              = "terraform-google-modules/project-factory/google"
  version             = "12.0.0"
  billing_account     = var.billing_account
  org_id              = var.org_id
  name                = var.gcp_project_id
  auto_create_network = false
  folder_id           = var.folder_id

  activate_apis = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudtrace.googleapis.com",
    "meshca.googleapis.com",
    "meshtelemetry.googleapis.com",
    "meshconfig.googleapis.com",
    "iamcredentials.googleapis.com",
    "gkeconnect.googleapis.com",
    "gkehub.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "stackdriver.googleapis.com",
    "sts.googleapis.com",
    "anthos.googleapis.com",
  ]
}


# subnet 1 network breakdown https://www.davidc.net/sites/default/subnets/subnets.html?network=10.10.0.0&mask=19&division=5.30
# subnet 2 network breakdown https://www.davidc.net/sites/default/subnets/subnets.html?network=10.10.32.0&mask=19&division=5.30
module "network" {
  source       = "terraform-google-modules/network/google"
  version      = "5.0.0"
  network_name = "vpc01"
  project_id   = module.project.project_id
  subnets      = [
    {
      subnet_name           = "c1-nodes-subnet"
      subnet_ip             = "10.10.0.0/21" # 2046 usable ips for nodes
      subnet_region         = "us-west1"
      subnet_private_access = "true"
    },
    {
      subnet_name           = "c2-nodes-subnet"
      subnet_ip             = "10.10.32.0/21" # 2046 usable ips for nodes
      subnet_region         = "us-east1"
      subnet_private_access = "true"
    },
  ]
  secondary_ranges = {
    "c1-nodes-subnet" : [
      { range_name = "c1-pods-range", ip_cidr_range = "10.10.16.0/20" }, # 4094 usable ips for pods
      { range_name = "c1-svc-range", ip_cidr_range = "10.10.8.0/21" } # 2046 usable ips for services
    ],
    "c2-nodes-subnet" : [
      { range_name = "c2-pods-range", ip_cidr_range = "10.10.48.0/20" }, # 4094 usable ips for pods
      { range_name = "c2-svc-range", ip_cidr_range = "10.10.40.0/21" } # 2046 usable ips for services
    ]
  }

  firewall_rules = [{
    name        = "allow-all-intra"
    description = "Allow Pod to Pod connectivity"
    direction   = "INGRESS"
    ranges      = ["10.10.0.0/18"]
    allow = [{
      protocol = "tcp"
      ports    = ["0-65535"]
    }]
  }]

}

#Enable the hub mesh in the fleet project
locals {
  hub_mesh_enable_command = "gcloud beta container hub mesh enable --project=${var.gcp_project_id}"
}
resource "null_resource" "exec_gke1_mesh" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = local.hub_mesh_enable_command
  }
  triggers = {
    command_sha = sha1(local.hub_mesh_enable_command)
  }
}
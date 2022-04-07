#must be applied after project/network
module "cluster2" {
  source  = "terraform-google-modules/kubernetes-engine/google"
  version = "20.0.0"

  project_id               = module.project.project_id
  name                     = "${var.gcp_project_id}-cluster2"
  network                  = "vpc01"
  region                   = "us-east1"
  subnetwork               = "c2-nodes-subnet"
  ip_range_pods            = "c2-pods-range"
  ip_range_services        = "c2-svc-range"
  remove_default_node_pool = true
  cluster_resource_labels = {
    mesh_id = local.mesh_id
  }
  identity_namespace = local.workload_pool
  node_pools         = [
    {
      name               = "general-pool"
      machine_type       = "e2-standard-2"
      min_count          = 1
      max_count          = 2
      disk_size_gb       = 100
      disk_type          = "pd-standard"
      preemptible        = false
      initial_node_count = 1
    },
  ]
  depends_on = [module.project]
}

#register this cluster as a member of the fleet
resource "google_gke_hub_membership" "cluster2_membership" {
  membership_id = "${var.gcp_project_id}-cluster2"
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${module.cluster2.cluster_id}"
    }
  }
  authority {
    issuer = "https://container.googleapis.com/v1/${module.cluster1.cluster_id}"
  }

  provider   = google-beta
  depends_on = [module.cluster2]
}


#install ASM with managed control plane
locals {
  cluster2_hub_mesh_update_command = "gcloud alpha container hub mesh update --control-plane automatic --membership ${var.gcp_project_id}-cluster2 --project=${var.gcp_project_id}"
}
resource "null_resource" "cluster2_hub_mesh_update" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = local.cluster2_hub_mesh_update_command
  }
  triggers = {
    command_sha = sha1(local.cluster2_hub_mesh_update_command)
  }
  depends_on = [module.cluster2]
}
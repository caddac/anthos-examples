module "cluster1" {
  source  = "terraform-google-modules/kubernetes-engine/google"
  version = "20.0.0"

  project_id        = module.project.project_id
  name              = "${var.gcp_project_id}-cluster1"
  network           = "vpc01"
  region            = "us-west1"
  subnetwork        = "c1-nodes-subnet"
  ip_range_pods     = "c1-pods-range"
  ip_range_services = "c1-svc-range"
  remove_default_node_pool = true
  cluster_autoscaling = {
    enabled=true
    max_cpu_cores = 12
    min_cpu_cores = 3
    max_memory_gb = 48
    min_memory_gb = 12
    gpu_resources = []
  }
  cluster_resource_labels = {
    mesh_id = local.mesh_id
  }
  identity_namespace = local.workload_pool
  node_pools = [
    {
      name               = "general-pool"
      machine_type       = "e2-standard-2"
      min_count          = 1
      max_count          = 2
      disk_size_gb       = 100
      disk_type          = "pd-standard"
      preemptible        = true
      initial_node_count = 1
    },
  ]
}

#register this cluster as a member of the fleet
resource "google_gke_hub_membership" "cluster1_membership" {
  membership_id = "${var.gcp_project_id}-cluster1"
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${module.cluster1.cluster_id}"
    }
  }
  authority {
    issuer = "https://container.googleapis.com/v1/${module.cluster1.cluster_id}"
  }
  provider = google-beta
  depends_on = [module.cluster1]
}


#install ASM with managed control plane
locals {
  cluster1_hub_mesh_update_command = "gcloud alpha container hub mesh update --control-plane automatic --membership ${var.gcp_project_id}-cluster1 --project=${var.gcp_project_id}"
}
resource "null_resource" "cluster1_hub_mesh_update" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = local.cluster1_hub_mesh_update_command
  }
  triggers = {
    command_sha = sha1(local.cluster1_hub_mesh_update_command)
  }
  depends_on = [module.cluster1]
}

locals {
  mesh_id = "proj-${module.project.project_number}"
  workload_pool = "${module.project.project_id}.svc.id.goog"
}
locals {
}

variable "gcp_project_id" {
}
variable "billing_account" {
}
variable "org_id" {
}
variable "folder_id" {
  default = ""
  description = "If you have a folder id, add it here. Leave blank for no folder"
}
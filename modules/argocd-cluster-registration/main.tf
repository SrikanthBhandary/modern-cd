data "external" "cluster" {

  program = [
    "${path.module}/scripts/get_cluster_info.sh",
    "${var.cluster_name}"
  ]
}
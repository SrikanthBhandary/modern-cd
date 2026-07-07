module "kind" {
  source = "../../modules/kind-cluster"

  cluster_name = var.cluster_name
  config_file  = var.config_file
}
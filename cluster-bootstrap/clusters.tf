module "demo_cluster" {
  source       = "../modules/kind-cluster"
  cluster_name = var.clusters.hub
  config_file  = var.hub_config_file
}

module "spoke_1" {
  source       = "../modules/kind-cluster"
  cluster_name = var.clusters.spoke1
  config_file  = var.cluster_config_file
}

module "spoke_2" {
  source       = "../modules/kind-cluster"
  cluster_name = var.clusters.spoke2
  config_file  = var.cluster_config_file
}
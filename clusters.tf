module "demo_cluster" {
  source       = "./modules/kind-cluster"
  cluster_name = var.clusters.hub
  config_file  = var.cluster_config_file
}

module "spoke_1" {
  source       = "./modules/kind-cluster"
  cluster_name = var.clusters.spoke1
  config_file  = var.cluster_config_file
}

module "spoke_2" {
  source       = "./modules/kind-cluster"
  cluster_name = var.clusters.spoke2
  config_file  = var.cluster_config_file
}

# Each registration module is self-contained: it creates the argocd-manager
# ServiceAccount + ClusterRoleBinding on the target cluster, then reads back
# the connection info ArgoCD needs to add that cluster as an external target.
module "register_spoke1" {
  source       = "./modules/argocd-cluster-registration"
  cluster_name = var.clusters.spoke1
  depends_on   = [module.spoke_1]

  providers = {
    kubernetes.target = kubernetes.spoke1
  }
}

module "register_spoke2" {
  source       = "./modules/argocd-cluster-registration"
  cluster_name = var.clusters.spoke2
  depends_on   = [module.spoke_2]

  providers = {
    kubernetes.target = kubernetes.spoke2
  }
}

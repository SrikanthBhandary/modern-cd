terraform {
  required_providers {
    kubernetes = {
      source                = "hashicorp/kubernetes"
      configuration_aliases = [kubernetes.target]
    }
  }
}

resource "kubernetes_service_account_v1" "argocd_manager" {
  provider = kubernetes.target

  metadata {
    name      = "argocd-manager"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding_v1" "argocd_manager" {
  provider = kubernetes.target

  metadata {
    name = "argocd-manager"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.argocd_manager.metadata[0].name
    namespace = "kube-system"
  }
}

data "external" "cluster" {
  depends_on = [kubernetes_cluster_role_binding_v1.argocd_manager]

  program = [
    "${path.module}/scripts/get_cluster_info.sh",
    var.cluster_name
  ]
}

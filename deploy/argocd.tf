# Each registration module is self-contained: it creates the argocd-manager
# ServiceAccount + ClusterRoleBinding on the target cluster, then reads back
# the connection info ArgoCD needs to add that cluster as an external target.
module "register_spoke1" {
  source       = "../modules/argocd-cluster-registration"
  cluster_name = var.clusters.spoke1
  providers = {
    kubernetes.target = kubernetes.spoke1
  }
}

module "register_spoke2" {
  source       = "../modules/argocd-cluster-registration"
  cluster_name = var.clusters.spoke2

  providers = {
    kubernetes.target = kubernetes.spoke2
  }
}

resource "helm_release" "argocd" {
  provider         = helm.hub
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  values = [
    yamlencode({
      configs = {
        params = {
          "server.insecure" = true
        }
      }
    })
  ]

  timeout = 600
}

resource "kubernetes_secret_v1" "cluster_spoke1" {
  provider = kubernetes.hub

  metadata {
    name      = "spoke1"
    namespace = "argocd"

    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }

  type = "Opaque"

  data = {
    name   = "spoke1"
    server = module.register_spoke1.server

    config = jsonencode({
      bearerToken = module.register_spoke1.token

      tlsClientConfig = {
        insecure = false
        caData   = module.register_spoke1.ca
      }
    })
  }
  depends_on = [helm_release.argocd]
}

resource "kubernetes_secret_v1" "cluster_spoke2" {
  provider = kubernetes.hub

  metadata {
    name      = "spoke2"
    namespace = "argocd"

    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }

  type = "Opaque"

  data = {
    name   = "spoke2"
    server = module.register_spoke2.server

    config = jsonencode({
      bearerToken = module.register_spoke2.token

      tlsClientConfig = {
        insecure = false
        caData   = module.register_spoke2.ca
      }
    })
  }

  depends_on = [helm_release.argocd]
}
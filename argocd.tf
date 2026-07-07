resource "helm_release" "argocd" {
  depends_on       = [module.demo_cluster]
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

resource "helm_release" "argocd_spoke_1" {
  depends_on       = [module.spoke_1]
  provider         = helm.spoke1
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  timeout = 600
}

resource "helm_release" "argocd_spoke_2" {
  depends_on       = [module.spoke_2]
  provider         = helm.spoke2
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

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
}

resource "kubernetes_manifest" "guestbook_appset" {
  provider = kubernetes.hub

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"

    metadata = {
      name      = "guestbook"
      namespace = "argocd"
    }

    spec = {
      generators = [
        {
          clusters = {}
        }
      ]

      template = {
        metadata = {
          name = "{{name}}-guestbook"
        }

        spec = {
          project = "default"

          source = {
            repoURL        = "https://github.com/argoproj/argocd-example-apps.git"
            targetRevision = "HEAD"
            path           = "guestbook"
          }

          destination = {
            server    = "{{server}}"
            namespace = "default"
          }

          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }

            syncOptions = [
              "CreateNamespace=true"
            ]
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.argocd,
    kubernetes_secret_v1.cluster_spoke1,
    kubernetes_secret_v1.cluster_spoke2
  ]
}

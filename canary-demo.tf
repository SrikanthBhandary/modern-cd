# Deploys the canary-demo Rollout (see apps/canary-demo/) to every cluster
# registered with the hub's ArgoCD - same "clusters" generator pattern used
# by the guestbook ApplicationSet in argocd.tf, but sourced from this repo
# instead of the upstream argocd-example-apps repo.
resource "kubernetes_manifest" "canary_demo_appset" {
  provider = kubernetes.hub

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"

    metadata = {
      name      = "canary-demo"
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
          name = "{{name}}-canary-demo"
        }

        spec = {
          project = "default"

          source = {
            repoURL        = "https://github.com/SrikanthBhandary/modern-cd.git"
            targetRevision = "HEAD"
            path           = "apps/canary-demo"
          }

          destination = {
            server    = "{{server}}"
            namespace = "canary-demo"
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
    helm_release.argo_rollouts_hub,
    helm_release.argo_rollouts_spoke1,
    helm_release.argo_rollouts_spoke2,
    kubernetes_secret_v1.cluster_spoke1,
    kubernetes_secret_v1.cluster_spoke2
  ]
}

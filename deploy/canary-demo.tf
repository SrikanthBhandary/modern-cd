resource "helm_release" "canary_demo_appset" {
  provider = helm.hub

  name      = "canary-demo-appset"
  chart     = "../charts/canary-demo-appset"
  namespace = "argocd"

  depends_on = [
    helm_release.argo_rollouts_hub,
    kubernetes_secret_v1.cluster_spoke1,
    kubernetes_secret_v1.cluster_spoke2
  ]
}
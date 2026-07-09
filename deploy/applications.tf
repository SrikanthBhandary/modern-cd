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


resource "helm_release" "monitoring_stack" {
  provider = helm.hub
  name      = "monitoring-stack"
  chart     = "../charts/monitoring"
  namespace = "argocd"

  values = [
    file("../charts/monitoring/values.yaml")
  ]


  depends_on = [
    helm_release.argo_rollouts_hub,
    kubernetes_secret_v1.cluster_spoke1,
    kubernetes_secret_v1.cluster_spoke2
  ]
}

resource "helm_release" "progressive_demo" {
  provider = helm.hub
  name      = "progressive-demo"
  chart     = "../charts/progressive-demo-appset"
  namespace = "argocd"

  values = [
    file("../charts/progressive-demo-appset/values.yaml")
  ]


  depends_on = [
    helm_release.argo_rollouts_hub,
    kubernetes_secret_v1.cluster_spoke1,
    kubernetes_secret_v1.cluster_spoke2
  ]
}


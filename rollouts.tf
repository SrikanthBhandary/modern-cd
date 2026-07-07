resource "helm_release" "argo_rollouts_hub" {
  depends_on       = [module.demo_cluster]
  provider         = helm.hub
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  namespace        = "argo-rollouts"
  create_namespace = true
}

resource "helm_release" "argo_rollouts_spoke1" {
  depends_on       = [module.spoke_1]
  provider         = helm.spoke1
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  namespace        = "argo-rollouts"
  create_namespace = true
}

resource "helm_release" "argo_rollouts_spoke2" {
  depends_on       = [module.spoke_2]
  provider         = helm.spoke2
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  namespace        = "argo-rollouts"
  create_namespace = true
}

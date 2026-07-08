# TODO : move this as the applicationset.action
resource "helm_release" "argo_rollouts_hub" {  
  provider         = helm.hub
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  namespace        = "argo-rollouts"
  create_namespace = true
  values = [    
    file("${path.module}/../config/dev/argo_values.yaml")
  ]
}

resource "helm_release" "argo_rollouts_spoke1" {
  provider         = helm.spoke1
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  namespace        = "argo-rollouts"
  create_namespace = true
  values = [
    file("${path.module}/../config/dev/argo_values.yaml")
  ]
}

resource "helm_release" "argo_rollouts_spoke2" {
  provider         = helm.spoke2
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  namespace        = "argo-rollouts"
  create_namespace = true
  values = [
    file("${path.module}/../config/dev/argo_values.yaml")
  ]
}

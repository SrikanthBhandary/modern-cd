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


resource "kubernetes_cluster_role_v1" "argo_rollouts_gatewayapi" {
  provider = kubernetes.hub

  metadata {
    name = "argo-rollouts-gatewayapi"
  }

  rule {
    api_groups = ["gateway.networking.k8s.io"]
    resources  = ["httproutes"]

    verbs = [
      "get",
      "list",
      "watch",
      "update",
      "patch",
    ]
  }

  rule {
    api_groups = [""]
    resources  = ["services"]

    verbs = [
      "get",
      "list",
      "watch",
    ]
  }
}

resource "kubernetes_cluster_role_binding_v1" "argo_rollouts_gatewayapi" {
  provider = kubernetes.hub

  metadata {
    name = "argo-rollouts-gatewayapi"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.argo_rollouts_gatewayapi.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "argo-rollouts"
    namespace = "argo-rollouts"
  }
}
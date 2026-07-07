resource "kubectl_manifest" "gateway_api" {
  provider   = kubectl.hub
  yaml_body  = file("gateway/gateway-api.yaml")
  depends_on = [module.demo_cluster]
}

resource "helm_release" "envoy_gateway" {
  provider = helm.hub

  name      = "envoy-gateway"
  namespace = "envoy-gateway-system"

  create_namespace = true

  repository = "oci://docker.io/envoyproxy"
  chart      = "gateway-helm"

  depends_on = [
    kubectl_manifest.gateway_api
  ]
}

resource "kubernetes_manifest" "main_gateway" {
  provider = kubernetes.hub

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"

    metadata = {
      name      = "main-gateway"
      namespace = "argocd"
    }

    spec = {
      gatewayClassName = "eg"

      listeners = [
        {
          name     = "http"
          protocol = "HTTP"
          port     = 80
        }
      ]
    }
  }

  depends_on = [
    helm_release.envoy_gateway
  ]
}

resource "kubernetes_manifest" "envoy_gateway_class" {
  provider = kubernetes.hub

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "GatewayClass"

    metadata = {
      name = "eg"
    }

    spec = {
      controllerName = "gateway.envoyproxy.io/gatewayclass-controller"
    }
  }

  depends_on = [
    helm_release.envoy_gateway
  ]
}

resource "kubernetes_manifest" "argocd_route" {
  provider = kubernetes.hub

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"

    metadata = {
      name      = "argocd"
      namespace = "argocd"
    }

    spec = {
      parentRefs = [
        {
          name = "main-gateway"
        }
      ]

      rules = [
        {
          backendRefs = [
            {
              name = "argocd-server"
              port = 80
            }
          ]
        }
      ]
    }
  }

  depends_on = [
    kubernetes_manifest.main_gateway
  ]
}

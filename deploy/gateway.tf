resource "helm_release" "envoy_gateway_crd" {
  provider = helm.hub

  name      = "envoy-gateway-crd"
  chart     = "../charts/envoy-gateway-crd"

  namespace = "argocd"     
  depends_on = [helm_release.argocd ] 
}

resource "helm_release" "envoy_gateway_bootstrap" {
  provider = helm.hub

  name      = "envoy-gateway-bootstrap"
  chart     = "../charts/envoy-gateway-bootstrap"

  namespace = "argocd"  
  create_namespace = true
  depends_on = [helm_release.argocd, helm_release.envoy_gateway_crd] 
}

resource "helm_release" "gateway_routes" {
  provider = helm.hub

  name      = "gateway-routes"
  chart     = "../charts/gateway-routes"
  namespace = "argocd"

  depends_on = [
    helm_release.envoy_gateway_bootstrap, helm_release.envoy_gateway_crd
  ]
  create_namespace = true  
  values = [
    file("../charts/gateway-routes/values.yaml")
  ]
}

# TODO: install envory for other clusters also
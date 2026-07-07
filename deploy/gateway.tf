# resource "kubernetes_manifest" "envoy_gateway_application" {
#   provider = kubernetes.hub

#   manifest = {
#     apiVersion = "argoproj.io/v1alpha1"
#     kind       = "Application"

#     metadata = {
#       name      = "envoy-gateway"
#       namespace = "argocd"
#     }

#     spec = {
#       project = "default"

#       source = {
#         chart          = "gateway-helm"
#         repoURL        = "docker.io/envoyproxy"
#         targetRevision = "v1.8.2"
#       }

#       destination = {
#         namespace = "envoy-gateway-system"
#         server    = "https://kubernetes.default.svc"
#       }

#       syncPolicy = {
#         syncOptions = [
#           "CreateNamespace=true",
#           "ServerSideApply=true"
#         ]

#         automated = {
#           prune    = true
#           selfHeal = true
#         }
#       }
#     }
#   }
# }
 
# resource "kubernetes_manifest" "main_gateway" {
#   provider = kubernetes.hub

#   manifest = {
#     apiVersion = "gateway.networking.k8s.io/v1"
#     kind       = "Gateway"

#     metadata = {
#       name      = "main-gateway"
#       namespace = "argocd"
#     }

#     spec = {
#       gatewayClassName = "eg"

#       listeners = [
#         {
#           name     = "http"
#           protocol = "HTTP"
#           port     = 80

#           allowedRoutes = {
#             namespaces = {
#               from = "All"
#             }
#           }
#         }
#       ]
#     }
#   }

#   depends_on = [
#     kubernetes_manifest.envoy_gateway_application, kubernetes_manifest.envoy_gateway_class
#   ]
# }

# resource "kubernetes_manifest" "envoy_gateway_class" {
#   provider = kubernetes.hub

#   manifest = {
#     apiVersion = "gateway.networking.k8s.io/v1"
#     kind       = "GatewayClass"

#     metadata = {
#       name = "eg"
#     }

#     spec = {
#       controllerName = "gateway.envoyproxy.io/gatewayclass-controller"
#     }
#   }

#   depends_on = [
#     kubernetes_manifest.envoy_gateway_application
#   ]
# }

# resource "kubernetes_manifest" "argocd_route" {
#   provider = kubernetes.hub

#   manifest = {
#     apiVersion = "gateway.networking.k8s.io/v1"
#     kind       = "HTTPRoute"

#     metadata = {
#       name      = "argocd"
#       namespace = "argocd"
#     }

#     spec = {
#       parentRefs = [
#         {
#           name = "main-gateway"
#         }
#       ]

#       rules = [
#         {
#           backendRefs = [
#             {
#               name = "argocd-server"
#               port = 80
#             }
#           ]
#         }
#       ]
#     }
#   }

#   depends_on = [
#     kubernetes_manifest.main_gateway
#   ]
# }


# resource "kubernetes_manifest" "canary_route" {
#   provider = kubernetes.hub

#   manifest = {
#     apiVersion = "gateway.networking.k8s.io/v1"
#     kind       = "HTTPRoute"

#     metadata = {
#       name      = "canary-demo"
#       namespace = "canary-demo"
#     }

#     spec = {
#       parentRefs = [
#         {
#           name      = "main-gateway"
#           namespace = "argocd"
#         }
#       ]

#       hostnames = [
#         "canary.local"
#       ]

#       rules = [
#         {
#           backendRefs = [
#             {
#               name   = "canary-demo-stable"
#               port   = 80
#               weight = 100
#             },
#             {
#               name   = "canary-demo-canary"
#               port   = 80
#               weight = 0
#             }
#           ]
#         }
#       ]
#     }
#   }
# }

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
  
}

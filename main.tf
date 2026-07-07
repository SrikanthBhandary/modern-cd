module "demo_cluster" {
  source = "./modules/kind-cluster"
  cluster_name = "demo"
  config_file  = "config/dev/config.yaml"
}

module "spoke_1" {
  source = "./modules/kind-cluster"
  cluster_name = "spoke-1"
  config_file  = "config/dev/config.yaml"
}

module "register_spoke1" {
  source = "./modules/argocd-cluster-registration"
  cluster_name = "spoke-1"
  depends_on = [module.spoke_1, kubernetes_service_account_v1.argocd_manager]
}


resource "kubernetes_service_account_v1" "argocd_manager" {
  provider = kubernetes.spoke1

  metadata {
    name      = "argocd-manager"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding_v1" "argocd_manager" {
  provider = kubernetes.spoke1

  metadata {
    name = "argocd-manager"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.argocd_manager.metadata[0].name
    namespace = "kube-system"
  }
}


module "spoke_2" {
  source = "./modules/kind-cluster"
  cluster_name = "spoke-2"
  config_file  = "config/dev/config.yaml"
}

resource "helm_release" "argocd" {
  depends_on = [module.demo_cluster]
  provider = helm.hub
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
  depends_on = [module.spoke_1]
  provider = helm.spoke1
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  timeout = 600
}

resource "helm_release" "argocd_spoke_2" {
  depends_on = [module.spoke_2]
  provider = helm.spoke2
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
      bearerToken =  module.register_spoke1.token

      tlsClientConfig = {
        insecure = false
        caData   =  module.register_spoke1.ca
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
    kubernetes_secret_v1.cluster_spoke1
  ]
}


resource "kubectl_manifest" "gateway_api" {
  provider = kubectl.hub
  yaml_body = file("gateway/gateway-api.yaml")
  depends_on = [ module.demo_cluster ]

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

    kind = "Gateway"

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
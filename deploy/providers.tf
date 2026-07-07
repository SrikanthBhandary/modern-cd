terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.4.1"
    }
  }
}

locals {
  kubeconfig = pathexpand("~/.kube/config")

  # Define contexts as a map for cleaner access
  contexts = {
    hub    = "kind-hub"
    spoke1 = "kind-spoke-1"
    spoke2 = "kind-spoke-2"
  }
}

# 1. Define Kubernetes Providers
provider "kubernetes" {
  alias          = "hub"
  config_path    = local.kubeconfig
  config_context = local.contexts.hub
}

provider "kubernetes" {
  alias          = "spoke1"
  config_path    = local.kubeconfig
  config_context = local.contexts.spoke1
}

provider "kubernetes" {
  alias          = "spoke2"
  config_path    = local.kubeconfig
  config_context = local.contexts.spoke2
}

# 2. Define Helm Providers (referencing the kubernetes provider blocks)
provider "helm" {
  alias = "hub"
  kubernetes = {
    config_path    = local.kubeconfig
    config_context = local.contexts.hub
  }
}

provider "helm" {
  alias = "spoke1"
  kubernetes = {
    config_path    = local.kubeconfig
    config_context = local.contexts.spoke1
  }
}

provider "helm" {
  alias = "spoke2"
  kubernetes = {
    config_path    = local.kubeconfig
    config_context = local.contexts.spoke2
  }
}

# 3. Define Kubectl Providers
provider "kubectl" {
  alias          = "hub"
  config_path    = local.kubeconfig
  config_context = local.contexts.hub
}
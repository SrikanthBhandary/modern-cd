# modern-cd

Terraform project that spins up a **hub-and-spoke Kubernetes setup on [kind](https://kind.sigs.k8s.io/)**, installs ArgoCD on each cluster, registers the spoke clusters with the hub's ArgoCD, and exposes ArgoCD through an Envoy Gateway (Gateway API).

## Architecture

```
                    ┌─────────────────────┐
                    │   hub (demo)        │
                    │  - ArgoCD (hub)     │
                    │  - Envoy Gateway    │
                    │  - Gateway API      │
                    └──────────┬──────────┘
                     registers │ registers
                ┌──────────────┴──────────────┐
                ▼                             ▼
      ┌───────────────────┐         ┌───────────────────┐
      │  spoke-1           │         │  spoke-2           │
      │  - ArgoCD (spoke)  │         │  - ArgoCD (spoke)  │
      └───────────────────┘         └───────────────────┘
```

- The **hub** cluster (`demo`) runs the main ArgoCD instance, plus Envoy Gateway and a Gateway API `HTTPRoute` that exposes the ArgoCD UI.
- Each **spoke** cluster (`spoke-1`, `spoke-2`) runs its own local ArgoCD, and is also registered as an external cluster on the hub's ArgoCD (so the hub can deploy applications to it via an `ApplicationSet`).
- A sample `guestbook` `ApplicationSet` demonstrates deploying the same app across every registered cluster.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5
- [kind](https://kind.sigs.k8s.io/) and [kubectl](https://kubernetes.io/docs/tasks/tools/) installed and on your `PATH`
- [jq](https://jqlang.org/) (used by the cluster-registration script)
- Docker (kind runs clusters as Docker containers)

## Repo structure

```
.
├── providers.tf     # Terraform + Kubernetes/Helm/kubectl provider configuration
├── variables.tf      # Cluster names and shared kind config path
├── clusters.tf        # kind-cluster modules + ArgoCD spoke registration
├── argocd.tf           # ArgoCD helm releases, cluster secrets, guestbook ApplicationSet
├── gateway.tf           # Envoy Gateway install + Gateway API routing for ArgoCD
├── config/dev/           # kind cluster config shared by hub + spokes
├── gateway/                # Gateway API CRDs (applied via kubectl_manifest)
└── modules/
    ├── kind-cluster/                    # Creates/destroys a kind cluster via local-exec
    └── argocd-cluster-registration/     # Creates argocd-manager RBAC on a target cluster
                                          # and reads back its connection details
```

### Modules

**`modules/kind-cluster`**
Creates a kind cluster using `kind create cluster` via a `local-exec` provisioner, and tears it down with `kind delete cluster` on destroy. Takes `cluster_name` and `config_file` as inputs.

**`modules/argocd-cluster-registration`**
Given a `cluster_name` and a `kubernetes` provider alias (passed in via `configuration_aliases`), this module:
1. Creates an `argocd-manager` ServiceAccount and a `cluster-admin` ClusterRoleBinding on the target cluster.
2. Runs `scripts/get_cluster_info.sh`, which generates a short-lived token for that ServiceAccount and reads the cluster's API server address and CA certificate.
3. Exposes `server`, `token`, and `ca` as outputs, which the root module uses to build the ArgoCD cluster-registration `Secret` on the hub.

## Usage

```bash
terraform init
terraform plan
terraform apply
```

This will, in order:
1. Create the `demo`, `spoke-1`, and `spoke-2` kind clusters.
2. Install ArgoCD on all three.
3. Register `spoke-1` and `spoke-2` with the hub's ArgoCD.
4. Install Envoy Gateway on the hub and expose the ArgoCD UI via an `HTTPRoute`.
5. Deploy the sample `guestbook` app to every registered cluster via the `ApplicationSet`.

To tear everything down:

```bash
terraform destroy
```

## Notes / known limitations

- `helm_release.argocd` sets `server.insecure = true`, which disables TLS on the hub's ArgoCD server. This is fine for local kind clusters but should not be carried into any environment reachable outside your machine.
- Provider blocks (`kubernetes`, `helm`) are duplicated once per cluster (hub/spoke1/spoke2) because Terraform provider blocks don't support `for_each`/`count`. Adding a fourth cluster means adding a fourth set of provider blocks by hand.
- The `kind-cluster` module has no `output` values currently — nothing downstream depends on it yet.

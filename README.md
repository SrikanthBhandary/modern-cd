# modern-cd

Two Terraform projects that spin up a **hub-and-spoke Kubernetes setup on [kind](https://kind.sigs.k8s.io/)**, install ArgoCD on each cluster, register the spoke clusters with the hub's ArgoCD, expose ArgoCD (and a sample canary app) through an Envoy Gateway (Gateway API), and use Argo Rollouts to demo canary deployments across the hub and both spokes.

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

- The **hub** cluster (`hub`) runs the main ArgoCD instance, plus Envoy Gateway and Gateway API `HTTPRoute`s that expose the ArgoCD UI (`argocd.local`) and the canary demo (`canary.local`).
- Each **spoke** cluster (`spoke-1`, `spoke-2`) is registered as an external cluster on the hub's ArgoCD (so the hub can deploy applications to it via an `ApplicationSet`), and also runs its own Argo Rollouts controller.
- A `canary-demo-appset` `ApplicationSet` deploys the sample canary app (an Argo `Rollout` with `stable`/`canary` Services) to every registered cluster, so you can practice canary promotions via Argo Rollouts.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5
- [kind](https://kind.sigs.k8s.io/) and [kubectl](https://kubernetes.io/docs/tasks/tools/) installed and on your `PATH`
- [jq](https://jqlang.org/) (used by the cluster-registration script)
- Docker (kind runs clusters as Docker containers)

## Repo structure

The project is split into **two independent Terraform projects** that must be run one after the other — `cluster-bootstrap/` creates the kind clusters, and `deploy/` installs everything on top of them.

```
.
├── cluster-bootstrap/       # Terraform project #1: creates the hub + spoke kind clusters
│   ├── providers.tf           # Kubernetes/Helm/kubectl provider configuration (per cluster)
│   ├── variables.tf            # Cluster names + kind config file paths
│   └── clusters.tf              # kind-cluster modules (hub, spoke-1, spoke-2)
├── deploy/                  # Terraform project #2: installs ArgoCD, gateway, and the demo app
│   ├── providers.tf            # Provider blocks pointed at the kind-* contexts created above
│   ├── variables.tf             # Cluster name overrides
│   ├── argocd.tf                 # ArgoCD helm release, spoke registration, cluster secrets
│   ├── gateway.tf                  # Envoy Gateway CRDs/bootstrap + Gateway API routes (via Helm charts)
│   ├── rollouts.tf                  # Argo Rollouts controller on hub + both spokes
│   └── canary-demo.tf                # ArgoCD ApplicationSet that deploys the canary demo everywhere
├── charts/                  # Helm charts used by deploy/gateway.tf and deploy/canary-demo.tf
│   ├── envoy-gateway-crd/           # Gateway API CRDs
│   ├── envoy-gateway-bootstrap/      # Envoy Gateway controller + Gateway + GatewayClass
│   ├── gateway-routes/                # HTTPRoutes: argocd.local -> argocd-server, canary.local -> canary demo
│   └── canary-demo-appset/             # ArgoCD ApplicationSet fanning the demo app out to hub/spokes
├── apps/canary-demo/        # Plain Kubernetes manifests for the demo app (Rollout + stable/canary Services)
├── config/dev/               # kind cluster config shared by hub + spokes (hub uses node_port.yaml)
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

This repo is two separate Terraform projects, run in order from their own directories. Each has its own state — don't run `terraform init`/`apply` from the repo root.

### 1. `cluster-bootstrap/` — create the clusters

```bash
cd cluster-bootstrap
terraform init
terraform apply
```

This creates the `hub`, `spoke-1`, and `spoke-2` kind clusters and their `kind-hub`, `kind-spoke-1`, `kind-spoke-2` kubeconfig contexts.

Confirm all three contexts exist before continuing:

```bash
kubectl config get-contexts
```

### 2. `deploy/` — install ArgoCD, the gateway, and the demo app

```bash
cd ../deploy
terraform init
terraform apply
```

This will, in order:
1. Install ArgoCD on the hub cluster.
2. Register `spoke-1` and `spoke-2` with the hub's ArgoCD.
3. Install the Envoy Gateway CRDs/controller and the `main-gateway` Gateway on the hub, plus `HTTPRoute`s for `argocd.local` (→ `argocd-server`) and `canary.local` (→ the canary demo).
4. Install the Argo Rollouts controller on the hub and both spokes.
5. Deploy the sample canary demo app to every registered cluster via the `canary-demo-appset` ApplicationSet.

To tear everything down, destroy in reverse order:

```bash
cd deploy && terraform destroy
cd ../cluster-bootstrap && terraform destroy
```

### 3. Access ArgoCD / the canary demo through the gateway

The gateway only has an in-cluster `ClusterIP` Service (no ingress/LoadBalancer in this local kind setup), so you reach it via `kubectl port-forward` plus a `/etc/hosts` entry for the two hostnames used by the routes.

**Find the gateway's Service name** (Envoy Gateway generates one per Gateway resource, e.g. `envoy-argocd-main-gateway-<hash>`):

```bash
kubectl --context kind-hub -n envoy-gateway-system get svc
```

**Port-forward it:**

```bash
kubectl --context kind-hub \
  -n envoy-gateway-system \
  port-forward svc/envoy-argocd-main-gateway-4aaefa5f 8080:80
```

**Add the route hostnames to your hosts file** so requests to them resolve to the forwarded port. Edit `/etc/hosts` (macOS/Linux) or `C:\Windows\System32\drivers\etc\hosts` (Windows, as Administrator) and add:

```
127.0.0.1 argocd.local
127.0.0.1 canary.local
```

Then, with the port-forward running:
- ArgoCD UI: http://argocd.local:8080
- Canary demo: http://canary.local:8080

> The Service name includes a hash suffix that Envoy Gateway derives from the Gateway's name/namespace, so it *should* stay stable across re-applies of this repo — but always verify with `kubectl get svc -n envoy-gateway-system` if the port-forward can't find it.

## Notes / known limitations

- `helm_release.argocd` sets `server.insecure = true`, which disables TLS on the hub's ArgoCD server. This is fine for local kind clusters but should not be carried into any environment reachable outside your machine.
- Provider blocks (`kubernetes`, `helm`) are duplicated once per cluster (hub/spoke1/spoke2) in both `cluster-bootstrap/providers.tf` and `deploy/providers.tf`, because Terraform provider blocks don't support `for_each`/`count`. Adding a fourth cluster means adding a fourth set of provider blocks by hand in both projects.
- The `kind-cluster` module has no `output` values currently — nothing downstream depends on it yet.
- The gateway's Service name (`envoy-<gateway-namespace>-<gateway-name>-<hash>`) is generated by Envoy Gateway and isn't a Terraform output — you may need to `kubectl get svc -n envoy-gateway-system` to confirm it before port-forwarding.
- `cluster-bootstrap/providers.tf` currently defines its `hub` context as `kind-demo`, while `cluster-bootstrap/clusters.tf` creates the hub cluster with the name `hub` (kind context `kind-hub`) and `deploy/providers.tf` also expects `kind-hub`. If `cluster-bootstrap` apply/destroy commands target the wrong context, this mismatch is worth fixing to `kind-hub` for consistency.

## Resetting from scratch

If state gets messy (stale kind clusters, half-applied state, etc.), clear everything and start over:

```bash
kind get clusters | xargs -I{} kind delete cluster --name {}   # belt-and-suspenders, clears anything lingering

cd cluster-bootstrap
rm -f terraform.tfstate terraform.tfstate.backup
terraform init -upgrade
terraform apply
kubectl config get-contexts   # confirm all 3 kind-* contexts exist before continuing

cd ../deploy
rm -f terraform.tfstate terraform.tfstate.backup
terraform init -upgrade
terraform apply
```
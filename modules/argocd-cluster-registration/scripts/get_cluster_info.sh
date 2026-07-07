#!/bin/bash
set -e

CLUSTER_NAME=$1
CONTEXT="kind-${CLUSTER_NAME}"

SERVER="https://${CLUSTER_NAME}-control-plane:6443"

CA=$(kubectl config view --raw \
  -o jsonpath="{.clusters[?(@.name==\"$CONTEXT\")].cluster.certificate-authority-data}")

TOKEN=$(kubectl \
  --context "$CONTEXT" \
  create token argocd-manager \
  -n kube-system)

jq -n \
  --arg server "$SERVER" \
  --arg ca "$CA" \
  --arg token "$TOKEN" \
'{
  server: $server,
  ca: $ca,
  token: $token
}'
#!/usr/bin/env bash

set -e
set -o errexit
set -o nounset
set -o pipefail

header=$'\e[1;33m'
reset=$'\e[0m'

function header_text {
	echo "$header$*$reset"
}

kind delete cluster || true

NODE_VERSION=${NODE_VERSION:-"v1.34.0"}
NODE_SHA=${NODE_SHA:-"sha256:7416a61b42b1662ca6ca89f02028ac133a309a2a30ba309614e8ec94d976dc5a"}
REGISTRY_NAME=${REGISTRY_NAME:-"kind-registry"}
REGISTRY_PORT=${REGISTRY_PORT:-"5001"}

# create registry container unless it already exists
if [ "$(docker inspect -f '{{.State.Running}}' "${REGISTRY_NAME}" 2>/dev/null || true)" != 'true' ]; then
  docker run \
    -d --restart=always -p "127.0.0.1:${REGISTRY_PORT}:5000" --name "${REGISTRY_NAME}" \
    docker.io/registry:2
fi

cat <<EOF | kind create cluster --config=-
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster

containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${REGISTRY_PORT}"]
    endpoint = ["http://${REGISTRY_NAME}:5000"]
nodes:
- role: control-plane
  image: kindest/node:${NODE_VERSION}@${NODE_SHA}
- role: worker
  image: kindest/node:${NODE_VERSION}@${NODE_SHA}
EOF

# connect the registry to the cluster network if not already connected
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${REGISTRY_NAME}")" = 'null' ]; then
  docker network connect "kind" "${REGISTRY_NAME}"
fi

# Document the local registry
# https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

header_text "Installing Strimzi Operator"
kubectl create namespace kafka
kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka
header_text "Deploy a Kafka UI"
kubectl apply -f https://gist.githubusercontent.com/creydr/96b823bd44011d3c2d3faeb41dbbcfd0/raw/726cb8588b5ffd8d8ea2965e60a2683ce34a10c4/kafka-ui.yaml -n kafka
header_text "Waiting for Strimzi Operator to become ready"
kubectl wait deployment --all --timeout=-1s --for=condition=Available -n kafka
header_text "Create an Apache Kafka Cluster"
kubectl apply -f https://strimzi.io/examples/latest/kafka/kafka-single-node.yaml -n kafka
header_text "Waiting for Kafka cluster to become ready"
kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n kafka

header_text "Installing keda"
kubectl apply --server-side -f https://github.com/kedacore/keda/releases/download/v2.17.0/keda-2.17.0.yaml
kubectl apply --server-side -f https://github.com/kedacore/keda/releases/download/v2.17.0/keda-2.17.0-core.yaml
header_text "Waiting for Keda to become ready"
kubectl wait deployment --all --timeout=-1s --for=condition=Available --namespace keda
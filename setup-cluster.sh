#!/usr/bin/env bash
set -euo pipefail

##############################################################################
# 1. Prereqs: install Multipass via Homebrew if needed                       #
##############################################################################
if ! command -v multipass &> /dev/null; then
  echo "🔄 Installing Multipass..."
  brew install --cask multipass
fi

##############################################################################
# 2. VM names and specs                                                      #
##############################################################################

# Adjust these to the names you prefer for your Multipass VMs
NODES=( k8s-master k8s-worker1 k8s-worker2 k8s-worker3 k8s-worker4 )

echo "🚀 Launching VMs..."
for NODE in "${NODES[@]}"; do
  if [[ "$NODE" == "${NODES[0]}" ]]; then   # More ressources to master node
    multipass launch --name "$NODE" --cpus 4 --memory 8G  --disk 20G 22.04
  else
    multipass launch --name "$NODE" --cpus 2 --memory 4G  --disk 10G 22.04
  fi  
done

echo "⏳ Waiting for VMs to boot..."
sleep 10

##############################################################################
# 3. Prepare each node                                                       #
##############################################################################
# Disable swap, load modules, sysctl, containerd, kubeadm/kubelet
for NODE in "${NODES[@]}"; do
  echo "🔧 Installing $NODE containerd..."
  multipass exec "$NODE" -- bash -s < scripts/install-containerd.sh &> "logs/$NODE.log"
  echo "🔧 Installing $NODE kubernetes..."
  multipass exec "$NODE" -- bash -s < scripts/install-kubernetes.sh &>> "logs/$NODE.log"
  echo "🔧 Configuring $NODE..."
  multipass exec "$NODE" -- bash -s < scripts/setup-node.sh &>> "logs/$NODE.log"
done
echo "✅ Nodes were launched and are ready!"
sleep 10

##############################################################################
# 4. Initialize the master                                                   #
##############################################################################
MASTER_NODE=${NODES[0]}
MASTER_IP=$(multipass info "$MASTER_NODE" | awk '/IPv4/ {print $2}')

echo "🎯 Pre-pulling control-plane images on master..."
multipass exec "$MASTER_NODE" -- sudo kubeadm config images pull --kubernetes-version=v1.32.4 &>> "logs/$MASTER_NODE.log"

echo "🎯 Initializing master (API at $MASTER_IP)..."
multipass exec "$MASTER_NODE" -- bash -s < scripts/init-master.sh "$MASTER_IP" &>> "logs/$MASTER_NODE.log"

##############################################################################
# 5. Copy kubeconfig locally                                                 #
##############################################################################
echo "📋 Copying kubeconfig to ~/.kube/multipass-k8s.conf"
# Copy kubeconfig to ~/.kube/multipass-k8s.conf
mkdir -p ~/.kube
multipass transfer "$MASTER_NODE":/home/ubuntu/.kube/config ~/.kube/multipass-k8s.conf
export KUBECONFIG=~/.kube/multipass-k8s.conf

##############################################################################
# 5. Install Calico Operator & CRDs                                          #
##############################################################################
echo "📥 Installing Calico operator and CRDs..."
kubectl apply --server-side --force-conflicts -f \
  https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/tigera-operator.yaml

# Wait for the Installation CRD to be Established
echo "⏳ Waiting for CRD installations.operator.tigera.io to be Established..."
kubectl wait --for=condition=Established crd/installations.operator.tigera.io --timeout=60s

##############################################################################
# 7. Apply Calico Installation & APIServer CRs                               #
##############################################################################
echo "🔨 Applying Calico Installation & APIServer resources..."
kubectl apply -f resources/calico-installation.yaml

##############################################################################
# 8. Join the worker nodes                                                  #
##############################################################################
JOIN_CMD=$(multipass exec "$MASTER_NODE" -- sudo kubeadm token create --print-join-command)
echo "🔑 Join command: $JOIN_CMD"
for NODE in "${NODES[@]:1}"; do
  echo "✋ Joining $NODE..."
  multipass exec "$NODE" -- sudo "$JOIN_CMD" &>> "logs/$NODE.log"
done

##############################################################################
# 9. Wait for all nodes to be Ready                                          #
##############################################################################
echo "⏳ Waiting for all nodes to be Ready..."
kubectl wait --for=condition=Ready node --all --timeout=2m

echo "✅ Kubernetes v1.32 cluster with Calico is up and Ready!"

echo "🔍 Nodes:"
kubectl get nodes

echo "🔍 Pods:"
kubectl get pods -A | grep -E "calico|tigera|csi-node-driver"
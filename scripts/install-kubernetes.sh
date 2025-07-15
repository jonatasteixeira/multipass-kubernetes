#!/bin/env bash
set -eu

##############################################################################
# Kubernetes components                                                      #
##############################################################################

# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# If the directory `/etc/apt/keyrings` does not exist, 
# it should be created before the curl command, read the note below.
sudo mkdir -p -m 755 /etc/apt/keyrings || true

# Add Kubernetes repository to keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key \
    | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg

# Add Kubernetes repository to sources.list
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /
EOF

# Install kubelet, kubeadm, and kubectl
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Enable the kubelet service before running kubeadm:
sudo systemctl enable --now kubelet

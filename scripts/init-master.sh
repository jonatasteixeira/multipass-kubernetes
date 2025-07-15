#!/bin/env bash
set -eux

##############################################################################
# Initialize the master                                                      #
##############################################################################

MASTER_IP=$1

# Check if master IP is provided
if [ -z "$MASTER_IP" ]; then
  echo "Error: Master IP is required"
  exit 1
fi

# Initialize the master
sudo kubeadm init \
  --kubernetes-version v1.32.4 \
  --apiserver-advertise-address "$MASTER_IP" \
  --pod-network-cidr 10.244.0.0/16

# Set up kubectl for ubuntu user
mkdir -p "$HOME/.kube"
sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
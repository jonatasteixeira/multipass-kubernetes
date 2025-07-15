#!/bin/env bash
set -eu

# This script is used to setup a basic kubernetes node.
# It must run in all nodes, including the master node.
# Disable swap, load modules, sysctl, containerd, kubeadm/kubelet
# It is used to install containerd, Kubernetes components and dependencies.

##############################################################################
# System setup                                                               #
##############################################################################

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap /s/^/#/' /etc/fstab

# Load Kubernetes kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Reload kernel modules
sudo modprobe overlay
sudo modprobe br_netfilter

# Sysctl params for networking
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                = 1
EOF

# Update containerd config to use systemd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Apply sysctl params without reboot
sudo sysctl --system

# Restart containerd/kubelet
sudo systemctl restart containerd
sudo systemctl restart kubelet

# Enable containerd/kubelet
sudo systemctl enable containerd
sudo systemctl enable --now kubelet

#!/bin/env bash
set -eu

##############################################################################
# Containerd                                                                 #
##############################################################################

# Containerd
# The containerd daemon is the container runtime for the node. For Ubuntu its 
# is being distributed by Docker Engine. 
# Reference:
# https://github.com/containerd/containerd/blob/main/docs/getting-started.md
# https://docs.docker.com/engine/install/ubuntu/

packages=(
    docker.io
    docker-doc
    docker-compose
    docker-compose-v2
    podman-docker
    containerd
    runc
)

# Remove old packages
for pkg in "${packages[@]}"; do
    sudo apt-get remove "$pkg"
done

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
cat <<EOF | sudo tee /etc/apt/sources.list.d/docker.list
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable
EOF

# Install Docker Engine, containerd, and Docker Compose
sudo apt-get update
sudo apt-get install \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

sudo systemctl enable containerd
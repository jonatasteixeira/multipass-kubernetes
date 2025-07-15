# Multipass Kubernetes Cluster

A complete automation solution for setting up a multi-node Kubernetes cluster using Multipass VMs on macOS. This project creates a production-like Kubernetes v1.32 cluster with Calico networking, consisting of 1 master node and 4 worker nodes.

## 🏗️ Architecture

The cluster consists of:

- **1 Master Node** (`k8s-master`): 4 CPUs, 8GB RAM, 20GB disk
- **4 Worker Nodes** (`k8s-worker1-4`): 2 CPUs, 4GB RAM, 10GB disk each
- **Operating System**: Ubuntu 22.04 LTS
- **Container Runtime**: containerd (via Docker Engine)
- **Network Plugin**: Calico v3.26.0
- **Pod Network CIDR**: `10.244.0.0/16`

## 📋 Prerequisites

- **macOS** (tested on Darwin 24.5.0)
- **Homebrew** package manager
- **Multipass** (automatically installed if not present)
- At least **20GB free disk space**
- At least **24GB RAM** (for all VMs combined)

## 🚀 Quick Start

1. **Clone the repository**:

   ```bash
   git clone git@github.com:jonatasteixeira/multipass-kubernetes.git
   cd multipass-kubernetes
   ```

2. **Run the setup script**:

   ```bash
   ./setup-cluster.sh
   ```

3. **Access your cluster**:

   ```bash
   export KUBECONFIG=~/.kube/multipass-k8s.conf
   kubectl get nodes
   ```

## 🔧 Implementation Details

### Core Components

#### 1. Main Setup Script (`setup-cluster.sh`)

The orchestrator script that:

- Installs Multipass via Homebrew if needed
- Launches 5 Ubuntu 22.04 VMs with appropriate resource allocation
- Configures each node by executing the node setup script
- Initializes the Kubernetes master node
- Installs Calico networking operator and CRDs
- Joins worker nodes to the cluster
- Waits for all components to be ready

#### 2. Node Setup Script (`scripts/setup-node.sh`)

Prepares each VM for Kubernetes by:

**System Configuration:**

- Disabling swap permanently
- Loading required kernel modules (`overlay`, `br_netfilter`)
- Configuring sysctl parameters for container networking

**Container Runtime Setup:**

- Installing Docker Engine and containerd
- Configuring containerd to use systemd cgroup driver
- Enabling and starting containerd service

**Kubernetes Components:**

- Adding Kubernetes v1.32 repository and GPG keys
- Installing `kubelet`, `kubeadm`, and `kubectl`
- Marking packages to prevent automatic updates
- Enabling kubelet service

#### 3. Master Initialization (`scripts/init-master.sh`)

Configures the master node by:

- Running `kubeadm init` with specific API server settings
- Configuring kubectl access for the ubuntu user
- Using the provided master IP for API server advertisement

#### 4. Network Configuration (`resources/calico-installation.yaml`)

Defines Calico networking setup:

- **Installation CR**: Configures IP pools with VXLANCrossSubnet encapsulation
- **APIServer CR**: Enables Calico API server for advanced features
- **CIDR Block**: `10.244.0.0/16` with `/26` block size for efficient IP allocation

### Networking Architecture

```ascii
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   k8s-master    │    │  k8s-worker1    │    │  k8s-worker2    │
│   4 CPU/8GB     │    │   2 CPU/4GB     │    │   2 CPU/4GB     │
│                 │    │                 │    │                 │
│ Control Plane   │◄──►│   Worker Node   │    │   Worker Node   │
│ + Worker        │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
         ┌─────────────────┐    ┌─────────────────┐
         │  k8s-worker3    │    │  k8s-worker4    │
         │   2 CPU/4GB     │    │   2 CPU/4GB     │
         │                 │    │                 │
         │   Worker Node   │    │   Worker Node   │
         │                 │    │                 │
         └─────────────────┘    └─────────────────┘

Pod Network: 10.244.0.0/16 (Calico CNI)
Encapsulation: VXLAN Cross-Subnet
```

## 📁 Project Structure

```bash
multipass-kubernetes/
├── setup-cluster.sh              # Main orchestration script
├── scripts/
│   ├── install-containerd.sh     # Install Container.d (all nodes)
│   ├── install-kubernetes.sh     # Install kubernetes tools (all nodes)
│   ├── setup-node.sh             # Node preparation (all nodes)
│   └── init-master.sh            # Master node initialization
├── resources/
│   └── calico-installation.yaml  # Calico network configuration
├── logs/                         # Execution logs for each node
└── README.md                     # This documentation
```

## 🎯 Features

- **Automated VM provisioning** with optimal resource allocation
- **Complete Kubernetes v1.32 setup** with latest stable components
- **Production-ready networking** with Calico CNI
- **Comprehensive logging** for troubleshooting
- **Idempotent operations** - safe to re-run
- **Local kubectl access** with dedicated kubeconfig

## 🔍 Post-Installation Verification

After successful setup, verify your cluster:

```bash
# Set kubeconfig
export KUBECONFIG=~/.kube/multipass-k8s.conf

# Check nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system

# Check Calico components
kubectl get pods -n calico-system

# Test cluster connectivity
kubectl run test-pod --image=nginx --rm -it -- /bin/bash
```

## 🛠️ Management Commands

### Cluster Operations

```bash
# Stop all VMs
multipass stop k8s-master k8s-worker1 k8s-worker2 k8s-worker3 k8s-worker4

# Start all VMs
multipass start k8s-master k8s-worker1 k8s-worker2 k8s-worker3 k8s-worker4

# Check VM status
multipass list

# Access master node
multipass shell k8s-master
```

### Cleanup

```bash
# Delete all VMs
multipass delete k8s-master k8s-worker1 k8s-worker2 k8s-worker3 k8s-worker4
multipass purge

# Remove kubeconfig
rm ~/.kube/multipass-k8s.conf
```

## 📊 Resource Requirements

| Component | CPU | Memory | Disk | Purpose |
|-----------|-----|--------|------|---------|
| Master Node | 4 cores | 8GB | 20GB | Control plane + worker |
| Worker Node × 4 | 2 cores | 4GB | 10GB | Application workloads |
| **Total** | **12 cores** | **24GB** | **60GB** | Complete cluster |

## 🔧 Troubleshooting

### Common Issues

1. **Insufficient Resources**:
   - Reduce worker node count in `setup-cluster.sh`
   - Adjust VM specs based on available resources

2. **Network Issues**:
   - Check Calico pod status: `kubectl get pods -n calico-system`
   - Verify node connectivity: `multipass list`

3. **Join Failures**:
   - Check worker node logs in `logs/` directory
   - Regenerate join token: `multipass exec k8s-master -- sudo kubeadm token create --print-join-command`

### Log Files

All operations are logged to `logs/` directory:

- `k8s-master.log`: Master node setup and initialization
- `k8s-worker[1-4].log`: Individual worker node setup

### Recovery

If setup fails partway through:

1. Check logs for specific errors
2. Delete problematic VMs: `multipass delete <vm-name>`
3. Re-run `./setup-cluster.sh`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test changes thoroughly
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🔗 References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Multipass Documentation](https://multipass.run/docs)
- [Calico Documentation](https://docs.projectcalico.org/)
- [containerd Documentation](https://containerd.io/docs/)

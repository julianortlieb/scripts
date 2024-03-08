#!/bin/bash

###########################################################
# TITLE: Kubernetes Installation
# DESCRIPTION: Installs docker engine, kubeadm, kubelet, and kubectl on debian based systems
# AUTHOR: Julian Ortlieb
# DATE: 2022-03-01
###########################################################

# ------- Check requirements -------
# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

# Check if system is debian based
if [ ! -f /etc/debian_version ]; then
    echo "This script is only for debian based systems"
    exit
fi

# Check if the debian version is bookworm or bullseye
if [ "$(lsb_release -cs)" != "bookworm" ] && [ "$(lsb_release -cs)" != "bullseye" ]; then
    echo "This script is only for debian bookworm or bullseye"
    exit
fi

# Check if whiptail is installed
if [ ! -x "$(command -v whiptail)" ]; then
    echo "whiptail is not installed. Please install it with 'apt install whiptail'"
    exit
fi

# ------- Swap -------
# Check if swap is enabled and store the result in a variable
SWAP_ENABLED=$(swapon -s | wc -l)

# ask user via whiptail if swap should be disabled
if [ $SWAP_ENABLED -gt 1 ]; then
    whiptail --title "Swap" --yesno "Swap is enabled. Do you want to disable it?" 10 60
    SWAP_ENABLED=$?
fi

# If swap should be disabled
if [ $SWAP_ENABLED -eq 1 ]; then
    # Disable swap
    swapoff -a

    # Comment out the swap line in /etc/fstab
    sed -i '/swap/s/^/#/' /etc/fstab

    # Echo a message to the user
    echo "[Script] Swap is disabled"
fi

# ------- Docker -------
# Install docker
# Check if Docker is already installed
if ! command -v docker &> /dev/null; then
    # Add Docker's official GPG key:
    apt-get update
    apt-get install ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |
        tee /etc/apt/sources.list.d/docker.list >/dev/null
    apt-get update

    # Install docker packages
    apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# ------- Install CRI-Dockerd -------
# Check if cri-dockerd is not installed
if ! dpkg -s cri-dockerd &> /dev/null; then
    # Get latest deb-Package from GitHub based on the system version
    if [ "$(lsb_release -cs)" == "bookworm" ]; then
        # Download with curl and install with dpkg
        curl -LO https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.10/cri-dockerd_0.3.10.3-0.debian-bookworm_amd64.deb
        dpkg -i cri-dockerd_0.3.10.3-0.debian-bookworm_amd64.deb
    elif [ "$(lsb_release -cs)" == "bullseye" ]; then
        # Download with curl and install with dpkg
        curl -LO https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.10/cri-dockerd_0.3.10.3-0.debian-bullseye_amd64.deb
        dpkg -i cri-dockerd_0.3.10.3-0.debian-bullseye_amd64.deb
    fi

    # Echo a message to the user
    echo "[Script] CRI-Dockerd is installed"
fi

# ------- Configure cgroup driver -------
# Ask user via whiptail if cgroup driver should be configured
whiptail --title "Cgroup Driver" --yesno "Do you want to configure the cgroup driver?" 10 60
CONFIGURE_CGROUP_DRIVER=$?

# If cgroup driver should be configured
if [ $CONFIGURE_CGROUP_DRIVER -eq 0 ]; then
    # Ask user via whiptail which cgroup driver should be used
    CGROUP_DRIVER=$(whiptail --title "Cgroup Driver" --radiolist "Choose the cgroup driver" 10 60 2 "systemd" "Use systemd as cgroup driver" ON "cgroupfs" "Use cgroupfs as cgroup driver" OFF 3>&1 1>&2 2>&3)

    # If the user chose systemd
    if [ $CGROUP_DRIVER == "systemd" ]; then
        # Add the cgroup driver to the kernel command line
        sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=1"/' /etc/default/grub
        update-grub
    fi
fi

# ------- Precheck -------
# Check if port 6443 is open
PORT_6443_OPEN=$(
    nc -zv
    localhost 6443 2>&1 | grep succeeded | wc -l
)

# If port 6443 is not open
if [ $PORT_6443_OPEN -eq 0 ]; then
    # Ask user via whiptail if port 6443 should be opened
    whiptail --title "Port 6443" --yesno "Port 6443 is not open. Do you want to open it?" 10 60
    PORT_6443_OPEN=$?
fi

# If port 6443 should be opened
if [ $PORT_6443_OPEN -eq 0 ]; then
    # Open port 6443
    ufw allow 6443
fi

# ------- Kubernetes -------
# Add the Kubernetes repository
apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
apt-get install -y apt-transport-https ca-certificates curl gpg

# If the folder `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
mkdir -p /etc/apt/keyrings/
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

# Install the Kubernetes packages
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Configure kubernetes to use the same cgroup driver as docker
if [ $CGROUP_DRIVER == "systemd" ]; then
    # Add the cgroup driver to the kubelet configuration
    echo "KUBELET_EXTRA_ARGS=--cgroup-driver=$CGROUP_DRIVER" >/etc/default/kubelet
fi

# ------- Postcheck -------
# Check if the kubelet is running
KUBELET_RUNNING=$(systemctl is-active kubelet)

# If the kubelet is not running
if [ $KUBELET_RUNNING != "active" ]; then
    # Ask user via whiptail if the kubelet should be started
    whiptail --title "Kubelet" --yesno "The kubelet is not running. Do you want to start it?" 10 60
    KUBELET_RUNNING=$?
fi

# If the kubelet should be started
if [ $KUBELET_RUNNING -eq 0 ]; then
    # Start the kubelet
    systemctl start kubelet
fi

# Check if the kubelet is enabled
KUBELET_ENABLED=$(systemctl is-enabled kubelet)

# If the kubelet is not enabled
if [ $KUBELET_ENABLED != "enabled" ]; then
    # Ask user via whiptail if the kubelet should be enabled
    whiptail --title "Kubelet" --yesno "The kubelet is not enabled. Do you want to enable it?" 10 60
    KUBELET_ENABLED=$?
fi

# If the kubelet should be enabled
if [ $KUBELET_ENABLED -eq 0 ]; then
    # Enable the kubelet
    systemctl enable kubelet
fi

# ------- Create Cluster -------
# Ask user via whiptail if a cluster should be created
whiptail --title "Create Cluster" --yesno "Do you want to create a cluster?" 10 60
CREATE_CLUSTER=$?

# If a cluster should be created
if [ $CREATE_CLUSTER -eq 0 ]; then
    # Ask user via whiptail for the cluster name
    # CLUSTER_NAME=$(whiptail --title "Cluster Name" --inputbox "Enter the name of the cluster" 10 60 3>&1 1>&2 2>&3)

    # Ask user via whiptail for the pod network cidr
    POD_NETWORK_CIDR=$(whiptail --title "Pod Network CIDR" --inputbox "Enter the pod network CIDR" 10 60 3>&1 1>&2 2>&3)

    # Create the cluster with pod network cidr and cri dockerd socket and the right cluster name
    kubeadm init --pod-network-cidr=$POD_NETWORK_CIDR --cri-socket=/var/run/cri-dockerd.sock

    # Copy the kubectl configuration to the user's home directory and create folder if it does not exist
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/
    chown $(id -u):$(id -g) $HOME/admin.conf
    export KUBECONFIG=$HOME/admin.conf

    # Apply the pod network
    kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

    # Save the token and hash in a file
    kubeadm token create --print-join-command >/root/join-cluster.sh
fi

# ------- Load Balancer -------
# Ask user via whiptail if a load balancer should be installed
whiptail --title "Load Balancer" --yesno "Do you want to install a load balancer?" 10 60
LOAD_BALANCER=$?

# If a load balancer should be installed
if [ $LOAD_BALANCER -eq 0 ]; then
    # Install the load balancer
    apt-get install -y haproxy

    # Configure the load balancer
    echo "frontend k8s-api" >/etc/haproxy/haproxy.cfg
    echo "    bind *:6443" >>/etc/haproxy/haproxy.cfg
    echo "    default_backend k8s-api" >>/etc/haproxy/haproxy.cfg
    echo "" >>/etc/haproxy/haproxy.cfg
    echo "backend k8s-api" >>/etc/haproxy/haproxy.cfg
    echo "    balance roundrobin" >>/etc/haproxy/haproxy.cfg
    echo "    server master1
    $(hostname -I | awk '{print $1}'):6443 check" >>/etc/haproxy/haproxy.cfg

    # Restart the load balancer
    systemctl restart haproxy
fi

# ------- Dashboard -------
# Ask user via whiptail if the dashboard should be installed
whiptail --title "Dashboard" --yesno "Do you want to install the dashboard?" 10 60
DASHBOARD=$?

# If the dashboard should be installed
if [ $DASHBOARD -eq 0 ]; then
    # Install the dashboard
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.4.0/aio/deploy/recommended.yaml
fi



# ------- Join Cluster -------
# Ask user via whiptail if a node should join the cluster, but only if the node is not the master
if [ $CREATE_CLUSTER -eq 0 ] && [ "$(hostname)" != "master" ]; then
    whiptail --title "Join Cluster" --yesno "Do you want to join the cluster?" 10 60
    JOIN_CLUSTER=$?
fi

# If a node should join the cluster
if [ $JOIN_CLUSTER -eq 0 ]; then
    # Ask user via whiptail for the master's ip address
    MASTER_IP=$(whiptail --title "Master IP" --inputbox "Enter the master's IP address" 10 60 3>&1 1>&2 2>&3)

    # Ask user via whiptail for the token
    TOKEN=$(whiptail --title "Token" --inputbox "Enter the token" 10 60 3>&1 1>&2 2>&3)

    # Ask user via whiptail for the hash
    HASH=$(whiptail --title "Hash" --inputbox "Enter the hash" 10 60 3>&1 1>&2 2>&3)

    # Join the cluster
    kubeadm join $MASTER_IP:6443 --token $TOKEN --discovery-token-ca-cert-hash sha256:$HASH
fi

# ------- Finish -------
# Ask user via whiptail if the system should be rebooted
whiptail --title "Reboot" --yesno "The installation is finished. Do you want to reboot the system?" 10 60
REBOOT=$?

# If the system should be rebooted
if [ $REBOOT -eq 0 ]; then
    # Reboot the system
    reboot
fi

# One liner to start script with curl
# curl -s https://raw.githubusercontent.com/julianortlieb/k8s-install/main/k8s-install.sh | bash

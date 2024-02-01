#!/bin/bash
# Author: Md Saif Zaman
# Purpose: Building a Bridge Between Two Network Namespaces Using Virtual Ethernet in a Virtual Machine
# Date: Feb 01, 2024

# Ensure the script is run as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Step 0: Check basic network status
echo "Checking the current network status..."
ip link
route -n

# Step 1.1: Create two network namespaces
echo "Creating network namespaces ns1 and ns2..."
ip netns add ns1
ip netns add ns2
ip netns list
ls /var/run/netns/

# Step 1.2: Set up loopback interfaces
echo "Setting up loopback interfaces for ns1 and ns2..."
ip netns exec ns1 ip link set lo up
ip netns exec ns2 ip link set lo up

# Step 2.1: Create a bridge network
echo "Creating a bridge network br0..."
ip link add br0 type bridge
ip link set br0 up

# Step 2.2: Configure IP to the bridge network
echo "Assigning IP address to the bridge br0..."
ip addr add 192.168.1.1/24 dev br0

# Step 3.1: Create veth pairs and attach to namespaces and bridge
echo "Creating veth pairs and attaching them to namespaces and the bridge..."
ip link add veth0 type veth peer name ceth0
ip link set veth0 master br0
ip link set veth0 up
ip link set ceth0 netns ns1
ip netns exec ns1 ip link set ceth0 up

ip link add veth1 type veth peer name ceth1
ip link set veth1 master br0
ip link set veth1 up
ip link set ceth1 netns ns2
ip netns exec ns2 ip link set ceth1 up

# Step 3.2: Assign IP addresses and update routes
echo "Assigning IP addresses to veth interfaces in namespaces..."
ip netns exec ns1 ip addr add 192.168.1.10/24 dev ceth0
ip netns exec ns2 ip addr add 192.168.1.11/24 dev ceth1

# Step 5.1: Establish internet connectivity
echo "Adding default routes for internet connectivity..."
ip netns exec ns1 ip route add default via 192.168.1.1
ip netns exec ns2 ip route add default via 192.168.1.1

# Step 5.3: Set up NAT
echo "Setting up NAT for internet access..."
sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -s 192.168.1.0/24 ! -o br0 -j MASQUERADE

echo "Network namespaces setup is complete!"

# Note: The script does not include the steps for verifying connectivity and exposing services,
# as these steps are typically performed manually for testing purposes.

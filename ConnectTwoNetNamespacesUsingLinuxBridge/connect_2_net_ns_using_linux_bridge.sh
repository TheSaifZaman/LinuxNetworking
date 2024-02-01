#!/bin/bash
# Author: Md Saif Zaman
# Purpose: Connect Two Network Namespaces Using a Linux Bridge
# Date: Feb 01, 2024

# Define network namespaces
NS1="ns1"
NS2="ns2"

# Define virtual ethernet pairs
VETH_NS1="veth-ns1"
VETH_NS2="veth-ns2"
VPEER_NS1="vpeer-ns1"
VPEER_NS2="vpeer-ns2"

# Define bridge name
BRIDGE="br0"

# Create network namespaces
echo "Creating network namespaces: $NS1 and $NS2..."
sudo ip netns add $NS1
sudo ip netns add $NS2

# Create virtual ethernet pairs and bridge
echo "Creating virtual ethernet pairs and Linux bridge $BRIDGE..."
sudo ip link add $VETH_NS1 type veth peer name $VPEER_NS1
sudo ip link add $VETH_NS2 type veth peer name $VPEER_NS2
sudo ip link add name $BRIDGE type bridge

# Attach veth pairs to the namespaces
echo "Attaching virtual ethernet pairs to namespaces..."
sudo ip link set $VETH_NS1 netns $NS1
sudo ip link set $VETH_NS2 netns $NS2

# Attach peers to the bridge
echo "Attaching peers to the bridge..."
sudo ip link set $VPEER_NS1 master $BRIDGE
sudo ip link set $VPEER_NS2 master $BRIDGE

# Configure IP addresses for veth interfaces in namespaces
echo "Configuring IP addresses in namespaces..."
sudo ip netns exec $NS1 ip addr add 10.0.0.1/24 dev $VETH_NS1
sudo ip netns exec $NS2 ip addr add 10.0.0.2/24 dev $VETH_NS2

# Bring up the interfaces within namespaces
echo "Bringing up interfaces within namespaces..."
sudo ip netns exec $NS1 ip link set $VETH_NS1 up
sudo ip netns exec $NS2 ip link set $VETH_NS2 up

# Bring up the bridge and peer interfaces
echo "Bringing up the Linux bridge and peer interfaces..."
sudo ip link set $BRIDGE up
sudo ip link set $VPEER_NS1 up
sudo ip link set $VPEER_NS2 up

# Test connectivity
echo "Testing connectivity between $NS1 and $NS2..."
sudo ip netns exec $NS1 ping -c 3 10.0.0.2
sudo ip netns exec $NS2 ping -c 3 10.0.0.1

echo "Script completed."

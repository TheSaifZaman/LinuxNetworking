#!/bin/bash
# Author: Md Saif Zaman
# Purpose: Building an Egress Traffic
# Date: Apr 10, 2024

# Update & Install Important Packages
sudo apt-get update
sudo apt install iproute2 iputils-ping iptables curl tcpdump net-tools -y

# Add Red & Green Namespaces
sudo ip netns add red
sudo ip netns add green

# Add Bridge & Assign IP to bridge
sudo ip link add br0 type bridge
sudo ip link set br0 up
sudo ip addr add 192.168.0.1/16 dev br0

# Add veth-ceth cables
sudo ip link add veth-red type veth peer name ceth-red
sudo ip link add veth-green type veth peer name ceth-green

# Set ceth cables to NS
sudo ip link set ceth-red netns red
sudo ip link set ceth-green netns green

# Set veth cables to Bridge
sudo ip link set veth-red master br0
sudo ip link set veth-green master br0

# Set ceth cables UP
sudo ip netns exec red ip link set ceth-red up
sudo ip netns exec green ip link set ceth-green up

# Set ceth cables UP
sudo ip link set veth-red up
sudo ip link set veth-green up

# Assign IP to NS and Set Default
sudo ip netns exec red ip addr add 192.168.0.2/16 dev ceth-red
sudo ip netns exec red ip route add default via 192.168.0.1

sudo ip netns exec green ip addr add 192.168.0.3/16 dev ceth-green
sudo ip netns exec green ip route add default via 192.168.0.1

# Post Route Chaining
sudo iptables -t nat -A POSTROUTING -s 192.168.0.0/16 -j MASQUERADE

# Add Firewall Rules
sudo iptables -t nat -L -n -v
sudo iptables --append FORWARD --in-interface br0 --jump ACCEPT
sudo iptables --append FORWARD --out-interface br0 --jump ACCEPT

# Now Enter Into NS and try ping 8.8.8.8 -c 5
# Building a Bridge Between Two Network Namespaces Using Virtual Ethernet in a Virtual Machine

## Introduction
Networking in Linux is a vast and complex topic, but one fascinating aspect is the creation and management of isolated network environments using network namespaces. In this blog, we'll explore how to create two namespaces and connect them using virtual Ethernet (veth) pairs in a virtual machine (VM). For this demonstration, I'm using an EC2 instance from AWS running Ubuntu, but you can replicate this on any standard Linux machine or VM.

## Step 0: Checking Basic Network Status
Before diving into the creation of namespaces, it's crucial to understand the current network status of your host machine or root namespace. This initial check helps in better understanding the changes we're about to make.

- **List all interfaces**:
  ```bash
  sudo ip link
  ```
- **Find the routing table**:
  ```bash
  sudo route -n
  ```

## Step 1: Creating Two Network Namespaces
### Step 1.1: Add Namespaces
First, we add two network namespaces, `ns1` and `ns2`, using the `ip netns` command.

```bash
sudo ip netns add ns1
sudo ip netns add ns2
sudo ip netns list
sudo ls /var/run/netns/
```

### Step 1.2: Enable Loopback Interfaces
By default, network interfaces of newly created namespaces are down, including loopback interfaces. We need to turn them on.

```bash
sudo ip netns exec ns1 ip link set lo up
sudo ip netns exec ns1 ip link

sudo ip netns exec ns2 ip link set lo up
sudo ip netns exec ns2 ip link
```

## Step 2: Setting up a Bridge Network
### Step 2.1: Create a Bridge
Next, we create a bridge network on the host.

```bash
sudo ip link add br0 type bridge
sudo ip link set br0 up
sudo ip link
```

### Step 2.2: Configure IP for the Bridge
Assign an IP address to the bridge and check its configuration.

```bash
sudo ip addr add 192.168.1.1/24 dev br0
sudo ip addr
ping -c 2 192.168.1.1
```

## Step 3: Connecting Namespaces using veth
### Step 3.1: Create and Attach veth Interfaces
We create veth pairs and attach one end to the bridge and the other end to the respective namespaces.

- **For ns1**:
  ```bash
  # Create veth pair and attach to bridge and ns1
  sudo ip link add veth0 type veth peer name ceth0
  sudo ip link set veth0 master br0
  sudo ip link set veth0 up
  sudo ip link set ceth0 netns ns1
  sudo ip netns exec ns1 ip link set ceth0 up
  ```

- **For ns2**: Repeat the same steps as for `ns1` but with `veth1` and `ceth1`.

### Step 3.2: Assign IP Addresses and Update Routes
Assign IP addresses to the veth interfaces in each namespace and update the route table to establish communication with the bridge network. This also enables communication between the two namespaces via the bridge.

```bash
# For ns1
sudo ip netns exec ns1 ip addr add 192.168.1.10/24 dev ceth0
sudo ip netns exec ns1 ping -c 2 192.168.1.10
sudo ip netns exec ns1 ip route
sudo ip netns exec ns1 ping -c 2 192.168.1.1

# For ns2
sudo ip netns exec ns2 ip addr add 192.168.1.11/24 dev ceth1
sudo ip netns exec ns2 ping -c 2 192.168.1.11
sudo ip netns exec ns2 ip route
sudo ip netns exec ns2 ping -c 2 192.168.1.1
```

## Step 4: Verify Connectivity Between Namespaces
Now, let's verify the connectivity between the two namespaces.

```bash
# For ns1
sudo nsenter --net=/var/run/netns/ns1
ping -c -2 192.168.1.10
ping -c -2 192.168.1.1
ping -c -2 192.168.1.11
# ping -c -2 host ip
exit

# For ns2
sudo nsenter --net=/var/run/netns/ns2
ping -c 2 192.168.1.10
ping -c -2 192.168.1.11
ping -c -2 192.168.1.1
ping -c -2 192.168.1.10
# ping host ip
exit
```

## Step 5: Connecting Namespaces to the Internet
### Step 5.1: Establishing Internet Connectivity
We'll now enable the namespaces to access the internet. First, we need to add a

 default route.

```bash
# For ns1
sudo ip netns exec ns1 ping -c 2 8.8.8.8
sudo ip netns exec ns1 route -n

sudo ip netns exec ns1 ip route add default via 192.168.1.1
sudo ip netns exec ns1 route -n

# Do the same for ns2
sudo ip netns exec ns2 ip route add default via 192.168.1.1
sudo ip netns exec ns2 route -n

# now first ping the host machine eth0
ip addr | grep eth0

# ping from ns1 to host ip
sudo ip netns exec ns1 ping 172.31.13.55
```

### Step 5.2: Analyzing Traffic with tcpdump
Let's use `tcpdump` to analyze traffic and understand how packets are traveling.

```bash
# Terminal-1: Ping google's DNS
sudo ip netns exec ns1 ping 8.8.8.8

# Terminal-2: Observe traffic : still unreachable
sudo tcpdump -i eth0 icmp

# If no packets are captured, try capturing on br0
sudo tcpdump -i br0 icmp

# we can see the traffic at br0 but we don't get response from eth0.
# it's because of IP forwarding issue
sudo cat /proc/sys/net/ipv4/ip_forward

# enabling ip forwarding by change value 0 to 1
sudo sysctl -w net.ipv4.ip_forward=1
sudo cat /proc/sys/net/ipv4/ip_forward

# terminal-2
sudo tcpdump -i eth0 icmp
```

### Step 5.3: Setting up NAT
To enable internet access, we can make use of NAT (network address translation) by placing an iptables rule in the POSTROUTING chain of the nat table.

```bash
sudo iptables -t nat -A POSTROUTING -s 192.168.1.0/24 ! -o br0 -j MASQUERADE

# -t specifies the table to which the commands should be directed to. By default it's `filter`.
# -A specifies that we're appending a rule to the chain then we tell the name after it
# -s specifies a source address (with a mask in this case).
# -j specifies the target to jump to (what action to take).

# now we're getting response from google dns
sudo ip netns exec ns1 ping -c 2 8.8.8.8
sudo ip netns exec ns2 ping -c 2 8.8.8.8
```

## Step 6: Exposing Services from Namespace
Finally, let's open a service in one of the namespaces and access it from outside.

```bash
sudo nsenter --net=/var/run/netns/ns1
python3 -m http.server --bind 192.168.1.10 3000
```

- **Accessing the Service**:
  ```bash
  telnet 65.2.35.192 5000
  ```

- **Setting up NAT for Incoming Traffic**:
  ```bash
  sudo iptables \
        -t nat \
        -A PREROUTING \
        -d 172.31.13.55 \
        -p tcp -m tcp --dport 5000 \
        -j DNAT --to-destination 192.168.1.10:5000
# -p specifies a port type and --dport specifies the destination port
# -j specifies the target DNAT to jump to destination IP with port.

# Inside container network, we successfully recieved traffic from internet

telnet 65.2.35.192 5000
  ```

## Conclusion
Creating and connecting network namespaces using virtual Ethernet is a powerful way to simulate complex network environments. This setup is particularly useful for network administrators and developers working with containerized applications. The ability to control and manipulate network environments at this level provides a deeper understanding of networking principles and practices. Happy networking!
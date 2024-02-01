# How to Connect Two Network Namespaces Using a Linux Bridge

Networking in Linux offers a vast playground for administrators, developers, and network enthusiasts. It provides the flexibility to create isolated network environments, such as network namespaces, and connect them in various ways. In this blog, we will guide you through the process of creating two network namespaces and connecting them using a Linux bridge, a traditional and efficient way to interconnect network segments.

## Prerequisites

Before we begin, ensure you have:
- A Linux system with sudo or root access
- The `ip` and `brctl` utilities installed (usually available by default on most Linux distributions)

## Step-by-Step Guide

### Step 1: Open a Terminal

Start by opening a terminal on your Linux host. This will be your main interface for entering the commands required to set up the network namespaces and bridge.

### Step 2: Create First Namespace (ns1)

Create the first network namespace named `ns1` using the following command:

```bash
sudo ip netns add ns1
```

### Step 3: Create Second Namespace (ns2)

Similarly, create the second network namespace named `ns2`:

```bash
sudo ip netns add ns2
```

### Step 4: Create Virtual Ethernet Pair (veth0 and veth1) in Default Namespace

Create a pair of virtual Ethernet interfaces (veth0 and veth1). These will be used to connect the two namespaces:

```bash
sudo ip link add veth0 type veth peer name veth1
```

### Step 5: Move veth0 to ns1

Assign `veth0` to the first namespace (`ns1`):

```bash
sudo ip link set veth0 netns ns1
```

### Step 6: Move veth1 to ns2

Assign `veth1` to the second namespace (`ns2`):

```bash
sudo ip link set veth1 netns ns2
```

### Step 7: Configure IP Addresses in ns1 and ns2

Assign IP addresses to the interfaces within each namespace. This step is crucial for enabling communication between them:

```bash
sudo ip netns exec ns1 ip addr add 10.0.0.1/24 dev veth0
sudo ip netns exec ns2 ip addr add 10.0.0.2/24 dev veth1
```

### Step 8: Bring Up Interfaces in ns1 and ns2

Activate the interfaces within each namespace to enable network traffic:

```bash
sudo ip netns exec ns1 ip link set veth0 up
sudo ip netns exec ns2 ip link set veth1 up
```

### Step 9: Create Linux Bridge (br0)

Create a Linux bridge `br0`. This bridge will be used to connect the two namespaces through the virtual Ethernet interfaces:

```bash
sudo brctl addbr br0
```

### Step 10: Attach veth1 and veth0 to br0

Connect both virtual Ethernet interfaces to the bridge. This step effectively bridges the network between `ns1` and `ns2`:

```bash
sudo brctl addif br0 veth1
sudo brctl addif br0 veth0
```

### Step 11: Bring Up br0

Enable the bridge interface, allowing it to forward packets:

```bash
sudo ip link set br0 up
```

## Testing Connectivity

To verify that the setup is working correctly, attempt to ping each namespace from the other:

- From ns1 to ns2:

  ```bash
  sudo ip netns exec ns1 ping 10.0.0.2
  ```

- From ns2 to ns1:

  ```bash
  sudo ip netns exec ns2 ping 10.0.0.1
  ```

If the pings are successful, congratulations! You have successfully connected two network namespaces using a Linux bridge. This setup is useful for various scenarios, including development, testing network configurations, or learning about Linux networking concepts.

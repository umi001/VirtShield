<br>

# VirtShield: Evaluation of Firewall Performance in Virtualized and Containerized Systems

### Instruction set for setup and experimentation
The experimental setup consists of 3 VMs or Containers each one for a server (receiver), client (traffic generator) and firewall. Experiments are performed on both VMs and docker containers and metrics like throughput, delay for traffic and CPU, Memory utilization for firewall containers are gathered.

#### Experiment benchmark for evaluation
- iperf3
- netperf
- nuttcp
- MySQL
- Redis
- FIO (using NFS)
- Stream

<br>

# Docker
Docker is a powerful platform that enables developers to automate the deployment of applications inside lightweight, portable containers. These containers encapsulate all the necessary dependencies and libraries, ensuring that the application run consistently across different environments. 

This guide will help to set up the experimental topology for firewall evaluation using Docker.

## Setup
Dockerfiles are used to create container images. Dockerfile mentions all the libraries that are required for experiments. Therefore, when creating the image all these libraries will be installed.

<!-- Docker file is used to build images for client, server and firewall.
The docker file name is dockerfile.<Build name>. Build name in this case will be either client, server or firewall -->
- ### Docker image build command
    ```
    docker build -t <Build name> -f dockerfile.<Build name> .
    ```

 <!--Reason behind creating subnet: Provides more control over IP addresses. Can give static IP to each container making the testing easier, where as bridge by default provides dynamic IP.  -->
- ### Create 2 custom networks, client-net and server-net
    ```
    docker network create --subnet 192.168.1.0/24 client-net
    docker network create --subnet 192.168.2.0/24 server-net
    ```

<!-- Run the containers, configure them with the custom network created and provide a static IP -->
- ### Run the client and firewall on the client-net and server on server-net
    ```
    docker run -d --name <container name> --net client-net --ip <IP address> --cpus="2" --memory="1g" <Build name>
    
    ```
    <b>Note:</b>
    - <b>Client:</b> 192.168.1.3
    - <b>Server:</b> 192.168.2.3
    - <b>Firewall:</b> 192.168.1.2 / 192.168.2.2

    Also, the firewall container needs privilege mode. Therefore, the docker run for firewall container is added with <b>--privileged</b> tag. Client also needs privileged access because it needs to change the default gateway.

<!-- On firewall container, setup iptables rules and add server-net to it also -->
- ### Configure the firewall and IP forwarding
    ```
    docker network connect server-net firewall --ip 192.168.2.2 

    docker exec -it firewall bash

    echo 1 > /proc/sys/net/ipv4/ip_forward

    iptables -A FORWARD -i eth0 -o eth0 -s 192.168.2.3 -d 192.168.1.3 -j ACCEPT
    iptables -A FORWARD -i eth0 -o eth0 -s 192.168.1.3 -d 192.168.2.3 -j ACCEPT

    iptables -t nat -A POSTROUTING -s 192.168.1.3 -d 192.168.2.3 -j MASQUERADE
    ```

- ### Configure default routing on client container
    ```
    docker exec -it client bash

    ip route add 192.168.2.3 via 192.168.1.2
    ```
<br>

#### Following this steps creates a setup as following:
1. 3 containers i.e. client, server and firewall
2. client and firewall are in one subnet
3. firewall and server are in one subnet
4. packets from client goes first to firewall then to server
5. packets from server to client does not go through firewall

<br>

## Experiments


#### Copy files between Container and Host
- Copy files from host to VM
    ```
    docker cp <file location on host> <Container name>:<destination location in container>
    ```

- Copy files from container to host
    ```
    dcoker cp <Container name>:<file location in container> <destination location on host>
    ```

<br>

# QEMU
QEMU (Quick Emulator) is an open-source machine emulator and virtualizer that enables users to run virtual machines with different architectures. It provides a powerful environment for testing, development and experimentation, allowing to emulate a wide variety of hardware platforms and guest operating systems.

This guide will help to set up the experimental topology for firewall evaluation using QEMU.

## Setup
Creating virtual machine requires iso (optical disc image) of the operating system whose VM is being created. Such iso image contains all the necessary details for disk layout, operating system and other important setings. VMs are created using these iso images with the configurations for resource allocation to the VM. 

<!-- Creating bridge network for VMs-->
- ### Create two TAP, tap-client and tap-server
    ```
    sudo brctl addbr br0
    sudo ip addr add 192.168.10.1/24 dev br0
    sudo ip link set dev br0 up
    ```

    <b>Note: </b>To connect the VMs to internet via bridge there are two options available.

<br> 
 
1. Add the ethernet interface on the device to the bridge network with dhcp enabled. This exposes the VMs directly to VMs without any intervention from Host Operating System. But implementing this option can get tricky, if not implemented correctly the host device may loose its internet connection as the physical interface is made part of bridge. This method is usually used when VMs on different host machines are required to communicate with each other and it is heavily used in cloud environments. Avoid this by using the NAT forwarding on host when VMs on different host are not required to communicate. 

2. In NAT forwarding, VMs are connected to bridge and all the traffic to and from outisde internet goes through bridge. To connect to outside internet, the bridge use NAT which utilizes Host intervention. In NAT forwarding, packets from the VMs before going to internet are first processed by Host. During this processing, host changes the header fields of the packet like Source IP Address is changed from VMs to Host's. then it also replaces the port number in Transport Layer header to some free port on host machine. Host keeps a track of this translation to forward packets coming to host device with these header values to be forwarded to VM. This is ensures that VMs are connected to internet, but do not need public IP address for them, in this case VMs are given private addresses. Using this method, VMs on the same host machine can also communicate with each other but not with VM on different host machine as the private IP addresses are not allowed in public internet.

<br> 

<!-- Create NAT on Host to allow traffic from bridge and also allow traffic between the VMs connected to bridge if not already.-->
- ### Create NAT on host to allow traffic from bridge
    ```
    sudo sysctl -w net.ipv4.ip_forward=1

    sudo iptables -t nat -A POSTROUTING -o enp3s0 -j MASQUERADE
    
    sudo iptables -A FORWARD -i br0 -o br0 -j ACCEPT
    ```

<!-- Allow the new bridges to be used by qemu -->
- ### Make QEMU use the newly created bridges
    ```
    sudo mkdir -p /etc/qemu/
    sudo nano /etc/qemu/bridge.conf
    ```

    - Add following lines to the file
        ```
        allow br0
        ```
    
    - Ensure that qemu-bridge-helper has correct permissions
        ```
        sudo chmod u+s /usr/lib/qemu/qemu-bridge-helper
        ```

<!-- Created three bash files to start the VMs -->
- ### Command to create the file for VMs
    ```
    qemu-img create -f qcow2 client.qcow2 10G
    ```

    <b>Important Note Regarding QEMU: </b>When creating the VMs using QEMU, it is important to understand that by default QEMU assigns same Virtual MAC Address to each VM. This makes it impossible for them to communicate with other VMs are they all have same MAC address. Therefore, when creating new VM, make sure to give each custom unique MAC address (It may not be unique in the world, but that won't matter as the VMs are not connected to internet directly). 

<br>

- ### Run a VM with QEMU
    ```
    chmod +x ./vm-client.sh
    ./vm-client.sh
    ```

    <b>Note:</b>
    - <b>Client:</b> 192.168.10.4
    - <b>Server:</b> 192.168.10.5
    - <b>Firewall:</b> 192.168.10.3

    <br>

    <b>Note related to bridge configuration: </b>Another method to connect the VMs to internet is using TAP interfaces along with bridge. This requires to create TAP interface for each VM and connect it to appropriate bridge. These TAP interfaces are connected to VM during the creation of VM where the interface is provided. But when the VMs are created using bridge network mode, TAP interfaces are created by default. Therefore, it is easier to create VMs using bridge rather using TAP and having the headache to manage the TAP interface.

<br>

<!-- Provide the Static IP to VMs -->
After creating the VMs, the devices needs to be given network configurations to communicate over internet. Use the following commands to do so:

- ### Provide Static IP to VMs
    ```
    ip addr show
    ```
    
    Output shows available interfaces and associated bridge. (eg. ens3)
    - #### Add IP address to file /etc/netplan/01-netcfg.yaml

        ```
        sudo nano /etc/netplan/01-netcfg.yaml
        ```
    
    - #### Add following lines to the file:
        ```
        network:
            version: 2
            ethernets:
                ens3:
                    addresses:
                        - 192.168.10.x/24  
                    routes:
                        - to: default
                           via: 192.168.10.x
                    nameservers:
                        addresses:
                            - 8.8.8.8
        ```
    - #### Save the file and apply the configurations
        ```
        sudo netplan apply
        ```



## ✅ Troubleshooting Internet Access in QEMU/KVM VMs (firewalld + NAT)

If your VM **can ping internal devices but cannot access the internet**, the issue may lie with `firewalld` silently blocking forwarding or NAT.

---

### 🛠️ Symptoms

* VM can ping gateway (e.g., 192.168.10.1) but cannot reach `8.8.8.8`
* On host, `tcpdump` shows ICMP requests from VM leaving `br0`, but not leaving `eno1`(interface)
* No entries in `conntrack`
* ICMP unreachable messages with "admin prohibited"

---

### 🔍 Step-by-Step Fix (Using firewalld)

#### 1. Check if firewalld is running

```bash
sudo firewall-cmd --state
```

If `running`, continue. If not, your issue is elsewhere.

#### 2. Assign the VM bridge interface (`br0`) to a firewalld zone

```bash
sudo firewall-cmd --permanent --zone=trusted --add-interface=br0
sudo firewall-cmd --reload
```

Verify:

```bash
sudo firewall-cmd --get-active-zones
```

You should see `br0` listed under `trusted`.

#### 3. Enable masquerading for the `trusted` zone

```bash
sudo firewall-cmd --zone=trusted --permanent --add-masquerade
sudo firewall-cmd --reload
```

#### 4. Ensure IP forwarding is enabled

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```


<!-- Make permanent via `/etc/sysctl.conf`:

```ini
net.ipv4.ip_forward = 1
``` -->

#### 5. Verify NAT rule was applied

```bash
sudo nft list chain inet firewalld nat_POST_trusted_allow
```

Look for:

```nft
oifname "eno1" masquerade
```

#### 6. Test from VM

```bash
ping 1.1.1.1
```

Check from host:

```bash
sudo tcpdump -i eno1 icmp
```

If you see packets leaving with the host's IP → ✅ NAT is working.

---

<!-- ### 💾 Backup Script (Re-apply configuration)

```bash
#!/bin/bash

# Assign br0 to trusted zone
firewall-cmd --permanent --zone=trusted --add-interface=br0

# Enable masquerading for trusted zone
firewall-cmd --zone=trusted --permanent --add-masquerade

# Reload firewall
firewall-cmd --reload

# Ensure IP forwarding is enabled
sysctl -w net.ipv4.ip_forward=1

# Optional: Make forwarding persistent
if ! grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf; then
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
fi
```

Make executable:

```bash
chmod +x fix-vm-networking.sh
```

Run anytime:

```bash
sudo ./fix-vm-networking.sh
```

---

### 📌 Include in your README:

> #### If your VM has no internet access:
>
> * Check if the VM’s bridge (`br0`) is managed by firewalld:
>
>   ```bash
>   sudo firewall-cmd --get-active-zones
>   ```
> * If `br0` is missing or unmanaged:
>
>   * Assign it to a zone (e.g., `trusted`)
>   * Enable masquerade in that zone
>   * Ensure IP forwarding is enabled
>   * See the detailed fix in `fix-vm-networking.sh`.
>
> These steps are firewalld-safe and do not require disabling the firewall.
 -->





















    Perform the similar operations on all VMs. These configuration can be applied during the creation of VM. 

<!-- Make the traffic from client to server go through firewall -->
- ### Configure traffic from client to server go through firewall

    Testing environment requires traffic from client to server go through firewall. Since all the VMs are on same subnet network and direct route is available between client and server, creating a default route for server IP address won't help. Since the network among these VMs can be considered as a Switched Network which forwards traffic based on MAC addresses. Therefore, traffic from client needs to first reach firewall using the MAC address of firewall.

    - #### On Client VM, configure ARP table entru to point towards firewall
        ```
        sudo arp -s <IP address of server VM> <MAX address of firewall VM>
        ```
        This points the Server IP address to MAC of firewall, forwarding the traffic to firewall first.

    - #### On Firewall, configure IP forwarding
        ```
        sudo sysctl -w net.ipv4.ip_forward=1

        sudo iptables -A FORWARD -s <IP of client> -d <IP of server> -j ACCEPT
        ```
<br>

#### Following this steps creates a setup as following:
1. 3 VMs i.e. client, server and firewall
2. packets from client goes first to firewall then to server
3. packets from server to client does not go through firewall

<br>

## Install Benchmark

<b> 

1. On client VM
</b>
<br>
Run following command to install all the required benchmarks
    ```
    sudo apt-get install iperf3 netperf nuttcp redis-tools sysbench mysql-client fio traceroute
    ```
<b>
<br>

2. On server VM
</b>
<br>
Run following command to install all the required benchmarks
    ```
    sudo apt-get install iperf3 netperf nuttcp redis-server mysql-server fio
    ```

    <br>
    
    Configure mysql user and database for experiments
    ```
    sudo service mysql start

    sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'password';"
    sudo mysql -e "CREATE USER 'root'@'%' IDENTIFIED BY 'password';"
    sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' GRANT OPTION;"
    sudo mysql -e "FLUSH PRIVILEGES;"

    sudo sed -i "s/bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf

    sudo service mysql restart

    sudo mysql -u root -p'password' -e "CREATE DATABASE benchmark;"
    ```
    <br>
    
    Configure Redis to allow remote connections
    ```
    sudo sed -i "s/^bind.*/bind 0.0.0.0/" /etc/redis/redis.conf

    sudo service redis-server restart
    ```
<br>

#### Copy files between VM and Host
- Install ssh server on VM
    ```
    sudo apt-get install openssh-server
    ```

- Copy files from host to VM
    ```
    scp <file location on host> <VM username>@<VM IP>:<destination location on VM>
    ```

- Copy files from VM to host
    ```
    scp <VM username>@<VM IP>:<file location on VM> <destination location on host>
    ```

- Use '-r' flag to copy directories
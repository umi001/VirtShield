
# VirtShield – QEMU VM Setup Guide

This guide walks you through setting up the QEMU-based VM environment for evaluating firewall performance using VirtShield. The topology consists of three VMs: `client`, `firewall`, and `server`. All VMs communicate over a bridged virtual network `br0`.

---

## ✅ Step 1: Prerequisites

Make sure the following packages are installed:

```bash
sudo apt update
sudo apt install qemu qemu-kvm bridge-utils virt-manager
```

Ensure you have an Ubuntu ISO (e.g., `ubuntu.iso`) placed in your project/VMs directory.

---

## ✅ Step 2: Setup Networking (Run Once)

This script sets up the bridge network (`br0`) and enables NAT to allow VM internet access.

```bash
./setup_vm.sh
```

---

## ✅ Step 3: Create VM Disk Images

This script will create 10G disk images for the three VMs.

```bash
./create_vm_disks.sh
```

---

## ✅ Step 4: Launch the VMs

Each script launches one VM using the `ubuntu.iso` to install Ubuntu Server.

```bash
./vm-client.sh
./vm-firewall.sh
./vm-server.sh
```

Follow the on-screen instructions to complete Ubuntu installation in each VM. Use default options unless otherwise required.

---

## ✅ Step 5: Configure Static IPs Inside Each VM

After installation, log into each VM and configure networking manually:

### 🖧 VM Interface Name

Run the following to check the active interface:

```bash
ip a
```

Usually, it will be `ens3`.

---

### 📦 5.1 On `client` VM

```bash
sudo nano /etc/netplan/01-netcfg.yaml
```

```yaml
network:
  version: 2
  ethernets:
    ens3:
      dhcp4: no
      addresses: 192.168.10.4/24
      routes:
        - to: default
          via: 192.168.10.1
      nameservers:
        addresses: 8.8.8.8
```

```bash
sudo netplan apply
```

---

### 🔥 5.2 On `firewall` VM

```bash
sudo nano /etc/netplan/01-netcfg.yaml
```

```yaml
network:
  version: 2
  ethernets:
    ens3:
      dhcp4: no
      addresses: 192.168.10.3/24
      routes:
        - to: default
          via: 192.168.10.1
      nameservers:
        addresses: 8.8.8.8
```

```bash
sudo netplan apply
sudo sysctl -w net.ipv4.ip_forward=1
```

---

### 📦 5.3 On `server` VM

```bash
sudo nano /etc/netplan/01-netcfg.yaml
```

```yaml
network:
  version: 2
  ethernets:
    ens3:
      dhcp4: no
      addresses: 192.168.10.5/24
      routes:
        - to: default
          via: 192.168.10.1
      nameservers:
        addresses: 8.8.8.8
```

```bash
sudo netplan apply
```

---

## Force Traffic Through Firewall

To redirect traffic from `client` to `server` through `firewall`, configure static ARP:

On client VM:
```bash
sudo arp -s 192.168.10.5 <MAC_of_firewall>
```

You can get the firewall MAC via:
```bash
ip link show ens3
```

Then allow forwarding on firewall:
```bash
sudo iptables -A FORWARD -s 192.168.10.4 -d 192.168.10.5 -j ACCEPT
```

---

## ✅ Step 6: Install Benchmark Tools

Install the required benchmark packages inside the VMs.

### On `client` VM:
```bash
sudo apt install iperf3 netperf nuttcp redis-tools sysbench mysql-client fio traceroute
```

### On `server` VM:
```bash
sudo apt install iperf3 netperf nuttcp redis-server mysql-server fio

sudo service mysql start
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'password';"
sudo mysql -e "CREATE USER 'root'@'%' IDENTIFIED BY 'password';"
sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;"
sudo mysql -e "FLUSH PRIVILEGES;"
sudo sed -i "s/^bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf
sudo service mysql restart
sudo mysql -u root -p'password' -e "CREATE DATABASE benchmark;"

sudo sed -i "s/^bind.*/bind 0.0.0.0/" /etc/redis/redis.conf
sudo service redis-server restart
```

---

## 🔄 Copy Files Between Host and VMs

### Install SSH Server inside VMs:
```bash
sudo apt install openssh-server
```

### From host to VM:
```bash
scp file.txt username@192.168.10.4:/home/username/
```

### From VM to host:
```bash
scp username@192.168.10.4:/home/username/file.txt .
```

---

## ✅ You're Ready!

Your QEMU-based VirtShield setup is now ready for experiments. Launch benchmarking tools like `iperf3`, `netperf`, or `nuttcp` between client and server to evaluate firewall performance.

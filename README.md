# VirtShield: Unified Setup Guide (VM and Container)

## Overview

VirtShield is a research framework for evaluating security mechanisms in both **virtual machines (VMs)** and **containers**.\
It enables controlled experiments with security models deployed in either kernel-space or user-space, while supporting end-to-end benchmarking of both **network performance** and **microarchitectural behavior**.

Two deployment options are supported:

- **VM-based setup** using QEMU
- **Container-based setup** (for this repository, we rely on **Docker**. Other runtimes may require adjustments.)

Both setups follow the same topology:

- **Client**: traffic generator
- **Model**: security model host (where the security model is deployed and tested)
- **Server**: traffic receiver

Two execution modes are available:

- **direct**: client sends traffic directly to server (used to establish performance baseline)
- **model**: client routes traffic through the security model host (used to evaluate security model impact)

---

## Part I. VM-Based Setup
## Step-by-Step VMs Setup
We would create, connect, and configure three VMs: a client (which contains the benchmarks), a server (that receives and processes the packets), and a model that mimics a cloud infrastructure, where the model VMs host the security module, either implemented in user-space or kernel-space.

### Prerequisites

- QEMU installed on the host
- Ubuntu ISO (`ubuntu-22.04.5-live-server-amd64.iso`) in working directory
  - Download: [Ubuntu 22.04.5 ISO](https://releases.ubuntu.com/22.04/)
- If using another ISO, update its name in `vm-client.sh`, `vm-model.sh`, and `vm-server.sh`
- Scripts required:\
  `setup.sh`, `vm-client.sh`, `vm-model.sh`, `vm-server.sh`, `vm_setup_file_transfer.sh`, `setup_client.sh`, `setup_model.sh`

### 1. Host Setup

```bash
./setup.sh
```

This creates the Linux bridge (`br0`), sets up NAT and routing, prepares QEMU networking, and creates empty disk images (`client.qcow2`, `model.qcow2`, `server.qcow2`).

### 2. Launch VMs

```bash
./vm-client.sh
./vm-model.sh
./vm-server.sh
```

Each script launches its VM with proper MAC, disk, and ISO. During the initial boot, follow the on‑screen installation procedures to set up Ubuntu inside the VM. It is recommended to go with the default options during installation unless specific customization is needed.

### 3. VM Network Configuration

| VM     | MAC Address       | IP Address   | Role                |
| ------ | ----------------- | ------------ | ------------------- |
| Client | 52:54:00:12:34:01 | 192.168.10.4 | Traffic Generator   |
| Model  | 52:54:00:12:34:02 | 192.168.10.3 | Security Model Host |
| Server | 52:54:00:12:34:03 | 192.168.10.5 | Receiver            |

To set static IP addresses inside each VM, configure **netplan** as below. At this stage, you may need to type the following code directly into each VM console, since the VMs do not yet have an IP address to allow remote connection. The interface name may be `ens3` as shown. You can confirm the correct name by running `ip link` inside the VM; look for the primary network interface (commonly ens3 in QEMU).; adjust if your VM presents a different device name:

#### 5.1 On `client` VM

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

#### 5.2 On `model` VM

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
```

---

#### 5.3 On `server` VM

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

> These static configurations ensure each VM is reachable at the fixed IPs shown in the table above.


###<img width="3729" height="1092" alt="VirtShield" src="https://github.com/user-attachments/assets/7cb7eeeb-5e97-46fc-a4e5-26ac3e9f9950" />


### 4. Transfer Setup Scripts

```bash
./vm_setup_file_transfer.sh
```

> To enable SSH into VMs, install OpenSSH Server inside each VM (see [Ubuntu documentation](https://documentation.ubuntu.com/server/how-to/security/openssh-server/index.html) for details):
>
> ```bash
> sudo apt install openssh-server
> ```

### 5. Run Setup Inside VMs

- Client:

  ```bash
  ./setup_client.sh <direct|model>
  ```
  - Use `direct` if traffic should go straight from client to server.
  - Use `model` if traffic should go through the firewall (model VM).
  -  Run ``` sudo apt-get install iperf3 netperf nuttcp redis-tools sysbench mysql-client fio traceroute ``` to install all the benchmarks.

  **direct**: client sends traffic straight to server (used to establish performance baseline).\
  **model**: client routes traffic through the security model host (used to evaluate security model impact).

- Model:

  ```bash
  ./setup_model.sh
  ```

- Server:&#x20;

  ```
  ./setup_server.sh
  ```

### 6. Deploy Security Model

- Source code in `~/VirtShield/`:\
  `kernel_space.c`, `user_space_model.c`, `packet_queue.c/h`, `Makefile`, `performance/`
- Build:
  ```bash
  cd ~/VirtShield
  make
  ```
  Builds `kernel_space.ko` and `user_space_model[packet_sniffer]`.
- Run:
  ```bash
  sudo insmod kernel_space.ko     # kernel-space
  ./user_space_model              # user-space [packet_sniffer]
  ```
- Unload kernel module:
  ```bash
  sudo rmmod kernel_space
  ```

### 7. Performance Measurement

- **Network Performance (Client VM)**:
  ```bash
  ./run_test.sh
  ```
- **Microarchitectural Profiling (Model VM)**:
  ```bash
  cd ~/VirtShield/performance
  sudo ./run_perf.sh <logdir> <mode>
  # mode: 0 = user-space, 1 = kernel-space
  ```
### 8. Manually running the benchmarks 
The `Benchmarks` folder contains the scripts to run each benchmark manually. Users are encouraged to add additional benchmarks. The `Results` and `Results_Summary` contain results and logs for our runs of firewall and Suricata.
### 9. Logs and Debugging

| Component       | Command/File                             |   |
| --------------- | ---------------------------------------- | - |
| Kernel logs     | `dmesg`, \`sudo journalctl -k\`          |   |
| User-space logs | redirect stdout from binary              |   |
| Perf outputs    | `perf_kernel.log`, `perf_user_space.log` |   |
| Perf raw data   | `perf_kernel.data` + `perf report`       |   |

### 10. Troubleshooting: No Internet in VMs

If VMs can ping `192.168.10.1` but not the internet, first check whether this is caused by `firewalld` blocking forwarding rules. You can check with:

```bash
sudo firewall-cmd --state
```

If it shows `running`, continue with the fix below. If not, your issue is elsewhere:

```bash
sudo firewall-cmd --permanent --zone=trusted --add-interface=br0
sudo firewall-cmd --reload
sudo firewall-cmd --zone=trusted --permanent --add-masquerade
sudo firewall-cmd --reload
sudo sysctl -w net.ipv4.ip_forward=1
```

---

## Part II. Container-Based Setup

# VirtShield Container Setup Guide

This guide walks you through the **Container-based setup** for the VirtShield platform. It mirrors the VM-based setup but uses lightweight containers to emulate the client, server, and firewall environments.

---
### Prerequisites

- Container runtime (for this repo, we rely on **Docker**)
- Working directory: `VirtShield/`
- All setup scripts and Dockerfiles present

### 1. Launch Topology

```bash
cd setup
./setup_containers.sh <direct|model>
```

**Container Network Configuration**

| Container | IP (client-net) | IP (server-net) | Role                |
| --------- | --------------- | --------------- | ------------------- |
| Client    | 192.168.1.3     | 192.168.2.4\*   | Traffic Generator   |
| Model     | 192.168.1.2     | 192.168.2.2     | Security Model Host |
| Server    | -               | 192.168.2.3     | Receiver            |

&#x20;\*\*What Happens in \*\*`` `setup_containers.sh ``\`

- Creates two networks (`client-net`, `server-net`)
- Builds images for client, model, server
- Launches containers with fixed IPs
- Configures routing in model mode via IP forwarding and `iptables`
- File Copy into Containers

### 2. Modify and Deploy Security Model

Once the containers are up and the required files are copied in, the user is expected to:

- Navigate to `/root/performance/workspace/` inside the model container
- Modify the required C source files to implement their own security logic
  - For example: `kernel_space.c`, `user_space_model.c`, `packet_queue.c`, etc.

After modifying the files, inside the model container:

```bash
cd /root/performance/workspace
make
```

This produces `kernel_space.ko` and `user_space_model[packet_sniffer]`.

Run:

```bash
sudo insmod kernel_space.ko      # kernel-space
./user_space_model &             # user-space
```

Unload kernel module:

```bash
sudo rmmod kernel_space
```

### 3. Performance Measurement

- **Client container (network metrics)**:
  ```bash
  ./run_test.sh
  ```
- **Model container (microarchitectural profiling)**:
  ```bash
  cd /root/performance
  sudo ./run_perf.sh <logdir>
  ```

### 4. Logs and Debugging

| Component        | Command/Path                |
| ---------------- | --------------------------- |
| Kernel logs      | `dmesg`, `journalctl -k`    |
| User logs        | redirect stdout from binary |
| Performance logs | `/root/performance/*.log`   |

---

## Summary

VirtShield provides a unified framework to **develop, deploy, and evaluate security models** in both VM and container environments.\
The workflow is consistent:

1. Modify provided C source files (`kernel_space.c`, `user_space_model.c`, `packet_queue.c`)
2. Rebuild (`make`)
3. Deploy (insmod/run binary)
4. Benchmark performance (network + microarchitectural)


#!/bin/bash
# Create disk images for client, firewall, and server VMs

set -e

echo "[+] Creating VM disk images (10G each)..."

for vm in client firewall server; do
    if [ -f "$vm.qcow2" ]; then
        echo "[!] $vm.qcow2 already exists. Skipping..."
    else
        qemu-img create -f qcow2 $vm.qcow2 10G
        echo "  Created $vm.qcow2"
    fi
done

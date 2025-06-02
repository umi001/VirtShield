#!/bin/bash

# Persistent setup script for VirtShield VM networking using QEMU

set -e

BRIDGE="br0"
BR_IP="192.168.10.1/24"

DEFAULT_IF=$(ip route | grep default | awk '{print $5}')
echo "[+] Detected gateway interface: $DEFAULT_IF"

echo "[+] Creating bridge $BRIDGE with IP $BR_IP"
sudo brctl addbr $BRIDGE 2>/dev/null || echo "Bridge $BRIDGE already exists"
sudo ip addr add $BR_IP dev $BRIDGE 2>/dev/null || echo "$BRIDGE already has IP"
sudo ip link set dev $BRIDGE up

echo "[+] Enabling IP forwarding and NAT..."
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -A POSTROUTING -o "$DEFAULT_IF" -j MASQUERADE
sudo iptables -A FORWARD -i $BRIDGE -o $BRIDGE -j ACCEPT

echo "[+] Allowing QEMU to use bridge"
echo "allow $BRIDGE" | sudo tee /etc/qemu/bridge.conf >/dev/null
sudo chmod u+s /usr/lib/qemu/qemu-bridge-helper

echo "[+] VM network bridge $BRIDGE setup complete!"

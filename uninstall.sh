#!/bin/bash
# Script to uninstall WireGuard VPN configuration and clean up files

echo "======================================"
# Stop server interface if active
if [ -f "/etc/wireguard/wg0.conf" ]; then
    echo "[*] Stopping WireGuard Server interface (wg0)..."
    sudo wg-quick down wg0 2>/dev/null || true
    echo "[*] Removing Server configuration from /etc/wireguard/..."
    sudo rm -f /etc/wireguard/wg0.conf
fi

# Stop client interface if active
if [ -f "/etc/wireguard/client_wg0.conf" ]; then
    echo "[*] Stopping WireGuard Client interface (client_wg0)..."
    sudo wg-quick down client_wg0 2>/dev/null || true
    echo "[*] Removing Client configuration from /etc/wireguard/..."
    sudo rm -f /etc/wireguard/client_wg0.conf
fi

# Clean up local keys and configuration files in the current directory
echo "[*] Cleaning up local key and config files..."
rm -f server_private.key server_public.key wg0.conf
rm -f client_private.key client_public.key client_wg0.conf

echo "[*] Uninstall complete!"
echo "======================================"

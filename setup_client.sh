#!/bin/bash
# Script to setup WireGuard Client

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <server_public_ip_or_domain> <server_public_key>"
    echo "Example: $0 203.0.113.5 <server_pub_key>"
    exit 1
fi

SERVER_ENDPOINT=$1
SERVER_PUB_KEY=$2

# Configuration variables
WG_IFACE="wg0"
WG_IP="10.8.0.2/24"
WG_PORT="51820"
ALLOWED_IPS="10.8.0.0/24" # Set to 0.0.0.0/0 to route all traffic through VPN

echo "======================================"
echo "    WireGuard Client Setup Script"
echo "======================================"

# Check if wireguard is installed
if ! command -v wg &> /dev/null; then
    echo "WireGuard is not installed. Please install it first."
    exit 1
fi

echo "[*] Generating Client Keys..."
wg genkey | tee client_private.key | wg pubkey > client_public.key
CLIENT_PRIV_KEY=$(cat client_private.key)
CLIENT_PUB_KEY=$(cat client_public.key)

echo "[*] Creating Client Configuration (client_${WG_IFACE}.conf)..."
cat <<EOF > client_${WG_IFACE}.conf
[Interface]
Address = ${WG_IP}
PrivateKey = ${CLIENT_PRIV_KEY}

[Peer]
PublicKey = ${SERVER_PUB_KEY}
Endpoint = ${SERVER_ENDPOINT}:${WG_PORT}
AllowedIPs = ${ALLOWED_IPS}
PersistentKeepalive = 25
EOF

echo "[*] Client setup complete!"
echo ""
echo "IMPORTANT: You must add this client to the server's configuration."
echo "Run the following on the SERVER or append to server's wg0.conf:"
echo "
[Peer]
PublicKey = ${CLIENT_PUB_KEY}
AllowedIPs = 10.8.0.2/32
"

read -p "Do you want to copy client_${WG_IFACE}.conf to /etc/wireguard/ on this machine now? (y/n): " confirm
if [[ $confirm =~ ^[Yy]$ ]]; then
    echo "[*] Copying configuration to /etc/wireguard/..."
    sudo cp client_${WG_IFACE}.conf /etc/wireguard/
    sudo chmod 600 /etc/wireguard/client_${WG_IFACE}.conf
    read -p "Do you want to start the WireGuard client interface now? (y/n): " start_confirm
    if [[ $start_confirm =~ ^[Yy]$ ]]; then
        sudo wg-quick up client_${WG_IFACE}
        echo "Once connected, you can SSH into the server using: ssh user@10.8.0.1"
    fi
else
    echo "To connect to the VPN later:"
    echo "1. sudo cp client_${WG_IFACE}.conf /etc/wireguard/"
    echo "2. sudo wg-quick up client_${WG_IFACE}"
fi
echo "======================================"

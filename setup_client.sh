#!/bin/bash
# Script to setup WireGuard Client

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <server_public_ip_or_domain> <server_public_key> [server_ssh_user] [server_ssh_port]"
    echo "Example: $0 203.0.113.5 <server_pub_key> hiengyen 22"
    exit 1
fi

SERVER_ENDPOINT=$1
SERVER_PUB_KEY=$2
SERVER_SSH_USER=$3
SERVER_SSH_PORT=${4:-22}

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

REGISTRATION_SUCCESS=false
if [ -n "$SERVER_SSH_USER" ]; then
    echo "[*] Automatically registering client on server via SSH..."
    ssh -p "$SERVER_SSH_PORT" -t "${SERVER_SSH_USER}@${SERVER_ENDPOINT}" "sudo bash -c 'cat >> /etc/wireguard/wg0.conf <<EOF

[Peer]
PublicKey = ${CLIENT_PUB_KEY}
AllowedIPs = ${WG_IP%/24}/32
EOF
wg syncconf wg0 <(wg-quick strip wg0)'"
    if [ $? -eq 0 ]; then
        REGISTRATION_SUCCESS=true
        echo "[*] Successfully registered client on server!"
    else
        echo "[!] Failed to automatically register client via SSH."
    fi
else
    read -p "Do you want to automatically register this client on the server via SSH? (y/n): " ssh_confirm
    if [[ $ssh_confirm =~ ^[Yy]$ ]]; then
        read -p "Enter SSH username for server (${SERVER_ENDPOINT}): " SERVER_SSH_USER
        read -p "Enter SSH port [22]: " SERVER_SSH_PORT
        SERVER_SSH_PORT=${SERVER_SSH_PORT:-22}
        ssh -p "$SERVER_SSH_PORT" -t "${SERVER_SSH_USER}@${SERVER_ENDPOINT}" "sudo bash -c 'cat >> /etc/wireguard/wg0.conf <<EOF

[Peer]
PublicKey = ${CLIENT_PUB_KEY}
AllowedIPs = ${WG_IP%/24}/32
EOF
wg syncconf wg0 <(wg-quick strip wg0)'"
        if [ $? -eq 0 ]; then
            REGISTRATION_SUCCESS=true
            echo "[*] Successfully registered client on server!"
        else
            echo "[!] Failed to register client. You will need to add it manually."
        fi
    fi
fi

if [ "$REGISTRATION_SUCCESS" = false ]; then
    echo "IMPORTANT: You must manually add this client to the server's configuration."
    echo "Run the following on the SERVER or append to server's wg0.conf:"
    echo "
[Peer]
PublicKey = ${CLIENT_PUB_KEY}
AllowedIPs = ${WG_IP%/24}/32
"
fi

echo "[*] Copying configuration to /etc/wireguard/..."
sudo cp client_${WG_IFACE}.conf /etc/wireguard/
sudo chmod 600 /etc/wireguard/client_${WG_IFACE}.conf
echo "[*] Starting the WireGuard client interface..."
sudo wg-quick up client_${WG_IFACE}
echo "Once connected, you can SSH into the server using: ssh user@10.8.0.1"
echo "======================================"

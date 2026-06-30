#!/bin/bash
WG_IFACE="wg0"

# Check if wireguard is installed
if ! command -v wg &> /dev/null; then
    echo "WireGuard is not installed. Please install it first."
    exit 1
fi

# If config already exists, just install it and exit
if [ -f "client_${WG_IFACE}.conf" ]; then
    echo "======================================"
    echo "    WireGuard Client Setup Script"
    echo "======================================"
    echo "[*] Found existing client_${WG_IFACE}.conf configuration."
    echo "[*] Copying configuration to /etc/wireguard/..."
    sudo cp client_${WG_IFACE}.conf /etc/wireguard/
    sudo chmod 600 /etc/wireguard/client_${WG_IFACE}.conf
    echo "[*] Starting the WireGuard client interface..."
    sudo wg-quick up client_${WG_IFACE}
    echo "Once connected, you can SSH into the server using: ssh user@10.8.0.1"
    echo "======================================"
    exit 0
fi

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
WG_IP="10.8.0.2/32"
WG_PORT="51820"
ALLOWED_IPS="10.8.0.0/24" # Set to 0.0.0.0/0 to route all traffic through VPN

echo "[*] Generating Client Keys..."
wg genkey | tee client_private.key | wg pubkey > client_public.key
CLIENT_PRIV_KEY=$(cat client_private.key)
CLIENT_PUB_KEY=$(cat client_public.key)

echo "[*] Creating Client Configuration (client_${WG_IFACE}.conf)..."
cat <<EOF > client_${WG_IFACE}.conf
[Interface]
PrivateKey = ${CLIENT_PRIV_KEY}
Address = ${WG_IP}
ListenPort = 51820
DNS = 1.1.1.1

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
    ssh -p "$SERVER_SSH_PORT" -t "${SERVER_SSH_USER}@${SERVER_ENDPOINT}" "sudo sed -i '/# Client1  EdgeNode/,/AllowedIPs = ${WG_IP/\//\\\/}/ s|PublicKey  =.*|PublicKey  = ${CLIENT_PUB_KEY}|' /etc/wireguard/wg0.conf && sudo wg syncconf wg0 <(sudo wg-quick strip wg0)"
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
        ssh -p "$SERVER_SSH_PORT" -t "${SERVER_SSH_USER}@${SERVER_ENDPOINT}" "sudo sed -i '/# Client1  EdgeNode/,/AllowedIPs = ${WG_IP/\//\\\/}/ s|PublicKey  =.*|PublicKey  = ${CLIENT_PUB_KEY}|' /etc/wireguard/wg0.conf && sudo wg syncconf wg0 <(sudo wg-quick strip wg0)"
        if [ $? -eq 0 ]; then
            REGISTRATION_SUCCESS=true
            echo "[*] Successfully registered client on server!"
        else
            echo "[!] Failed to register client. You will need to update it manually."
        fi
    fi
fi

if [ "$REGISTRATION_SUCCESS" = false ]; then
    echo "IMPORTANT: You must manually update this client's public key on the server's /etc/wireguard/wg0.conf."
    echo "Find the [Peer] block for Client1 EdgeNode and set:"
    echo "PublicKey  = ${CLIENT_PUB_KEY}"
    echo ""
    echo "Then reload configuration on the server: sudo wg syncconf wg0 <(sudo wg-quick strip wg0)"
fi

echo "[*] Copying configuration to /etc/wireguard/..."
sudo cp client_${WG_IFACE}.conf /etc/wireguard/
sudo chmod 600 /etc/wireguard/client_${WG_IFACE}.conf
echo "[*] Starting the WireGuard client interface..."
sudo wg-quick up client_${WG_IFACE}
echo "Once connected, you can SSH into the server using: ssh user@10.8.0.1"
echo "======================================"

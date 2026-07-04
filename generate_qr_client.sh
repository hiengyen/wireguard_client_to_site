#!/bin/bash
# Script to generate a WireGuard client configuration and display it as a QR code

if ! command -v wg &> /dev/null; then
    echo "WireGuard (wg) is not installed. Please install it first."
    exit 1
fi

if ! command -v qrencode &> /dev/null; then
    echo "qrencode is not installed. Please install it first (e.g., sudo apt install qrencode)."
    exit 1
fi

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <server_public_ip_or_domain> <server_public_key> [client_name] [client_ip]"
    echo "Example: $0 203.0.113.5 <server_pub_key> mobile 10.8.0.3/32"
    exit 1
fi

SERVER_ENDPOINT=$1
SERVER_PUB_KEY=$2
CLIENT_NAME=${3:-"mobile_client"}
CLIENT_IP=${4:-"10.8.0.3/32"}
WG_PORT="51820"
ALLOWED_IPS="10.8.0.0/24" # Set to 0.0.0.0/0 to route all traffic through VPN

echo "[*] Generating Keys for ${CLIENT_NAME}..."
CLIENT_PRIV_KEY=$(wg genkey)
CLIENT_PUB_KEY=$(echo "${CLIENT_PRIV_KEY}" | wg pubkey)

CONF_FILE="${CLIENT_NAME}.conf"

echo "[*] Creating Client Configuration (${CONF_FILE})..."
cat <<EOF > "${CONF_FILE}"
[Interface]
PrivateKey = ${CLIENT_PRIV_KEY}
Address = ${CLIENT_IP}
DNS = 1.1.1.1

[Peer]
PublicKey = ${SERVER_PUB_KEY}
Endpoint = ${SERVER_ENDPOINT}:${WG_PORT}
AllowedIPs = ${ALLOWED_IPS}
PersistentKeepalive = 25
EOF

echo "[*] Client setup complete!"
echo ""
echo "======================================"
echo "IMPORTANT: You must manually update this client's public key on the server's /etc/wireguard/wg0.conf."
echo "Add the following block to the server configuration:"
echo ""
echo "[Peer]"
echo "# ${CLIENT_NAME}"
echo "PublicKey  = ${CLIENT_PUB_KEY}"
echo "AllowedIPs = ${CLIENT_IP}"
echo ""
echo "Then reload configuration on the server: sudo wg syncconf wg0 <(sudo wg-quick strip wg0)"
echo "======================================"
echo "[*] Scan the QR code below using the WireGuard mobile app:"
echo ""
qrencode -t ansiutf8 < "${CONF_FILE}"
echo ""
echo "Configuration saved to: ${CONF_FILE}"

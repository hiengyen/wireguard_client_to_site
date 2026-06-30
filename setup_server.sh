#!/bin/bash
# Script to setup WireGuard Server (Site)

# Configuration variables
WG_IFACE="wg0"
WG_PORT="51820"
WG_IP="10.8.0.1/24"
DEFAULT_ROUTE_IFACE=$(ip route ls default | awk '{print $5}')
DEFAULT_ROUTE_IFACE=${DEFAULT_ROUTE_IFACE:-ens5}

echo "======================================"
echo "    WireGuard Server Setup Script"
echo "======================================"

# Check if wireguard is installed
if ! command -v wg &> /dev/null; then
    echo "WireGuard is not installed. Please install it first."
    exit 1
fi

echo "[*] Generating Server Keys..."
wg genkey | tee server_private.key | wg pubkey > server_public.key
SERVER_PRIV_KEY=$(cat server_private.key)
SERVER_PUB_KEY=$(cat server_public.key)

echo "[*] Creating Server Configuration (${WG_IFACE}.conf)..."
cat <<EOF > ${WG_IFACE}.conf
[Interface]
Address = ${WG_IP}
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIV_KEY}

PostUp = sysctl -w net.ipv4.ip_forward=1
PostUp = iptables -A FORWARD -i ${WG_IFACE} -o ${DEFAULT_ROUTE_IFACE} -j ACCEPT
PostUp = iptables -A FORWARD -i ${DEFAULT_ROUTE_IFACE} -o ${WG_IFACE} -m state --state ESTABLISHED,RELATED -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o ${DEFAULT_ROUTE_IFACE} -j MASQUERADE

PostDown = iptables -D FORWARD -i ${WG_IFACE} -o ${DEFAULT_ROUTE_IFACE} -j ACCEPT
PostDown = iptables -D FORWARD -i ${DEFAULT_ROUTE_IFACE} -o ${WG_IFACE} -m state --state ESTABLISHED,RELATED -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o ${DEFAULT_ROUTE_IFACE} -j MASQUERADE

# Add peers below
[Peer]
# Client1  EdgeNode
PublicKey  = AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
AllowedIPs = 10.8.0.2/32
EOF

echo "[*] Server setup complete!"
echo ""
echo "Server Public Key (Share this with clients):"
echo "  ${SERVER_PUB_KEY}"
echo ""

echo "[*] Copying configuration to /etc/wireguard/..."
sudo cp ${WG_IFACE}.conf /etc/wireguard/
sudo chmod 600 /etc/wireguard/${WG_IFACE}.conf
echo "[*] Starting WireGuard interface ${WG_IFACE}..."
sudo wg-quick up ${WG_IFACE}

echo ""
echo "IMPORTANT: To allow clients to connect to this server from outside:"
echo "Forward UDP port ${WG_PORT} on your ISP Modem to this machine's local IP address."
echo "======================================"

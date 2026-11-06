#!/bin/bash
setxkbmap es

# Setup script: bind9 + network config + DNS zone
# Run as normal user: bash setup-dns.sh  (uses sudo internally)

# Ask for the sudo password once at the start
sudo -v || { echo "sudo is required."; exit 1; }

# ---------- FIXED VALUES ----------
IFACE="eno1"
FORWARDER="192.168.99.99"

# ---------- DEFAULT VALUES (used if you just press Enter) ----------
DEF_IP="192.168.202.17"
DEF_NETMASK="255.255.0.0"
DEF_GATEWAY="192.168.88.88"
DEF_ZONE="hramos.cat"

# ---------- FUNCTION: ask with default value ----------
ask() {
    local prompt="$1" default="$2" answer=""
    read -r -p "$prompt [$default]: " answer
    echo "${answer:-$default}"
}

# ---------- 1. INSTALL PACKAGES ----------
echo ">>> Installing packages..."
sudo apt update
sudo apt install -y bind9 dnsutils nmap flameshot

# ---------- ASK FOR DATA ----------
echo
IP=$(ask "IP address" "$DEF_IP")
NETMASK=$(ask "Netmask" "$DEF_NETMASK")
GATEWAY=$(ask "Gateway" "$DEF_GATEWAY")
ZONE=$(ask "Zone name" "$DEF_ZONE")

echo
echo "Using: IP=$IP  NETMASK=$NETMASK  GATEWAY=$GATEWAY  ZONE=$ZONE"
echo

# ---------- 2. /etc/network/interfaces ----------
echo ">>> Configuring /etc/network/interfaces..."
sudo cp /etc/network/interfaces /etc/network/interfaces.bak

{
    echo "auto lo"
    echo "iface lo inet loopback"
    echo ""
    echo "auto $IFACE"
    echo "iface $IFACE inet static"
    printf "\taddress %s\n" "$IP"
    printf "\tnetmask %s\n" "$NETMASK"
    printf "\tgateway %s\n" "$GATEWAY"
} | sudo tee /etc/network/interfaces > /dev/null

echo ">>> Restarting networking (stop, wait 5s, start)..."
sudo systemctl stop networking
sleep 5
sudo systemctl start networking

# ---------- 3. /etc/resolv.conf ----------
echo ">>> Configuring /etc/resolv.conf..."
sudo cp /etc/resolv.conf /etc/resolv.conf.bak
echo "nameserver $IP" | sudo tee /etc/resolv.conf > /dev/null

# ---------- 4. /etc/bind/named.conf.options ----------
echo ">>> Configuring /etc/bind/named.conf.options..."
sudo cp /etc/bind/named.conf.options /etc/bind/named.conf.options.bak

{
    echo "options {"
    printf "\tdirectory \"/var/cache/bind\";\n"
    printf "\tforwarders {\n"
    printf "\t\t%s;\n" "$FORWARDER"
    printf "\t};\n"
    echo "};"
} | sudo tee /etc/bind/named.conf.options > /dev/null

# ---------- 5. /etc/bind/named.conf.local ----------
echo ">>> Adding zone to /etc/bind/named.conf.local..."
sudo cp /etc/bind/named.conf.local /etc/bind/named.conf.local.bak

{
    echo ""
    echo "zone $ZONE {"
    printf "\ttype master;\n"
    printf "\tfile \"/etc/bind/db.%s\";\n" "$ZONE"
    echo "};"
} | sudo tee -a /etc/bind/named.conf.local > /dev/null

# ---------- 6. ZONE FILE ----------
echo ">>> Creating /etc/bind/db.$ZONE..."
{
    echo "\$TTL 1w"
    echo ""
    printf "@\tIN\tSOA\tdns1.%s.\thugo.%s. (\n" "$ZONE" "$ZONE"
    printf "\t1\n"
    printf "\t12h\n"
    printf "\t4h\n"
    printf "\t4d\n"
    printf "\t2h\n"
    echo ")"
    echo ""
    printf "@\tIN\tNS\tdns1.%s.\n" "$ZONE"
    printf "dns1\tIN\tA\t%s\n" "$IP"
    printf "@\tIN\tA\t%s\n" "$IP"
} | sudo tee "/etc/bind/db.$ZONE" > /dev/null

# ---------- CHECKS AND RESTART ----------
echo ">>> Checking configuration..."
sudo named-checkconf && echo "named.conf OK"
sudo named-checkzone "$ZONE" "/etc/bind/db.$ZONE"

sudo systemctl restart bind9
sudo systemctl status bind9 --no-pager | head -n 5

echo "Done."

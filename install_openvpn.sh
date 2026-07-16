#!/bin/bash

# ==============================================================================
# SCRIPT DE INSTALACIÓN COMPLETA DE OPENVPN SERVER (PERSONALIZADO)
# ==============================================================================
# - Configuración custom (tun1, tls-crypt, logger events)
# - Acceso dinámico a la LAN local 
# - Reglas de IPTables persistentes
# ==============================================================================

if [[ $EUID -ne 0 ]]; then 
    echo "Error: Este script debe ejecutarse como root (usa sudo)."
    exit 1
fi

TARGET_USER=${SUDO_USER:-$USER}
TARGET_HOME=$(eval echo ~$TARGET_USER)
OUTPUT_BASE="$TARGET_HOME/ovpn"
EASYRSA_DIR="/etc/openvpn/easy-rsa-tun1"
CCD_DIR="/etc/openvpn/server/ccd"
LOG_DIR="/var/log"

SERVER_IP=$(curl -s https://ipinfo.io/ip || curl -s https://api.ipify.org || hostname -I | awk '{print $1}')

# ------------------------------------------------------------------------------
# DETECCIÓN DINÁMICA DE LA RED LOCAL
# ------------------------------------------------------------------------------
NIC=$(ip -4 route show to default | grep -oP '(?<=dev )\S+' | head -n1)
CIDR=$(ip -o -f inet addr show "$NIC" | awk '{print $4}' | head -1)
LAN_ROUTE=$(python3 -c "import ipaddress; net=ipaddress.IPv4Network('$CIDR', strict=False); print(f'{net.network_address} {net.netmask}')")

echo "=================================================="
echo " Iniciando instalación de OpenVPN Server"
echo " Interfaz principal:      $NIC"
echo " Red local autodetectada: $LAN_ROUTE"
echo "=================================================="

# 1. Instalar dependencias (incluimos php-cli para el script de eventos)
echo "[1/6] Instalando paquetes del sistema..."
apt update && apt install -y openvpn easy-rsa curl iptables iptables-persistent python3 php-cli

# 2. Configurar Easy-RSA y certs a 10 años
echo "[2/6] Configurando estructura de Easy-RSA..."
rm -rf "$EASYRSA_DIR"
mkdir -p "$EASYRSA_DIR"
cp -r /usr/share/easy-rsa/* "$EASYRSA_DIR/"
cd "$EASYRSA_DIR"

cat << 'EOF' > vars
set_var EASYRSA_DN "org"
set_var EASYRSA_REQ_COUNTRY "AR"
set_var EASYRSA_REQ_PROVINCE "Buenos Aires"
set_var EASYRSA_REQ_CITY "Buenos Aires"
set_var EASYRSA_REQ_ORG "OpenVPN"
set_var EASYRSA_REQ_EMAIL "danifinke@gmail.com"
set_var EASYRSA_REQ_OU "SysAdmin"
set_var EASYRSA_CA_EXPIRE 7300
set_var EASYRSA_CERT_EXPIRE 3650
EOF

echo "[3/6] Generando infraestructura PKI, CA y Certificados..."
./easyrsa init-pki
./easyrsa --batch build-ca nopass
./easyrsa --batch build-server-full server-tun1 nopass
openssl dhparam -out pki/dh.pem 2048

openvpn --genkey secret tls-crypt-tun1.key
./easyrsa gen-crl

cp pki/ca.crt pki/issued/server-tun1.crt pki/private/server-tun1.key pki/dh.pem tls-crypt-tun1.key pki/crl.pem /etc/openvpn/server/
chmod 644 /etc/openvpn/server/crl.pem

# 3. Crear el archivo de configuración del servidor
echo "[4/6] Creando archivo server.conf personalizado..."
mkdir -p "$CCD_DIR"
touch /var/log/openvpn-server-status.log
touch /var/log/openvpn-server.log

cat << EOF > /etc/openvpn/server/server.conf
port 1194
proto udp
dev tun1

ca ca.crt
cert server-tun1.crt
key server-tun1.key
dh dh.pem
tls-crypt tls-crypt-tun1.key

topology subnet
server 10.10.20.0 255.255.255.0

status /var/log/openvpn-server-status.log
log-append /var/log/openvpn-server.log

push "route $LAN_ROUTE"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
client-config-dir /etc/openvpn/server/ccd
keepalive 10 120
persist-key
persist-tun
verb 4

crl-verify crl.pem
explicit-exit-notify

script-security 2
client-connect /usr/local/bin/vpn-logger-event.sh
client-disconnect /usr/local/bin/vpn-logger-event.sh
management 127.0.0.1 7505
EOF

# 4. Crear el script de logging
echo "[5/6] Instalando script de eventos (vpn-logger-event.sh)..."
cat << 'EOF' > /usr/local/bin/vpn-logger-event.sh
#!/bin/bash
SESSION_ID="${common_name}_${trusted_ip}_${ifconfig_pool_remote_ip}"

if [ "$script_type" == "client-connect" ]; then
    /usr/bin/php -r "
        require '/var/www/html/manage-openvpn/app/Config/db.php';
        \$stmt = \$pdo->prepare('INSERT INTO connection_history (username, real_ip, virtual_ip, connected_since, bytes_received, bytes_sent) 
                                VALUES (?, ?, ?, NOW(), \"0\", \"0\")');
        \$stmt->execute(['$common_name', '$trusted_ip', '$ifconfig_pool_remote_ip']);
    "
elif [ "$script_type" == "client-disconnect" ]; then
    /usr/bin/php -r "
        require '/var/www/html/manage-openvpn/app/Config/db.php';
        \$rx_bytes = \$argv[1];
        \$tx_bytes = \$argv[2];
        \$rx = round(\$rx_bytes / 1024, 2) . ' KB';
        \$tx = round(\$tx_bytes / 1024, 2) . ' KB';
        
        \$stmt = \$pdo->prepare('UPDATE connection_history 
                                SET bytes_received = ?, 
                                    bytes_sent = ? 
                                WHERE username = ? 
                                ORDER BY logged_at DESC LIMIT 1');
        \$stmt->execute([\$rx, \$tx, '$common_name']);
    " "$bytes_received" "$bytes_sent"
fi
exit 0
EOF
chmod +x /usr/local/bin/vpn-logger-event.sh

# 5. Configurar Red y Reglas IPTables persistentes
echo "[6/6] Configurando reenvío de IP y NAT..."
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-openvpn.sysctl
sysctl -p /etc/sysctl.d/99-openvpn.sysctl 2>/dev/null || true

iptables -t nat -A POSTROUTING -s 10.10.20.0/24 -o "$NIC" -j MASQUERADE
iptables -I FORWARD 1 -i tun+ -o "$NIC" -j ACCEPT
iptables -I FORWARD 1 -i "$NIC" -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT

export DEBIAN_FRONTEND=noninteractive
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
iptables-save > /etc/iptables/rules.v4

# Permisos para el log de status (vital para la web)
touch /var/log/openvpn-server-status.log
chown www-data:www-data /var/log/openvpn-server-status.log
chmod 644 /var/log/openvpn-server-status.log

systemctl restart openvpn-server@server
systemctl enable openvpn-server@server

echo "=================================================="
echo " ¡Servidor OpenVPN configurado exitosamente!"
echo " Ejecuta ahora install_webadmin.sh para la web."
echo "=================================================="

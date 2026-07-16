#!/bin/bash

# ==============================================================================
# SCRIPT DE INSTALACIÓN COMPLETA DE OPENVPN SERVER
# ==============================================================================
# Configura el servidor OpenVPN, habilita reenvío de tráfico, reglas NAT
# y autogenera el script de gestión para integrarse con OpenVPN-WebAdmin.
# ==============================================================================

# Verificar que se ejecute como root
if [[ $EUID -ne 0 ]]; then 
    echo "Error: Este script debe ejecutarse como root (usa sudo)."
    exit 1
fi

# Detectar el usuario real que invoca el script (SUDO_USER)
TARGET_USER=${SUDO_USER:-$USER}
TARGET_HOME=$(eval echo ~$TARGET_USER)
OUTPUT_BASE="$TARGET_HOME/ovpn"
EASYRSA_DIR="/etc/openvpn/easy-rsa-tun1"
CCD_DIR="/etc/openvpn/server/ccd"
STATUS_LOG="/var/log/openvpn/status.log"

# Obtener la IP pública del servidor automáticamente
SERVER_IP=$(curl -s https://ipinfo.io/ip || curl -s https://api.ipify.org || hostname -I | awk '{print $1}')

echo "=================================================="
echo " Iniciando instalación de OpenVPN Server"
echo "=================================================="
echo "Administrador del sistema: $TARGET_USER"
echo "Directorio Home detectado: $TARGET_HOME"
echo "IP Pública autodetectada:  $SERVER_IP"
echo "Directorio de perfiles:    $OUTPUT_BASE"
echo "=================================================="

# 1. Instalar dependencias necesarias
echo "[1/7] Instalando paquetes del sistema..."
apt update && apt install -y openvpn easy-rsa curl iptables

# 2. Preparar directorios de trabajo y PKI (Certificados)
echo "[2/7] Configurando estructura de Easy-RSA..."
rm -rf "$EASYRSA_DIR" # Limpiar si ya existía
mkdir -p "$EASYRSA_DIR"
cp -r /usr/share/easy-rsa/* "$EASYRSA_DIR/"
cd "$EASYRSA_DIR"

# Configurar variables de expiración y parámetros (Válidos por 10 años / 3650 días)
cat << 'EOF' > vars
set_var EASYRSA_DN "org"
set_var EASYRSA_REQ_COUNTRY "AR"
set_var EASYRSA_REQ_PROVINCE "Buenos Aires"
set_var EASYRSA_REQ_CITY "Hurlingham"
set_var EASYRSA_REQ_ORG "OpenVPN-WebAdmin"
set_var EASYRSA_REQ_EMAIL "admin@openvpnwebadmin.local"
set_var EASYRSA_REQ_OU "VpnUnit"
set_var EASYRSA_CA_EXPIRE 7300
set_var EASYRSA_CERT_EXPIRE 3650
EOF

# 3. Inicializar e iniciar la infraestructura de clave pública (PKI)
echo "[3/7] Generando infraestructura PKI, CA y Certificados..."
./easyrsa init-pki
./easyrsa --batch build-ca nopass
./easyrsa gen-req server nopass
./easyrsa --batch sign-req server server

# Generar parámetros Diffie-Hellman y la clave TLS-Auth
openssl dhparam -out pki/dh.pem 2048
openvpn --genkey secret ta.key

# Generar el archivo CRL inicial (Lista de revocación) indispensable para arrancar con revocaciones
./easyrsa gen-crl

# Copiar todos los certificados del servidor al directorio de OpenVPN
cp pki/ca.crt pki/issued/server.crt pki/private/server.key pki/dh.pem ta.key pki/crl.pem /etc/openvpn/server/
chmod 644 /etc/openvpn/server/crl.pem

# 4. Crear el archivo de configuración del servidor OpenVPN
echo "[4/7] Configurando el servicio OpenVPN..."
cat << 'EOF' > /etc/openvpn/server/server.conf
port 1194
proto udp
dev tun
ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key
dh /etc/openvpn/server/dh.pem
tls-auth /etc/openvpn/server/ta.key 0
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
cipher AES-256-GCM
auth SHA512
persist-key
persist-tun
status /var/log/openvpn/status.log 10
verb 3
explicit-exit-notify 1
crl-verify /etc/openvpn/server/crl.pem
EOF

# 5. Configurar Red, Reenvío de IP e IPTables (NAT)
echo "[5/7] Configurando reenvío de tráfico de red (Forwarding & NAT)..."
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-openvpn.sysctl

# Obtener interfaz de red por defecto para aplicar enmascaramiento
NIC=$(ip -4 route show to default | grep -oP '(?<=dev )\S+' | head -n1)
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$NIC" -j MASQUERADE

# Instalar de forma no interactiva iptables-persistent para salvar las reglas de IPTables
export DEBIAN_FRONTEND=noninteractive
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
apt-get install -y iptables-persistent

# Iniciar y habilitar el servicio de OpenVPN
systemctl start openvpn-server@server
systemctl enable openvpn-server@server

# 6. Estructuras de directorios y permisos para la Web
echo "[6/7] Creando directorios para perfiles del cliente..."
mkdir -p "$OUTPUT_BASE"
mkdir -p "$CCD_DIR"

# Permitir que el servidor web cruce el /home para escribir/leer los .ovpn
chmod 755 "$TARGET_HOME"
chown -R www-data:www-data "$OUTPUT_BASE"
chmod 755 "$OUTPUT_BASE"

# Configurar el registro de estados de conexiones
mkdir -p /var/log/openvpn/
touch "$STATUS_LOG"
chown www-data:www-data "$STATUS_LOG"
chmod 644 "$STATUS_LOG"

# 7. GENERAR EL SCRIPT DE GESTIÓN (vpn-manager-web.sh)
echo "[7/7] Creando script de gestión de backend para la web..."
cat << 'EOF' > /usr/local/bin/vpn-manager-web.sh
#!/bin/bash

EASYRSA_DIR="RUTAEASYRSA"
OUTPUT_BASE="RUTAOUTPUT"
CCD_DIR="RUTACCD"
STATUS_LOG="RUTALOG"
SERVER_IP="IP_PUBLICA_SERVIDOR"

case "$1" in
    create)
        CLIENT="$2"
        # Sanitizar entrada
        CLIENT=$(echo "$CLIENT" | tr -cd 'a-zA-Z0-9_-')
        
        if [ -z "$CLIENT" ]; then
            echo "Error: Nombre de usuario inválido."
            exit 1
        fi

        cd "$EASYRSA_DIR"
        
        # Generar certificado sin contraseña para el cliente
        ./easyrsa --batch build-client-full "$CLIENT" nopass > /dev/null 2>&1
        
        # Crear el directorio del cliente
        mkdir -p "$OUTPUT_BASE/$CLIENT"
        
        # Generar archivo .ovpn unificado con certificados embebidos
        cat << INNEREOF > "$OUTPUT_BASE/$CLIENT/$CLIENT.ovpn"
client
dev tun
proto udp
remote $SERVER_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA512
key-direction 1
verb 3

<ca>
$(cat "$EASYRSA_DIR/pki/ca.crt")
</ca>

<cert>
$(sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' "$EASYRSA_DIR/pki/issued/$CLIENT.crt")
</cert>

<key>
$(cat "$EASYRSA_DIR/pki/private/$CLIENT.key")
</key>

<tls-auth>
$(cat "$EASYRSA_DIR/ta.key")
</tls-auth>
INNEREOF

        chown -R www-data:www-data "$OUTPUT_BASE/$CLIENT"
        chmod 644 "$OUTPUT_BASE/$CLIENT/$CLIENT.ovpn"
        echo "OK"
        ;;
        
    revoke)
        CLIENT="$2"
        CLIENT=$(echo "$CLIENT" | tr -cd 'a-zA-Z0-9_-')
        
        if [ -z "$CLIENT" ]; then
            echo "Error: Nombre de usuario inválido."
            exit 1
        fi

        cd "$EASYRSA_DIR"
        ./easyrsa --batch revoke "$CLIENT" > /dev/null 2>&1
        ./easyrsa gen-crl > /dev/null 2>&1
        
        # Actualizar el CRL activo en el servidor
        cp pki/crl.pem /etc/openvpn/server/crl.pem
        chmod 644 /etc/openvpn/server/crl.pem
        
        # Limpiar directorio y perfiles revocados
        rm -rf "$OUTPUT_BASE/$CLIENT"
        rm -f "$CCD_DIR/$CLIENT"
        echo "OK"
        ;;
        
    download)
        CLIENT="$2"
        CLIENT=$(echo "$CLIENT" | tr -cd 'a-zA-Z0-9_-')
        if [ -f "$OUTPUT_BASE/$CLIENT/$CLIENT.ovpn" ]; then
            cat "$OUTPUT_BASE/$CLIENT/$CLIENT.ovpn"
        else
            echo "Error: Archivo no encontrado."
        fi
        ;;
        
    list_online)
        if [ -f "$STATUS_LOG" ]; then
            # Retorna la lista de usuarios con sesión VPN activa actualmente
            grep -E '^[a-zA-Z0-9_-]+,' "$STATUS_LOG" | awk -F, '{print $1}' | sort -u
        fi
        ;;
        
    *)
        echo "Uso: $0 {create|revoke|download|list_online} [usuario]"
        ;;
esac
EOF

# Inyectar rutas e IP pública real de instalación en el script de gestión
sed -i "s|RUTAEASYRSA|$EASYRSA_DIR|g" /usr/local/bin/vpn-manager-web.sh
sed -i "s|RUTAOUTPUT|$OUTPUT_BASE|g" /usr/local/bin/vpn-manager-web.sh
sed -i "s|RUTACCD|$CCD_DIR|g" /usr/local/bin/vpn-manager-web.sh
sed -i "s|RUTALOG|$STATUS_LOG|g" /usr/local/bin/vpn-manager-web.sh
sed -i "s|IP_PUBLICA_SERVIDOR|$SERVER_IP|g" /usr/local/bin/vpn-manager-web.sh

# Otorgar permisos de ejecución al script de gestión
chmod +x /usr/local/bin/vpn-manager-web.sh

# Añadir permisos en sudoers para www-data sin requerir contraseña
if ! grep -q "vpn-manager-web.sh" /etc/sudoers; then
    echo "www-data ALL=(ALL) NOPASSWD: /usr/local/bin/vpn-manager-web.sh" >> /etc/sudoers
fi

echo "=================================================="
echo " ¡Servidor OpenVPN configurado y listo!"
echo " Todos los certificados durarán 10 años."
echo "=================================================="
echo " Ahora ejecuta install_webadmin.sh para configurar el panel web."
echo "=================================================="

#!/bin/bash

# ==============================================================================
# SCRIPT DE DESINSTALACIÓN COMPLETA DE OPENVPN SERVER
# ==============================================================================
# Detiene servicios, elimina configuraciones, limpia IPTables, remueve
# scripts de logs/gestión y restaura el estado original de la red.
# ==============================================================================

if [[ $EUID -ne 0 ]]; then 
    echo "Error: Este script debe ejecutarse como root (usa sudo)."
    exit 1
fi

echo "=================================================="
echo " Iniciando desinstalación completa de OpenVPN"
echo "=================================================="

# 1. Detener y deshabilitar el servicio de OpenVPN
echo "[1/6] Deteniendo y deshabilitando servicios de OpenVPN..."
systemctl stop openvpn-server@server 2>/dev/null
systemctl disable openvpn-server@server 2>/dev/null
systemctl stop openvpn 2>/dev/null
systemctl disable openvpn 2>/dev/null

# 2. Desinstalar paquetes de OpenVPN y Easy-RSA
echo "[2/6] Desinstalando paquetes del sistema..."
export DEBIAN_FRONTEND=noninteractive
apt-get purge -y openvpn easy-rsa iptables-persistent
apt-get autoremove -y

# 3. Eliminar directorios de configuración y certificados
echo "[3/6] Eliminando directorios de configuración y certificados..."
rm -rf /etc/openvpn

# Eliminar directorios de salida de clientes (.ovpn) en todos los homes de usuarios reales
for user_dir in /home/*; do
    if [ -d "$user_dir/ovpn" ]; then
        echo "Eliminando perfiles de clientes en: $user_dir/ovpn"
        rm -rf "$user_dir/ovpn"
    fi
done
# También por si las dudas en el directorio de root
rm -rf /root/ovpn

# 4. Eliminar scripts personalizados y archivos de registro (logs)
echo "[4/6] Eliminando scripts personalizados de administración y logs..."
rm -f /usr/local/bin/vpn-logger-event.sh
rm -f /usr/local/bin/vpn-manager-web.sh
rm -f /var/log/openvpn-server-status.log
rm -f /var/log/openvpn-server.log
rm -rf /var/log/openvpn

# 5. Remover permisos de sudoers asignados a www-data
echo "[5/6] Limpiando archivo sudoers..."
if [ -f /etc/sudoers ]; then
    # Elimina cualquier línea que haga referencia al script de gestión web
    sed -i '/vpn-manager-web.sh/d' /etc/sudoers
fi

# 6. Limpiar reglas de IPTables de NAT/FORWARD y restaurar sysctl
echo "[6/6] Restaurando configuraciones de red e IPTables..."
# Deshabilitar reenvío de IP a nivel de sysctl
rm -f /etc/sysctl.d/99-openvpn.sysctl
sysctl -p /etc/sysctl.d/99-openvpn.sysctl 2>/dev/null || true
echo 0 > /proc/sys/net/ipv4/ip_forward

# Limpiar reglas persistentes de iptables guardadas
rm -f /etc/iptables/rules.v4
rm -f /etc/iptables/rules.v6

# Remover selectivamente las reglas de IPTables que creamos (evitando tocar otras reglas si existen)
# O restaurar las cadenas por defecto de NAT y FORWARD si es un entorno exclusivo para pruebas
iptables -t nat -F POSTROUTING 2>/dev/null
iptables -F FORWARD 2>/dev/null

echo "=================================================="
echo " ¡Desinstalación completada con éxito!"
echo " El sistema ha quedado completamente limpio de OpenVPN."
echo "=================================================="

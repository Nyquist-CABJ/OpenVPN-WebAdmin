#!/bin/bash

# Verificar que sea root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root (sudo ./uninstall_webadmin.sh)"
  exit 1
fi

echo "--- Iniciando desinstalación del panel VPN (SD Mates) ---"

# 1. Eliminar archivos web y carpetas
echo "[1/5] Eliminando archivos del panel..."
rm -rf /var/www/html/manage-openvpn

# 2. Eliminar configuración de Nginx
echo "[2/5] Eliminando configuración de Nginx..."
rm -f /etc/nginx/sites-available/vpn-manager
rm -f /etc/nginx/sites-enabled/vpn-manager
systemctl restart nginx

# 3. Eliminar bases de datos
echo "[3/5] Eliminando base de datos y usuario MySQL..."
mysql -e "DROP DATABASE IF EXISTS openvpn;"
mysql -e "DROP USER IF EXISTS 'openvpn_db'@'localhost';"

# 4. Eliminar scripts, permisos y tareas cron
echo "[4/5] Limpiando scripts, permisos y cronjobs..."
rm -f /usr/local/bin/vpn-manager-web.sh

# Eliminar línea de sudoers
sed -i '/vpn-manager-web.sh/d' /etc/sudoers

# Limpiar crontab
crontab -l | grep -v "cron_logger.php" | crontab -

# 5. Opcional: Eliminar carpetas de configuración de usuario creadas
# TARGET_USER=${SUDO_USER:-$USER}
# TARGET_HOME=$(eval echo ~$TARGET_USER)
# rm -rf "$TARGET_HOME/ovpn"

echo "==========================================="
echo "¡Desinstalación finalizada!"
echo "Nota: El software instalado (nginx, php, mariadb, openvpn) no se ha eliminado"
echo "para evitar romper otros servicios del servidor."
echo "==========================================="

#!/bin/bash
# Script de Instalación - VPN Manager (SD Mates / DF Techno)

# Verificar privilegios de root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root (sudo ./install.sh)"
  exit 1
fi

echo "Iniciando instalación del panel VPN..."

# 1. Instalar dependencias del sistema
echo "[1/6] Instalando dependencias (Apache, PHP, MariaDB, OpenVPN, Easy-RSA)..."
apt-get update
apt-get install -y apache2 php php-mysql php-gd mariadb-server openvpn easy-rsa unzip git

# 2. Configurar Base de Datos
echo "[2/6] Configurando Base de Datos..."
mysql -e "CREATE DATABASE IF NOT EXISTS openvpn_dftechno;"
mysql openvpn_dftechno < database/schema.sql
echo "Base de datos importada."

# 3. Copiar Archivos Web
echo "[3/6] Desplegando panel web..."
mkdir -p /var/www/html/manage-openvpn
cp -r web/* /var/www/html/manage-openvpn/
chown -R www-data:www-data /var/www/html/manage-openvpn/
chmod -R 755 /var/www/html/manage-openvpn/

# 4. Instalar Script de Servidor (Bash)
echo "[4/6] Configurando scripts de administración..."
cp scripts/vpn-manager-web.sh /usr/local/bin/
chmod +x /usr/local/bin/vpn-manager-web.sh

# 5. Configurar Permisos de Sudo para PHP (visudo)
echo "[5/6] Configurando permisos de ejecución sin contraseña para www-data..."
if ! grep -q "www-data ALL=(ALL) NOPASSWD: /usr/local/bin/vpn-manager-web.sh" /etc/sudoers; then
    echo "www-data ALL=(ALL) NOPASSWD: /usr/local/bin/vpn-manager-web.sh" >> /etc/sudoers
fi

# 6. Configurar Tareas Cron
echo "[6/6] Configurando Cronjobs (Motor de Reglas y Logs)..."
CRON_JOB="* * * * * php /var/www/html/manage-openvpn/cron/cron_logger.php"
(crontab -l 2>/dev/null | grep -v "cron_logger.php"; echo "$CRON_JOB") | crontab -

echo "==========================================="
echo "¡Instalación completada con éxito!"
echo "Accede al panel desde: http://tu-ip/manage-openvpn/public/login.php"
echo "Asegúrate de configurar app/Config/db.php con las credenciales correctas."
echo "==========================================="

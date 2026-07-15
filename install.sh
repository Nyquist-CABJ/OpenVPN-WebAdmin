#!/bin/bash
# Script de Instalación - VPN Manager (SD Mates) - VERSIÓN NGINX

# Verificar privilegios de root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root (sudo ./install.sh)"
  exit 1
fi

echo "Iniciando instalación del panel VPN con Nginx..."

# 1. Instalar dependencias del sistema
echo "[1/6] Instalando dependencias (Nginx, PHP-FPM, MariaDB, OpenVPN, Easy-RSA)..."
apt-get update
apt-get install -y nginx php-fpm php-mysql php-gd mariadb-server openvpn easy-rsa unzip git

# 2. Configurar Base de Datos
echo "[2/6] Configurando Base de Datos y Usuarios..."
# Creamos la base de datos 'openvpn'
mysql -e "CREATE DATABASE IF NOT EXISTS openvpn;"

# Importamos el esquema (ahora incluye al usuario admin)
mysql openvpn < database/schema.sql

# Creamos el usuario openvpn_db y asignamos los privilegios
mysql -e "CREATE USER IF NOT EXISTS 'openvpn_db'@'localhost' IDENTIFIED BY 'AlternativaGratisAR';"
mysql -e "GRANT ALL PRIVILEGES ON openvpn.* TO 'openvpn_db'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"
echo "Base de datos y usuario openvpn_db configurados con éxito."

# 3. Copiar Archivos Web
echo "[3/6] Desplegando panel web..."
mkdir -p /var/www/html/manage-openvpn
cp -r web/* /var/www/html/manage-openvpn/
chown -R www-data:www-data /var/www/html/manage-openvpn/
chmod -R 755 /var/www/html/manage-openvpn/

# 3.1. Configurar Virtual Host de Nginx
echo "[3.1/6] Configurando Nginx para procesar PHP..."
PHP_SOCK=$(find /run/php/ -name "php*-fpm.sock" | head -n 1)

cat <<EOF > /etc/nginx/sites-available/vpn-manager
server {
    listen 80;
    server_name _;
    /var/www/html/manage-openvpn/public;
    index index.php index.html index.htm;

    autoindex off;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:\$PHP_SOCK;
    }

    location ~ /\. {
        deny all;
    }
}
EOF

ln -sf /etc/nginx/sites-available/vpn-manager /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

systemctl restart nginx

# 4. Instalar Script de Servidor (Bash)
echo "[4/6] Configurando scripts de administración..."
cp scripts/vpn-manager-web.sh /usr/local/bin/
chmod +x /usr/local/bin/vpn-manager-web.sh

# 5. Configurar Permisos de Sudo para PHP
echo "[5/6] Configurando permisos de ejecución sin contraseña para www-data..."
if ! grep -q "www-data ALL=(ALL) NOPASSWD: /usr/local/bin/vpn-manager-web.sh" /etc/sudoers; then
    echo "www-data ALL=(ALL) NOPASSWD: /usr/local/bin/vpn-manager-web.sh" >> /etc/sudoers
fi

# 6. Configurar Tareas Cron
echo "[6/6] Configurando Cronjobs (Motor de Reglas y Logs)..."
CRON_JOB="* * * * * php /var/www/html/manage-openvpn/cron/cron_logger.php"
(crontab -l 2>/dev/null | grep -v "cron_logger.php"; echo "$CRON_JOB") | crontab -

echo "==========================================="
echo "¡Instalación completada con éxito usando NGINX!"
echo "Accede al panel desde: http://tu-ip/"
echo "Usuario por defecto: admin"
echo "Clave: Admin123"
echo "==========================================="

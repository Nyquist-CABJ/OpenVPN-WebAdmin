#!/bin/bash
# Script de Instalación - VPN Manager (SD Mates) - VERSIÓN NGINX

if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root (sudo ./install_webadmin.sh)"
  exit 1
fi

echo "Iniciando instalación del panel VPN con Nginx..."

# 1. Instalar dependencias del sistema
echo "[1/7] Instalando dependencias (Nginx, PHP-FPM, MariaDB, OpenVPN, Easy-RSA)..."
apt-get update
apt-get install -y nginx php-fpm php-mysql php-gd mariadb-server openvpn easy-rsa unzip git

# 2. Configurar Base de Datos
echo "[2/7] Configurando Base de Datos y Usuarios..."
mysql -e "CREATE DATABASE IF NOT EXISTS openvpn;"
mysql openvpn < database/schema.sql
mysql -e "CREATE USER IF NOT EXISTS 'openvpn_db'@'localhost' IDENTIFIED BY 'AlternativaGratisAR';"
mysql -e "GRANT ALL PRIVILEGES ON openvpn.* TO 'openvpn_db'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"
echo "Base de datos y usuario openvpn_db configurados con éxito."

# 3. Copiar Archivos Web
echo "[3/7] Desplegando panel web..."
mkdir -p /var/www/html/manage-openvpn
cp -r web/* /var/www/html/manage-openvpn/
cp /var/www/html/manage-openvpn/app/Config/db.example.php /var/www/html/manage-openvpn/app/Config/db.php
chown -R www-data:www-data /var/www/html/manage-openvpn/
chmod -R 755 /var/www/html/manage-openvpn/

# 3.1. Configurar Virtual Host de Nginx
echo "[4/7] Configurando Nginx para procesar PHP..."
# Detectamos dinámicamente el socket de PHP y lo inyectamos en tu configuración corregida
PHP_SOCK=$(find /run/php/ -name "php*-fpm.sock" | head -n 1)

cat <<EOF > /etc/nginx/sites-available/vpn-manager
server {
    listen 80;
    server_name _;

    root /var/www/html/manage-openvpn/public;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # Procesamiento de PHP con FastCGI
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${PHP_SOCK};
    }

    # Denegar acceso a archivos ocultos (como .git o tus archivos de config)
    location ~ /\. {
        deny all;
    }
}
EOF

ln -sf /etc/nginx/sites-available/vpn-manager /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

# 4. Instalar Script de Servidor (Bash)
echo "[5/7] Configurando scripts de administración..."
cp scripts/vpn-manager-web.sh /usr/local/bin/
chmod +x /usr/local/bin/vpn-manager-web.sh

# Aseguramos que la carpeta ovpn en el home exista y tenga permisos
TARGET_USER=${SUDO_USER:-$USER}
TARGET_HOME=$(eval echo ~$TARGET_USER)
mkdir -p "$TARGET_HOME/ovpn"
chmod 755 "$TARGET_HOME"
chown -R www-data:www-data "$TARGET_HOME/ovpn"
chmod 755 "$TARGET_HOME/ovpn"

# 5. Configurar Permisos de Sudo para PHP
echo "[6/7] Configurando permisos de ejecución sin contraseña para www-data..."
if ! grep -q "www-data ALL=(ALL) NOPASSWD: /usr/local/bin/vpn-manager-web.sh" /etc/sudoers; then
    echo "www-data ALL=(ALL) NOPASSWD: /usr/local/bin/vpn-manager-web.sh" >> /etc/sudoers
fi

# 6. Configurar Tareas Cron
echo "[7/7] Configurando Cronjobs y Usuario Administrador..."
CRON_JOB="* * * * * php /var/www/html/manage-openvpn/cron/cron_logger.php"
(crontab -l 2>/dev/null | grep -v "cron_logger.php"; echo "$CRON_JOB") | crontab -

# 7. Restablecer / Configurar Usuario Admin (Lógica integrada de reset_admin.sh)
echo "[*] Generando credenciales del administrador web..."
HASH=$(php -r "echo password_hash('Admin123', PASSWORD_DEFAULT);")
SQL_QUERY="
DELETE FROM web_users WHERE username = 'admin';
INSERT INTO web_users (username, real_name, password_hash, role) 
VALUES ('admin', 'Administrador Principal', '${HASH}', 'administrador');
"
mysql -u "openvpn_db" -p"AlternativaGratisAR" "openvpn" -e "$SQL_QUERY"

echo "==========================================="
echo "¡Instalación completada con éxito usando NGINX!"
echo "Accede al panel desde: http://$(hostname -I | awk '{print $1}')/"
echo "Usuario por defecto: admin"
echo "Clave: Admin123"
echo "==========================================="

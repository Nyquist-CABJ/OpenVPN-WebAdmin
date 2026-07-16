# VPN Manager for OpenVPN

Panel de administración web para gestionar conexiones OpenVPN, asignación de IPs estáticas, control de horarios y seguridad (Kill Switch) para redes corporativas.

## Características
- **Gestión de Perfiles**: Crear/Revocar certificados fácilmente.
- **Seguridad**: Kill Switch para bloquear usuarios instantáneamente.
- **Control de Acceso**: Configuración de horarios permitidos por usuario.
- **QR Deployment**: Generación dinámica de QR para importar perfiles en la app OpenVPN Connect.
- **Auditoría**: Registro de consumo de datos y estados de conexión.

## Requisitos
- Servidor Linux (Ubuntu/Debian)
- PHP 7.4+ con extensión `php-gd`
- MariaDB / MySQL
- OpenVPN y Easy-RSA

## Instalación
1. Clona este repositorio.
   ```bash
   git clone https://github.com/Nyquist-CABJ/OpenVPN-WebAdmin.git

2. Asegúrate de tener los permisos correctos en las carpetas.
3. Copia `app/Config/db.example.php` a `app/Config/db.php` y configura tus credenciales.
4. Ejecuta el script de instalación de OpenVPN Server:
   ```bash
   sudo ./install_openvpn.sh

5. Ejecuta el script de instalación del WebAdmin
   ```bash
   sudo ./install_webadmin.sh

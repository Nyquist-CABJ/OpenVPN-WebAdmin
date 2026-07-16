# OpenVPN WebAdmin

OpenVPN WebAdmin es una solución completa para desplegar y administrar un servidor OpenVPN con una interfaz web moderna.

El proyecto automatiza la instalación de OpenVPN, Easy-RSA, la base de datos y el panel de administración, permitiendo gestionar usuarios, certificados, direcciones IP estáticas y políticas de acceso desde el navegador.

## Características

- 🚀 Instalación automática de OpenVPN Server.
- 🌐 Panel Web de administración.
- 👤 Gestión de usuarios VPN.
- 🔐 Creación y revocación de certificados.
- 📡 Asignación de direcciones IP estáticas.
- 📱 Generación de códigos QR compatibles con OpenVPN Connect.
- ⏰ Control de horarios de acceso por usuario.
- 🛡️ Kill Switch para bloquear usuarios inmediatamente.
- 📊 Auditoría de conexiones y consumo de datos.
- 🔄 Renovación automática de certificados SSL mediante Let's Encrypt (opcional).
- 🗄️ Compatible con MariaDB y MySQL.

---

## Requisitos

- Ubuntu 22.04 o superior (recomendado)
- Acceso como usuario con privilegios `sudo`
- Dominio o dirección IP pública (opcional para acceso web)
- Conexión a Internet durante la instalación

---

## Instalación

### 1. Clonar el repositorio

```bash
git clone https://github.com/Nyquist-CABJ/OpenVPN-WebAdmin.git
cd OpenVPN-WebAdmin
```

### 2. Configurar permisos

```bash
chmod +x *.sh
chmod +x web/manage-openvpn/*.sh
```

### 3. Instalar OpenVPN Server

```bash
sudo ./install_openvpn.sh
```

Este script instalará:

- OpenVPN
- Easy-RSA
- Configuración inicial del servidor
- PKI
- Certificados
- Reglas de red necesarias

---

### 4. Instalar el Panel Web

```bash
sudo ./install_webadmin.sh
```

Durante la instalación se configurarán automáticamente:

- Apache/Nginx (según el instalador)
- PHP
- MariaDB/MySQL
- Base de datos
- VirtualHost
- Permisos de la aplicación

---

## Configuración

Si el instalador no genera automáticamente el archivo de configuración, copiar:

```bash
cp app/Config/db.example.php app/Config/db.php
```

Editar:

```php
app/Config/db.php
```

con los datos de conexión a la base de datos.

---

## Acceso

Una vez finalizada la instalación:

```
http://IP_DEL_SERVIDOR
```

o

```
https://tu-dominio.com
```

---

## Funcionalidades

- Administración de usuarios
- Crear certificados
- Revocar certificados
- Descargar perfiles `.ovpn`
- Generar código QR
- Asignar IP fija
- Horarios de acceso
- Kill Switch
- Estado de conexiones
- Estadísticas de uso

---

## Estructura del proyecto

```
OpenVPN-WebAdmin/
│
├── app/
│   ├── Config/
│   ├── Controllers/
│   ├── Models/
│   └── Views/
│
├── web/
│   └── manage-openvpn/
│
├── install_openvpn.sh
├── install_webadmin.sh
└── README.md
```

---

## Compatibilidad

- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS

---

## Licencia

Este proyecto se distribuye bajo la licencia MIT.

---

## Autor

Desarrollado por **DFTechno**.

Repositorio oficial:

https://github.com/Nyquist-CABJ/OpenVPN-WebAdmin

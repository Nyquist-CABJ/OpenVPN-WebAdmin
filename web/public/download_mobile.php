<?php
// Archivo: public/download_mobile.php
require_once __DIR__ . '/../app/Models/VPNManager.php';

$user = $_GET['u'] ?? '';
$token = $_GET['t'] ?? '';

if (empty($user) || empty($token)) {
    die("Error: Faltan datos de autenticación.");
}

// Verificamos el token de seguridad
$salt = "Seguridad_SD_Mates_2026";
$expectedToken = hash('sha256', $user . $salt . date('Y-m-d-H'));

if (!hash_equals($expectedToken, $token)) {
    // Damos margen de 1 hora hacia atrás por si el QR se generó a las 14:59 y se escanea a las 15:01
    $expectedTokenPrev = hash('sha256', $user . $salt . date('Y-m-d-H', strtotime('-1 hour')));
    if (!hash_equals($expectedTokenPrev, $token)) {
        die("Error: El código QR ha expirado por seguridad. Por favor, genera uno nuevo en el panel.");
    }
}

// Si la seguridad pasa, buscamos el archivo
$vpn = new VPNManager();
$config = $vpn->getProfileContent($user);

if (strpos($config, 'Error:') !== false || empty(trim($config))) {
    die("Error: No se pudo obtener el perfil de OpenVPN. Comunícate con el administrador.");
}

// Forzamos la descarga en el celular con el tipo de archivo correcto para OpenVPN
header('Content-Type: application/x-openvpn-profile');
header('Content-Disposition: attachment; filename="' . $user . '.ovpn"');
header('Content-Length: ' . strlen($config));

// Entregamos el archivo
echo $config;
exit;
?>

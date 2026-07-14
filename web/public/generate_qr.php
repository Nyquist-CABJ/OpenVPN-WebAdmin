<?php
session_start();
if (!isset($_SESSION['user_id'])) exit;

require_once __DIR__ . '/../lib/phpqrcode/qrlib.php';

$user = $_GET['user'] ?? '';
if (empty($user)) exit;

$salt = "Seguridad_SD_Mates_2026"; 
$token = hash('sha256', $user . $salt . date('Y-m-d-H'));

// --- CAMBIO AQUÍ: Usamos una ruta relativa desde el directorio actual ---
// Esto evita problemas con el nombre de la carpeta /manage-openvpn/
$protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? "https://" : "http://";
$domain = $_SERVER['HTTP_HOST'];
$url = $protocol . $domain . dirname($_SERVER['PHP_SELF']) . "/download_mobile.php?u=" . urlencode($user) . "&t=" . $token;

if (ob_get_length()) ob_end_clean();
QRcode::png($url, false, QR_ECLEVEL_L, 6, 2);
?>

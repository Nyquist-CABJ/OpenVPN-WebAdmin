<?php
$db_host = 'localhost';
$db_name = 'openvpn';
$db_user = 'openvpn_db';
$db_pass = 'AlternativaGratisAR';
try {
    $pdo = new PDO("mysql:host=$db_host;db_name=$db_name;charset=utf8", $db_user, $db_pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    die("Error de conexión a la base de datos.");
}
?>

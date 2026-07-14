<?php
require_once __DIR__ . '/../app/Config/db.php';
require_once __DIR__ . '/../app/Models/VPNManager.php';

$vpn = new VPNManager();

// --- 1. MOTOR DE CONTROL DE ACCESO (Kill Switch & Horarios) ---
$allUsers = $vpn->listUsers();
$current_time = date('H:i:00');

foreach ($allUsers as $u) {
    $stmt = $pdo->prepare("SELECT * FROM vpn_user_settings WHERE username = ?");
    $stmt->execute([$u]);
    $settings = $stmt->fetch(PDO::FETCH_ASSOC);
    
    $allow = true; // Por defecto permitimos
    
    if ($settings) {
        if ($settings['is_active'] == 0) {
            $allow = false; // Kill Switch Activo
        } elseif (!empty($settings['time_start']) && !empty($settings['time_end'])) {
            if ($current_time < $settings['time_start'] || $current_time > $settings['time_end']) {
                $allow = false; // Fuera de horario laboral
            }
        }
    }
    
    $vpn->setAccess($u, $allow ? 'allow' : 'deny');
}

// --- 2. AUDITORÍA DE TRÁFICO ---
$details = $vpn->getConnectedDetails();
if (!empty($details)) {
    foreach ($details as $username => $data) {
        $stmt = $pdo->prepare("UPDATE connection_history SET bytes_received = ?, bytes_sent = ? WHERE username = ? AND connected_since != 'Desconexión' ORDER BY logged_at DESC LIMIT 1");
        $stmt->execute([$data['rx'], $data['tx'], $username]);
        
        if ($stmt->rowCount() == 0) {
            $insert = $pdo->prepare("INSERT INTO connection_history (username, real_ip, virtual_ip, bytes_received, bytes_sent, connected_since, logged_at) VALUES (?, ?, ?, ?, ?, ?, NOW())");
            $insert->execute([$username, $data['real_ip'], $data['virtual_ip'], $data['rx'], $data['tx'], $data['connected_since']]);
        }
    }
}
?>

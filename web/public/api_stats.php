<?php
session_start();
if (!isset($_SESSION['user_id'])) {
    http_response_code(403);
    exit(json_encode(['error' => 'No autorizado']));
}

// Ejecutamos el comando details de nuestro bash script
$output = shell_exec("/usr/local/bin/vpn-manager-web.sh details 2>/dev/null");
$lines = explode("\n", trim($output));

$data = [
    'labels' => [],
    'rx' => [], // Recibido
    'tx' => []  // Enviado
];

foreach($lines as $line) {
    $cols = explode(",", $line);
    // OpenVPN status log format: CLIENT_LIST,username,real_address,virtual_address,bytes_received,bytes_sent,connected_since,...
    if(count($cols) >= 6 && $cols[0] === 'CLIENT_LIST') {
        $data['labels'][] = $cols[1];
        // Convertimos de Bytes a Megabytes y redondeamos a 2 decimales
        $data['rx'][] = round($cols[4] / 1048576, 2);
        $data['tx'][] = round($cols[5] / 1048576, 2);
    }
}

header('Content-Type: application/json');
echo json_encode($data);

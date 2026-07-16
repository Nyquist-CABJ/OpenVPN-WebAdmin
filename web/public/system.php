<?php
// Archivo: system.php
session_start();
if (!isset($_SESSION['user_id'])) {
    header("Location: login.php");
    exit;
}

$uptime = shell_exec('uptime -p');
$disk_free = round(disk_free_space("/") / 1024 / 1024 / 1024, 2);
$disk_total = round(disk_total_space("/") / 1024 / 1024 / 1024, 2);
$memory_info = shell_exec("free -m | awk 'NR==2{printf \"%.2f%% (Usado: %s MB / Total: %s MB)\", $3*100/$2, $3, $2 }'");

$openvpn_status = trim(shell_exec('systemctl is-active openvpn-server@server.service'));
$status_color = ($openvpn_status === 'active') ? 'success' : 'danger';

// -- INICIO DE LA VISTA --
$pageTitle = "Sistema - DF Techno VPN";
include __DIR__ . '/../templates/header.php';
?>

<h3 class="mb-4">Estado del Servidor</h3>

<div class="row">
    <div class="col-md-6 mb-4">
        <div class="card shadow-sm h-100 border-0">
            <div class="card-header bg-dark text-white"><i class="bi bi-server"></i> Recursos de Hardware</div>
            <ul class="list-group list-group-flush">
                <li class="list-group-item d-flex justify-content-between align-items-center py-3">
                    <span><i class="bi bi-clock text-primary me-2"></i> Tiempo activo</span>
                    <span class="fw-bold"><?= $uptime ? htmlspecialchars($uptime) : 'No disponible' ?></span>
                </li>
                <li class="list-group-item d-flex justify-content-between align-items-center py-3">
                    <span><i class="bi bi-memory text-primary me-2"></i> Memoria RAM</span>
                    <span class="fw-bold"><?= $memory_info ? htmlspecialchars($memory_info) : 'No disponible' ?></span>
                </li>
                <li class="list-group-item d-flex justify-content-between align-items-center py-3">
                    <span><i class="bi bi-hdd text-primary me-2"></i> Disco Principal (Libre/Total)</span>
                    <span class="fw-bold"><?= $disk_free ?> GB / <?= $disk_total ?> GB</span>
                </li>
            </ul>
        </div>
    </div>

    <div class="col-md-6 mb-4">
        <div class="card shadow-sm h-100 border-0">
            <div class="card-header bg-dark text-white"><i class="bi bi-gear"></i> Servicios Core</div>
            <ul class="list-group list-group-flush">
                <li class="list-group-item d-flex justify-content-between align-items-center py-3">
                    <span><i class="bi bi-shield-lock text-primary me-2"></i> Servicio OpenVPN</span>
                    <span class="badge bg-<?= $status_color ?> fs-6 px-3 py-2"><?= strtoupper($openvpn_status) ?></span>
                </li>
                <li class="list-group-item d-flex justify-content-between align-items-center py-3">
                    <span><i class="bi bi-globe text-primary me-2"></i> Servidor Web</span>
                    <span class="badge bg-success fs-6 px-3 py-2">ACTIVE (Nginx)</span>
                </li>
                <li class="list-group-item d-flex justify-content-between align-items-center py-3">
                    <span><i class="bi bi-database text-primary me-2"></i> Base de Datos</span>
                    <span class="badge bg-success fs-6 px-3 py-2">ACTIVE (MariaDB)</span>
                </li>
            </ul>
        </div>
    </div>
</div>

<?php include __DIR__ . '/../templates/footer.php'; ?>

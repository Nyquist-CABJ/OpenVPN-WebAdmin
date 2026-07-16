<?php
session_start();
if (!isset($_SESSION['user_id'])) { header("Location: login.php"); exit; }
require_once __DIR__ . '/../app/Models/VPNManager.php';

$vpn = new VPNManager();
$activeUsers = $vpn->listUsers();
$connectedDetails = $vpn->getConnectedDetails();

$totalUsers = count($activeUsers);
$connectedCount = count($connectedDetails);
$disconnectedCount = $totalUsers - $connectedCount;

$pageTitle = "Dashboard - DF Techno VPN";
$extraScripts = "<script>setTimeout(function(){ location.reload(); }, 15000);</script>";
include __DIR__ . '/../templates/header.php';
?>

<h3 class="mb-4">Monitor en Vivo</h3>
<div class="row mb-4">
    <div class="col-md-4 mb-3">
        <div class="card bg-success text-white shadow-sm h-100 border-0">
            <div class="card-body d-flex justify-content-between align-items-center">
                <div><h6 class="card-title text-uppercase fw-bold mb-1">En Línea</h6><h2 class="mb-0 display-5 fw-bold"><?= $connectedCount ?></h2></div>
                <i class="bi bi-wifi" style="font-size: 3rem; opacity: 0.5;"></i>
            </div>
        </div>
    </div>
    <div class="col-md-4 mb-3">
        <div class="card bg-secondary text-white shadow-sm h-100 border-0">
            <div class="card-body d-flex justify-content-between align-items-center">
                <div><h6 class="card-title text-uppercase fw-bold mb-1">Desconectados</h6><h2 class="mb-0 display-5 fw-bold"><?= $disconnectedCount ?></h2></div>
                <i class="bi bi-wifi-off" style="font-size: 3rem; opacity: 0.5;"></i>
            </div>
        </div>
    </div>
    <div class="col-md-4 mb-3">
        <div class="card bg-primary text-white shadow-sm h-100 border-0">
            <div class="card-body d-flex justify-content-between align-items-center">
                <div><h6 class="card-title text-uppercase fw-bold mb-1">Perfiles Totales</h6><h2 class="mb-0 display-5 fw-bold"><?= $totalUsers ?></h2></div>
                <i class="bi bi-people" style="font-size: 3rem; opacity: 0.5;"></i>
            </div>
        </div>
    </div>
</div>

<div class="card shadow-sm border-0">
    <div class="card-header bg-dark text-white py-3"><h6 class="mb-0"><i class="bi bi-activity"></i> Estado de los Clientes VPN</h6></div>
    <div class="card-body p-0 table-responsive">
        <table class="table table-hover align-middle m-0 text-center">
            <thead class="table-light">
                <tr><th class="text-start ps-4">Usuario VPN</th><th>Estado</th><th>IP Asignada</th><th>IP Pública</th><th>Tráfico (Rx/Tx)</th><th>Tiempo Conectado</th></tr>
            </thead>
            <tbody>
                <?php if ($totalUsers === 0): ?><tr><td colspan="6" class="py-5 text-muted">No hay perfiles.</td></tr><?php else: ?>
                    <?php foreach ($activeUsers as $user): $isOnline = isset($connectedDetails[$user]); $details = $isOnline ? $connectedDetails[$user] : null; ?>
                        <tr>
                            <td class="fw-bold text-start text-primary ps-4"><i class="bi bi-person-badge"></i> <?= htmlspecialchars($user) ?></td>
                            <td><?php if ($isOnline): ?><span class="badge bg-success rounded-pill px-3"><i class="bi bi-check-circle"></i> Conectado</span><?php else: ?><span class="badge bg-secondary rounded-pill px-3"><i class="bi bi-x-circle"></i> Desconectado</span><?php endif; ?></td>
                            <?php if ($isOnline): ?>
                                <td><span class="badge bg-info text-dark fs-6"><?= htmlspecialchars($details['virtual_ip']) ?></span></td>
                                <td class="small text-muted"><i class="bi bi-globe"></i> <?= htmlspecialchars($details['real_ip']) ?></td>
                                <td class="small"><span class="text-success fw-bold"><i class="bi bi-arrow-down"></i> <?= $details['rx'] ?></span><br><span class="text-primary fw-bold"><i class="bi bi-arrow-up"></i> <?= $details['tx'] ?></span></td>
                                <td class="small text-muted"><i class="bi bi-clock text-primary"></i> <?= htmlspecialchars($details['connected_since']) ?></td>
                            <?php else: ?><td colspan="4" class="text-muted">-</td><?php endif; ?>
                        </tr>
                    <?php endforeach; ?>
                <?php endif; ?>
            </tbody>
        </table>
    </div>
</div>

<?php include __DIR__ . '/../templates/footer.php'; ?>

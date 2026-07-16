<?php
// Archivo: public/logs.php
session_start();
require_once __DIR__ . '/../app/Config/db.php';
if (!isset($_SESSION['user_id'])) { header("Location: login.php"); exit; }

// Traemos solo los registros que tengan datos o que representen una sesión completa
$stmt = $pdo->query("SELECT * FROM connection_history ORDER BY logged_at DESC LIMIT 100");
$logs = $stmt->fetchAll(PDO::FETCH_ASSOC);

$pageTitle = "Auditoría - SD Mates VPN";
include __DIR__ . '/../templates/header.php';
?>

<h3 class="mb-4">Registro Histórico de Sesiones</h3>

<div class="card shadow-sm">
    <div class="card-header bg-dark text-white"><i class="bi bi-clock-history"></i> Últimas 100 sesiones</div>
    <div class="card-body p-0 table-responsive">
        <table class="table table-hover m-0 text-center">
            <thead class="table-light">
                <tr>
                    <th>Fecha</th>
                    <th>Usuario</th>
                    <th>IP Origen</th>
                    <th>IP VPN</th>
                    <th>Horario (Inicio - Fin)</th>
                    <th>Tráfico (Rx / Tx)</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($logs as $log): ?>
                <tr>
                    <td class="small"><?= date('d/m/Y', strtotime($log['logged_at'])) ?></td>
                    
                    <td class="fw-bold text-primary"><?= htmlspecialchars($log['username']) ?></td>
                    
                    <td class="small"><?= htmlspecialchars($log['real_ip']) ?></td>
                    
                    <td><span class="badge bg-info text-dark"><?= htmlspecialchars($log['virtual_ip']) ?></span></td>
                    
                    <td class="small text-muted"><?= htmlspecialchars($log['connected_since']) ?></td>
                    
                    <td class="small">
                        <?php if ($log['bytes_received'] == '0' && $log['bytes_sent'] == '0'): ?>
                            <span class="text-warning">Conectado...</span>
                        <?php else: ?>
                            <span class="text-success"><i class="bi bi-arrow-down"></i> <?= htmlspecialchars($log['bytes_received']) ?></span> / 
                            <span class="text-primary"><i class="bi bi-arrow-up"></i> <?= htmlspecialchars($log['bytes_sent']) ?></span>
                        <?php endif; ?>
                    </td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>

<?php include __DIR__ . '/../templates/footer.php'; ?>

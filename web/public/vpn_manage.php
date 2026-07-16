<?php
session_start();
if (!isset($_SESSION['user_id'])) { header("Location: login.php"); exit; }
require_once __DIR__ . '/../app/Config/db.php';
require_once __DIR__ . '/../app/Models/VPNManager.php';

$vpn = new VPNManager();
$message = ''; $messageType = '';
$isAdmin = ($_SESSION['role'] === 'administrador');

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    $action = $_POST['action']; $targetUser = $_POST['username'] ?? '';
    
    if ($action === 'create' && $isAdmin && preg_match('/^[a-zA-Z0-9_-]+$/', $targetUser)) {
        $r = $vpn->createUser($targetUser); $message = $r['message']; $messageType = $r['status'] === 'success' ? 'success' : 'danger';
    } elseif ($action === 'revoke' && $isAdmin && !empty($targetUser)) {
        $r = $vpn->revokeUser($targetUser); $message = $r['message']; $messageType = $r['status'] === 'success' ? 'success' : 'danger';
    } elseif ($action === 'save_config' && $isAdmin && !empty($targetUser)) {
        
        // Guardamos IP si existe
        if (!empty($_POST['new_ip'])) {
            $vpn->setStaticIP($targetUser, $_POST['new_ip']);
        }
        
        // Guardamos los Ajustes de Acceso en BD
        $isActive = isset($_POST['is_active']) ? (int)$_POST['is_active'] : 1;
        $timeStart = !empty($_POST['time_start']) ? $_POST['time_start'] : null;
        $timeEnd = !empty($_POST['time_end']) ? $_POST['time_end'] : null;
        
        $stmt = $pdo->prepare("INSERT INTO vpn_user_settings (username, is_active, time_start, time_end) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE is_active = ?, time_start = ?, time_end = ?");
        $stmt->execute([$targetUser, $isActive, $timeStart, $timeEnd, $isActive, $timeStart, $timeEnd]);
        
        // Forzamos actualización del Bash inmediatamente al guardar
        $vpn->setAccess($targetUser, $isActive === 1 ? 'allow' : 'deny');
        
        $message = "Configuración actualizada para $targetUser.";
        $messageType = "success";

    } elseif ($action === 'download' && !empty($targetUser)) {
        $content = $vpn->getProfileContent($targetUser);
        if (strpos($content, 'Error:') === false && !empty(trim($content))) {
            if (ob_get_length()) ob_end_clean();
            header('Content-Type: application/octet-stream');
            header('Content-Disposition: attachment; filename="' . $targetUser . '.ovpn"');
            echo $content; exit;
        } else { $message = "Error de descarga."; $messageType = 'danger'; }
    }
}

$activeUsers = $vpn->listUsers();
$userIPs = $vpn->listIPs();

// Obtener configuración de acceso para indicadores
$settingsQuery = $pdo->query("SELECT * FROM vpn_user_settings")->fetchAll(PDO::FETCH_ASSOC);
$userSettings = [];
foreach($settingsQuery as $row) { $userSettings[$row['username']] = $row; }

$pageTitle = "Certificados - SD Mates VPN";
include __DIR__ . '/../templates/header.php';
?>

<h3 class="mb-4">Gestión de Perfiles OpenVPN</h3>
<?php if ($message): ?><div class="alert alert-<?= $messageType ?> alert-dismissible"><button class="btn-close" data-bs-dismiss="alert"></button><?= htmlspecialchars($message) ?></div><?php endif; ?>

<div class="row">
    <?php if ($isAdmin): ?>
    <div class="col-md-4 mb-4">
        <div class="card shadow-sm border-primary">
            <div class="card-header bg-primary text-white"><i class="bi bi-shield-plus"></i> Generar Certificado</div>
            <div class="card-body">
                <form method="POST">
                    <input type="hidden" name="action" value="create">
                    <div class="mb-3">
                        <input type="text" class="form-control" name="username" pattern="[a-zA-Z0-9_-]+" required placeholder="Nombre de usuario (Sin espacios)">
                    </div>
                    <button type="submit" class="btn btn-success w-100"><i class="bi bi-plus-circle"></i> Crear Perfil</button>
                </form>
            </div>
        </div>
    </div>
    <?php endif; ?>
    
    <div class="col-md-<?= $isAdmin ? '8' : '12' ?>">
        <div class="card shadow-sm">
            <div class="card-header bg-dark text-white"><i class="bi bi-file-earmark-lock"></i> Perfiles (<?= count($activeUsers) ?>)</div>
            <div class="table-responsive">
                <table class="table table-hover align-middle m-0">
                    <thead class="table-light">
                        <tr>
                            <th class="ps-3">Estado</th>
                            <th>Usuario VPN</th>
                            <th>IP Asignada (Local)</th>
                            <th class="text-end pe-3">Acciones</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($activeUsers as $user): ?>
                        <?php 
                            $s = $userSettings[$user] ?? ['is_active' => 1, 'time_start' => '', 'time_end' => '']; 
                            $statusColor = ($s['is_active'] == 1) ? 'success' : 'danger';
                        ?>
                        <tr>
                            <td class="ps-3">
                                <span class="badge bg-<?= $statusColor ?> rounded-circle p-2" title="<?= ($s['is_active'] == 1) ? 'Permitido' : 'Bloqueado' ?>"><span class="visually-hidden">Estado</span></span>
                            </td>
                            <td class="fw-bold text-primary"><?= htmlspecialchars($user) ?></td>
                            <td>
                                <span class="badge bg-light text-dark border px-2 py-1 fs-6">
                                    <?= isset($userIPs[$user]) ? htmlspecialchars($userIPs[$user]) : 'Dinámica' ?>
                                </span>
                            </td>
                            <td class="text-end pe-3">
                                <div class="d-inline-flex gap-2">
                                    <?php if ($isAdmin): ?>
                                    <button class="btn btn-sm btn-outline-secondary" data-bs-toggle="modal" data-bs-target="#configModal<?= htmlspecialchars($user) ?>" title="Configuración de Red">
                                        <i class="bi bi-gear"></i> Set
                                    </button>
                                    <?php endif; ?>
                                    
                                    <!-- Botón QR -->
                                    <button class="btn btn-sm btn-outline-info" data-bs-toggle="modal" data-bs-target="#qrModal<?= htmlspecialchars($user) ?>" title="Escanear con el celular">
                                        <i class="bi bi-qr-code"></i>
                                    </button>
                                    
                                    <form method="POST" class="m-0">
                                        <input type="hidden" name="action" value="download">
                                        <input type="hidden" name="username" value="<?= htmlspecialchars($user) ?>">
                                        <button class="btn btn-sm btn-outline-primary" title="Descargar .ovpn"><i class="bi bi-download"></i></button>
                                    </form>
                                    
                                    <?php if ($isAdmin): ?>
                                    <form method="POST" class="m-0" onsubmit="return confirm('¿Revocar certificado de <?= htmlspecialchars($user) ?>?');">
                                        <input type="hidden" name="action" value="revoke">
                                        <input type="hidden" name="username" value="<?= htmlspecialchars($user) ?>">
                                        <button class="btn btn-sm btn-outline-danger" title="Revocar"><i class="bi bi-trash"></i></button>
                                    </form>
                                    <?php endif; ?>
                                </div>
                            </td>
                        </tr>

                        <!-- Modal de QR -->
                        <div class="modal fade" id="qrModal<?= htmlspecialchars($user) ?>" tabindex="-1">
                            <div class="modal-dialog modal-sm text-center">
                                <div class="modal-content">
                                    <div class="modal-header bg-light">
                                        <h6 class="modal-title"><i class="bi bi-qr-code"></i> Escanear Perfil: <?= htmlspecialchars($user) ?></h6>
                                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                                    </div>
                                    <div class="modal-body">
                                        <img src="generate_qr.php?user=<?= urlencode($user) ?>" class="img-fluid border p-2 mb-2" alt="Código QR de VPN">
                                        <p class="small text-muted m-0">Abre <strong>OpenVPN Connect</strong> en tu celular y selecciona <em>"Import Profile > Scan QR Code"</em>.</p>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Modal Unificado de Configuración -->
                        <?php if ($isAdmin): ?>
                        <div class="modal fade" id="configModal<?= htmlspecialchars($user) ?>" tabindex="-1">
                            <div class="modal-dialog">
                                <div class="modal-content">
                                    <div class="modal-header bg-light">
                                        <h6 class="modal-title"><i class="bi bi-gear"></i> Configuración: <?= htmlspecialchars($user) ?></h6>
                                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                                    </div>
                                    <form method="POST">
                                        <div class="modal-body text-start">
                                            <input type="hidden" name="action" value="save_config">
                                            <input type="hidden" name="username" value="<?= htmlspecialchars($user) ?>">
                                            
                                            <div class="mb-3">
                                                <label class="form-label small fw-bold">IP Asignada (Local)</label>
                                                <input type="text" class="form-control" name="new_ip" value="<?= isset($userIPs[$user]) ? htmlspecialchars($userIPs[$user]) : '10.10.20.' ?>">
                                            </div>
                                            
                                            <div class="mb-3">
                                                <label class="form-label small fw-bold text-danger">Interruptor de Emergencia</label>
                                                <select class="form-select border-danger" name="is_active">
                                                    <option value="1">🟢 Permitir Acceso (Activo)</option>
                                                    <option value="0" <?= ($s['is_active'] == 0) ? 'selected' : '' ?>>🔴 Bloquear Inmediatamente</option>
                                                </select>
                                            </div>

                                            <div class="row">
                                                <label class="form-label small fw-bold">Horario de Acceso Permitido (Vacíar para 24hs)</label>
                                                <div class="col-6">
                                                    <input type="time" class="form-control" name="time_start" value="<?= htmlspecialchars($s['time_start'] ?? '') ?>">
                                                    <div class="form-text">Hora Inicio</div>
                                                </div>
                                                <div class="col-6">
                                                    <input type="time" class="form-control" name="time_end" value="<?= htmlspecialchars($s['time_end'] ?? '') ?>">
                                                    <div class="form-text">Hora Fin</div>
                                                </div>
                                            </div>
                                        </div>
                                        <div class="modal-footer p-2">
                                            <button type="submit" class="btn btn-primary w-100">Guardar Cambios</button>
                                        </div>
                                    </form>
                                </div>
                            </div>
                        </div>
                        <?php endif; ?>
                        
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>
<?php include __DIR__ . '/../templates/footer.php'; ?>

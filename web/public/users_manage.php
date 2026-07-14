<?php
session_start();
require_once __DIR__ . '/../app/Config/db.php';
if (!isset($_SESSION['user_id']) || $_SESSION['role'] !== 'administrador') { header("Location: index.php"); exit; }

$message = ''; $messageType = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    if ($_POST['action'] === 'create') {
        $u = trim($_POST['username']); $rn = trim($_POST['real_name']); $p = $_POST['password']; $r = $_POST['role'];
        if ($u && $p) {
            try { $pdo->prepare("INSERT INTO web_users (username, real_name, password_hash, role) VALUES (?,?,?,?)")->execute([$u, $rn, password_hash($p, PASSWORD_DEFAULT), $r]); $message = "Usuario $u creado."; $messageType = "success"; } catch (Exception $e) { $message = "Error."; $messageType = "danger"; }
        }
    }
    if ($_POST['action'] === 'edit') {
        $id = (int)$_POST['user_id']; $rn = trim($_POST['real_name']); $r = $_POST['role']; $np = $_POST['new_password'];
        if ($np) { $pdo->prepare("UPDATE web_users SET real_name=?, role=?, password_hash=? WHERE id=?")->execute([$rn, $r, password_hash($np, PASSWORD_DEFAULT), $id]); }
        else { $pdo->prepare("UPDATE web_users SET real_name=?, role=? WHERE id=?")->execute([$rn, $r, $id]); }
        if ($id === $_SESSION['user_id']) $_SESSION['role'] = $r;
        $message = "Actualizado."; $messageType = "success";
    }
    if ($_POST['action'] === 'delete') {
        $id = (int)$_POST['user_id']; if ($id != $_SESSION['user_id']) { $pdo->prepare("DELETE FROM web_users WHERE id=?")->execute([$id]); }
    }
}
$webUsers = $pdo->query("SELECT * FROM web_users ORDER BY role, username")->fetchAll();
$pageTitle = "Usuarios Web - DF Techno VPN";
include __DIR__ . '/../templates/header.php';
?>

<h3 class="mb-4">Usuarios del Panel</h3>
<?php if ($message): ?><div class="alert alert-<?= $messageType ?>"><?= htmlspecialchars($message) ?></div><?php endif; ?>
<div class="row">
    <div class="col-md-4 mb-4">
        <div class="card shadow-sm border-primary">
            <div class="card-header bg-primary text-white"><i class="bi bi-person-plus"></i> Nuevo Acceso Web</div>
            <div class="card-body">
                <form method="POST"><input type="hidden" name="action" value="create"><input type="text" name="username" class="form-control mb-3" required placeholder="Login"><input type="text" name="real_name" class="form-control mb-3" required placeholder="Nombre Completo"><input type="password" name="password" class="form-control mb-3" required placeholder="Clave"><select name="role" class="form-select mb-3"><option value="operador">Operador</option><option value="administrador">Administrador</option></select><button type="submit" class="btn btn-primary w-100">Crear</button></form>
            </div>
        </div>
    </div>
    <div class="col-md-8">
        <div class="card shadow-sm"><table class="table m-0"><tbody>
            <?php foreach ($webUsers as $u): ?>
            <tr>
                <td><b>@<?= htmlspecialchars($u['username']) ?></b><br><small><?= htmlspecialchars($u['real_name']) ?></small></td>
                <td><span class="badge <?= $u['role'] == 'administrador' ? 'bg-danger' : 'bg-secondary' ?>"><?= $u['role'] ?></span></td>
                <td class="text-end">
                    <button class="btn btn-sm btn-outline-primary" data-bs-toggle="modal" data-bs-target="#editModal<?= $u['id'] ?>"><i class="bi bi-pencil"></i></button>
                    <?php if ($u['id'] != $_SESSION['user_id']): ?><form method="POST" class="d-inline"><input type="hidden" name="action" value="delete"><input type="hidden" name="user_id" value="<?= $u['id'] ?>"><button class="btn btn-sm btn-outline-danger"><i class="bi bi-trash"></i></button></form><?php endif; ?>
                </td>
            </tr>
            <div class="modal fade" id="editModal<?= $u['id'] ?>" tabindex="-1"><div class="modal-dialog"><div class="modal-content"><form method="POST"><div class="modal-body"><input type="hidden" name="action" value="edit"><input type="hidden" name="user_id" value="<?= $u['id'] ?>"><input type="text" name="real_name" class="form-control mb-3" value="<?= htmlspecialchars($u['real_name'] ?? '') ?>"><select name="role" class="form-select mb-3"><option value="operador" <?= $u['role']=='operador'?'selected':'' ?>>Operador</option><option value="administrador" <?= $u['role']=='administrador'?'selected':'' ?>>Administrador</option></select><input type="password" name="new_password" class="form-control" placeholder="Nueva Clave (opcional)"></div><div class="modal-footer"><button type="submit" class="btn btn-primary">Guardar</button></div></form></div></div></div>
            <?php endforeach; ?>
        </tbody></table></div>
    </div>
</div>
<?php include __DIR__ . '/../templates/footer.php'; ?>

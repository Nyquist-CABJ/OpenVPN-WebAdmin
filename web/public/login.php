<?php
session_start();
require_once __DIR__ . '/../app/Config/db.php';

if (isset($_SESSION['user_id'])) {
    header("Location: index.php");
    exit;
}
$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = trim($_POST['username'] ?? '');
    $password = $_POST['password'] ?? '';
    if (!empty($username) && !empty($password)) {
        $stmt = $pdo->prepare("SELECT id, username, password_hash, role FROM web_users WHERE username = ?");
        $stmt->execute([$username]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($user && password_verify($password, $user['password_hash'])) {
            $_SESSION['user_id'] = $user['id'];
            $_SESSION['username'] = $user['username'];
            $_SESSION['role'] = $user['role'];
            $pdo->prepare("UPDATE web_users SET last_login = NOW() WHERE id = ?")->execute([$user['id']]);
            header("Location: index.php");
            exit;
        } else {
            $error = "Usuario o contraseña incorrectos.";
        }
    }
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Login - DF Techno VPN</title>
    <link rel="stylesheet" href="assets/css/bootstrap.min.css">
    <link rel="stylesheet" href="assets/css/bootstrap-icons.css">
    <link rel="stylesheet" href="assets/css/main.css">
</head>
<body class="bg-light d-flex align-items-center" style="height: 100vh;">
<div class="container">
    <div class="row justify-content-center">
        <div class="col-md-4">
            <div class="card shadow border-0">
                <div class="card-header bg-dark text-white text-center py-4">
                    <h4 class="mb-0 text-primary"><i class="bi bi-shield-lock"></i> Acceso VPN</h4>
                </div>
                <div class="card-body p-4">
                    <?php if ($error): ?><div class="alert alert-danger"><?= htmlspecialchars($error) ?></div><?php endif; ?>
                    <form method="POST">
                        <div class="mb-3">
                            <label class="form-label">Usuario</label>
                            <input type="text" name="username" class="form-control" required autofocus>
                        </div>
                        <div class="mb-4">
                            <label class="form-label">Contraseña</label>
                            <input type="password" name="password" class="form-control" required>
                        </div>
                        <button type="submit" class="btn btn-primary w-100">Ingresar</button>
                    </form>
                </div>
            </div>
        </div>
    </div>
</div>
</body>
</html>

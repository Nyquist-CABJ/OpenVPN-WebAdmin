<?php $currentPage = basename($_SERVER['PHP_SELF']); ?>
<div class="bg-dark text-white p-3 d-flex flex-column" style="width: 250px; min-height: 100vh;">
    <h4 class="text-center mb-0 text-primary"><i class="bi bi-shield-lock"></i> DF Techno</h4>
    <p class="text-center text-muted small mt-1">VPN Manager</p>
    <hr>
    
    <div class="mb-3 px-2">
        <small class="text-muted text-uppercase">Sesión</small>
        <div class="d-flex align-items-center mt-2">
            <i class="bi bi-person-circle fs-4 me-2"></i>
            <div>
                <div class="fw-bold lh-1"><?= htmlspecialchars($_SESSION['username']) ?></div>
                <small class="text-secondary"><?= htmlspecialchars($_SESSION['role']) ?></small>
            </div>
        </div>
    </div>
    <hr>

    <ul class="nav nav-pills flex-column mb-auto gap-1">
        <li class="nav-item">
            <a href="index.php" class="nav-link <?= $currentPage == 'index.php' ? 'active bg-primary' : 'text-white' ?>">
                <i class="bi bi-speedometer2 me-2"></i> Dashboard
            </a>
        </li>
        <li class="nav-item">
            <a href="vpn_manage.php" class="nav-link <?= $currentPage == 'vpn_manage.php' ? 'active bg-primary' : 'text-white' ?>">
                <i class="bi bi-key me-2"></i> Certificados VPN
            </a>
        </li>
        <?php if ($_SESSION['role'] === 'administrador'): ?>
        <li class="nav-item">
            <a href="users_manage.php" class="nav-link <?= $currentPage == 'users_manage.php' ? 'active bg-primary' : 'text-white' ?>">
                <i class="bi bi-people me-2"></i> Usuarios Web
            </a>
        </li>
        <?php endif; ?>
        <li class="nav-item">
            <a href="logs.php" class="nav-link <?= $currentPage == 'logs.php' ? 'active bg-primary' : 'text-white' ?>">
                <i class="bi bi-clock-history me-2"></i> Auditoría y Logs
            </a>
        </li>
        <li class="nav-item">
            <a href="system.php" class="nav-link <?= $currentPage == 'system.php' ? 'active bg-primary' : 'text-white' ?>">
                <i class="bi bi-gear me-2"></i> Sistema
            </a>
        </li>
    </ul>
    
    <hr>
    <a href="logout.php" class="btn btn-outline-danger w-100"><i class="bi bi-box-arrow-right"></i> Cerrar Sesión</a>
</div>

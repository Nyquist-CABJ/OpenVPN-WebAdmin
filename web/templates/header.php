<?php
$pageTitle = $pageTitle ?? 'DF Techno - VPN Manager';
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= htmlspecialchars($pageTitle) ?></title>
    
    <link rel="stylesheet" href="assets/css/bootstrap.min.css">
    <link rel="stylesheet" href="assets/css/bootstrap-icons.css">
    <link rel="stylesheet" href="assets/css/main.css">
</head>
<body class="bg-light">
<div class="d-flex">
    <?php include __DIR__ . '/sidebar.php'; ?>
    
    <!-- Columna derecha convertida en un contenedor flexible vertical -->
    <div class="flex-grow-1 d-flex flex-column" style="height: 100vh; overflow-y: auto;">
        
        <!-- Este div empujará el footer hacia abajo gracias a flex-grow-1 -->
        <div class="p-4 flex-grow-1">

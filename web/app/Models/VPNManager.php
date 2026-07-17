<?php
class VPNManager {
    private $scriptPath = "sudo /usr/local/bin/vpn-manager-web.sh";

    public function createUser($username) {
        $cleanUsername = escapeshellarg(trim($username));
        $output = shell_exec("{$this->scriptPath} create {$cleanUsername} 2>&1");
        if (strpos($output, 'Error:') !== false) return ['status' => 'error', 'message' => $output];
        return ['status' => 'success', 'message' => "Usuario $username creado correctamente."];
    }

    public function revokeUser($username) {
        $cleanUsername = escapeshellarg(trim($username));
        $output = shell_exec("{$this->scriptPath} revoke {$cleanUsername} 2>&1");
        if (strpos($output, 'Error:') !== false) return ['status' => 'error', 'message' => $output];
        return ['status' => 'success', 'message' => "Usuario $username revocado y eliminado."];
    }

    public function getProfileContent($username) {
        $cleanUsername = escapeshellarg(trim($username));
        return shell_exec("{$this->scriptPath} profile {$cleanUsername}");
    }

    public function listUsers() {
        $output = shell_exec("{$this->scriptPath} list");
        if (empty(trim($output))) return [];
        return array_filter(explode("\n", trim($output)));
    }

    public function listIPs() {
        $output = shell_exec("{$this->scriptPath} ips");
        $ips = [];
        if (!empty(trim($output))) {
            foreach(explode("\n", trim($output)) as $line) {
                $parts = preg_split('/\s+/', trim($line));
                if (isset($parts[0], $parts[1])) {
                    $ips[$parts[0]] = $parts[1]; 
                }
            }
        }
        return $ips;
    }

    public function setStaticIP($username, $ip, $network = '', $netmask = '') {
        $cleanUsername = escapeshellarg(trim($username));
        $cleanIP = escapeshellarg(trim($ip));
        $cleanNet = escapeshellarg(trim($network ?: 'null'));
        $cleanMask = escapeshellarg(trim($netmask ?: 'null'));
        $output = shell_exec("{$this->scriptPath} setip {$cleanUsername} {$cleanIP} {$cleanNet} {$cleanMask} 2>&1");
        if (strpos($output, 'Error:') !== false) return ['status' => 'error', 'message' => $output];
        return ['status' => 'success', 'message' => "IP $ip y rutas asignadas correctamente a $username."];
    }

    public function setAccess($username, $access) {
        $cleanUsername = escapeshellarg(trim($username));
        $cleanAccess = escapeshellarg(trim($access));
        shell_exec("{$this->scriptPath} access {$cleanUsername} {$cleanAccess}");
    }

    public function getConnectedDetails() {
        $output = shell_exec("{$this->scriptPath} details");
        $details = [];
        if (!empty(trim($output))) {
            $lines = explode("\n", trim($output));
            foreach ($lines as $line) {
                $line = trim($line);
                if (empty($line)) continue;
                $parts = explode(',', $line);
                if (count($parts) >= 8 && $parts[0] === 'CLIENT_LIST') {
                    $username = $parts[1];
                    $real_ip_port = explode(':', $parts[2]);
                    $details[$username] = [
                        'real_ip' => $real_ip_port[0] ?? 'N/A',
                        'virtual_ip' => $parts[3] ?? 'N/A',
                        'rx' => $this->formatBytes($parts[5] ?? 0),
                        'tx' => $this->formatBytes($parts[6] ?? 0),
                        'connected_since' => $parts[7] ?? 'N/A'
                    ];
                }
            }
        }
        return $details;
    }

    private function formatBytes($bytes) {
        $units = ['B', 'KB', 'MB', 'GB'];
        $bytes = max($bytes, 0);
        $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
        $pow = min($pow, count($units) - 1);
        $bytes /= (1 << (10 * $pow));
        return round($bytes, 2) . ' ' . $units[$pow];
    }
}
?>

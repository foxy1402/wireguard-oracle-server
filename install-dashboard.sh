#!/bin/bash

###############################################################################
# WireGuard Web Dashboard Setup Script
# Simple Python-based dashboard for managing WireGuard
###############################################################################

set -e

echo "Installing WireGuard Web Dashboard..."

# Install dependencies
sudo dnf install -y python3 python3-pip

# Create dashboard directory
mkdir -p /opt/wireguard-dashboard
cd /opt/wireguard-dashboard

# Create Python web dashboard
cat > app.py <<'PYEOF'
#!/usr/bin/env python3
import subprocess
import os
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import urllib.parse

class WireGuardHandler(BaseHTTPRequestHandler):
    
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(self.get_dashboard_html().encode())
        
        elif self.path == '/api/status':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            status = self.get_wg_status()
            self.wfile.write(json.dumps(status).encode())
        
        elif self.path == '/api/diagnostics':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            diagnostics = self.run_diagnostics()
            self.wfile.write(json.dumps(diagnostics).encode())
        
        elif self.path.startswith('/download/'):
            client_name = self.path.split('/')[-1].replace('.conf', '')
            self.download_config(client_name)
        
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_POST(self):
        if self.path == '/api/add-client':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            data = urllib.parse.parse_qs(post_data.decode())
            client_name = data.get('client_name', [''])[0]
            
            if client_name:
                result = self.add_client(client_name)
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(result).encode())
            else:
                self.send_response(400)
                self.end_headers()
        
        elif self.path == '/api/auto-fix':
            result = self.auto_fix()
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(result).encode())
        
        else:
            self.send_response(404)
            self.end_headers()
    
    def get_wg_status(self):
        try:
            output = subprocess.check_output(['wg', 'show'], stderr=subprocess.STDOUT).decode()
            service_status = subprocess.check_output(['systemctl', 'is-active', 'wg-quick@wg0']).decode().strip()
            
            return {
                'status': 'running' if service_status == 'active' else 'stopped',
                'output': output
            }
        except Exception as e:
            return {'status': 'error', 'error': str(e)}
    
    def run_diagnostics(self):
        diagnostics = {}
        
        # IP Forwarding
        try:
            ip_forward = subprocess.check_output(['sysctl', 'net.ipv4.ip_forward']).decode().strip()
            diagnostics['ip_forward'] = 'enabled' if '= 1' in ip_forward else 'disabled'
        except:
            diagnostics['ip_forward'] = 'error'
        
        # NAT Rules
        try:
            nat_rules = subprocess.check_output(['iptables', '-t', 'nat', '-L', 'POSTROUTING', '-n']).decode()
            diagnostics['nat_rules'] = 'configured' if 'MASQUERADE' in nat_rules else 'missing'
        except:
            diagnostics['nat_rules'] = 'error'
        
        # WireGuard Interface
        try:
            wg_interface = subprocess.check_output(['ip', 'addr', 'show', 'wg0']).decode()
            diagnostics['wg_interface'] = 'up' if 'state UP' in wg_interface else 'down'
        except:
            diagnostics['wg_interface'] = 'down'
        
        # Firewall
        try:
            firewall_rules = subprocess.check_output(['firewall-cmd', '--list-ports']).decode()
            diagnostics['firewall'] = 'configured' if '51820/udp' in firewall_rules else 'not configured'
        except:
            diagnostics['firewall'] = 'not running'
        
        return diagnostics
    
    def add_client(self, client_name):
        try:
            # Get next available IP
            config_file = '/etc/wireguard/wg0.conf'
            with open(config_file, 'r') as f:
                content = f.read()
            
            # Find last IP
            import re
            ips = re.findall(r'AllowedIPs = 10\.8\.0\.(\d+)', content)
            next_ip = max([int(ip) for ip in ips]) + 1 if ips else 2
            
            # Generate keys
            private_key = subprocess.check_output(['wg', 'genkey']).decode().strip()
            public_key = subprocess.check_output(['wg', 'pubkey'], input=private_key.encode()).decode().strip()
            preshared_key = subprocess.check_output(['wg', 'genpsk']).decode().strip()
            
            # Get server public key
            with open('/etc/wireguard/server_public.key', 'r') as f:
                server_public = f.read().strip()
            
            # Get public IP
            public_ip = subprocess.check_output(['curl', '-s', 'ifconfig.me']).decode().strip()
            
            # Add peer to server config
            peer_config = f"""
[Peer]
# {client_name}
PublicKey = {public_key}
PresharedKey = {preshared_key}
AllowedIPs = 10.8.0.{next_ip}/32
"""
            with open(config_file, 'a') as f:
                f.write(peer_config)
            
            # Create client config
            client_config = f"""[Interface]
PrivateKey = {private_key}
Address = 10.8.0.{next_ip}/24
DNS = 1.1.1.1, 8.8.8.8
MTU = 1420

[Peer]
PublicKey = {server_public}
PresharedKey = {preshared_key}
Endpoint = {public_ip}:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
"""
            
            client_file = f'/etc/wireguard/client_{client_name}.conf'
            with open(client_file, 'w') as f:
                f.write(client_config)
            
            # Restart WireGuard
            subprocess.run(['systemctl', 'restart', 'wg-quick@wg0'])
            
            return {
                'success': True,
                'message': f'Client {client_name} added successfully',
                'download_url': f'/download/{client_name}.conf'
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def download_config(self, client_name):
        config_file = f'/etc/wireguard/client_{client_name}.conf'
        if os.path.exists(config_file):
            with open(config_file, 'r') as f:
                content = f.read()
            
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.send_header('Content-Disposition', f'attachment; filename="{client_name}.conf"')
            self.end_headers()
            self.wfile.write(content.encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def auto_fix(self):
        fixes = []
        
        try:
            # Fix IP forwarding
            subprocess.run(['sysctl', '-w', 'net.ipv4.ip_forward=1'], check=True)
            fixes.append('IP forwarding enabled')
            
            # Get interface
            iface = subprocess.check_output(['ip', 'route']).decode()
            iface = iface.split('default via')[1].split()[2] if 'default via' in iface else 'ens3'
            
            # Fix NAT
            subprocess.run(['iptables', '-t', 'nat', '-A', 'POSTROUTING', '-s', '10.8.0.0/24', '-o', iface, '-j', 'MASQUERADE'], check=False)
            fixes.append('NAT rules added')
            
            # Fix firewall
            subprocess.run(['firewall-cmd', '--permanent', '--add-port=51820/udp'], check=False)
            subprocess.run(['firewall-cmd', '--permanent', '--zone=public', '--add-masquerade'], check=False)
            subprocess.run(['firewall-cmd', '--reload'], check=False)
            fixes.append('Firewall configured')
            
            # Restart WireGuard
            subprocess.run(['systemctl', 'restart', 'wg-quick@wg0'], check=True)
            fixes.append('WireGuard restarted')
            
            return {'success': True, 'fixes': fixes}
        except Exception as e:
            return {'success': False, 'error': str(e), 'fixes': fixes}
    
    def get_dashboard_html(self):
        return '''
<!DOCTYPE html>
<html>
<head>
    <title>WireGuard Dashboard</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .header {
            background: white;
            border-radius: 10px;
            padding: 30px;
            margin-bottom: 20px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
        }
        .header h1 {
            color: #333;
            margin-bottom: 10px;
        }
        .header p {
            color: #666;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        .card {
            background: white;
            border-radius: 10px;
            padding: 25px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
        }
        .card h2 {
            color: #333;
            margin-bottom: 15px;
            font-size: 20px;
        }
        .status-badge {
            display: inline-block;
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 14px;
            font-weight: 600;
            margin: 5px 0;
        }
        .status-running { background: #10b981; color: white; }
        .status-stopped { background: #ef4444; color: white; }
        .status-enabled { background: #10b981; color: white; }
        .status-disabled { background: #ef4444; color: white; }
        .status-configured { background: #10b981; color: white; }
        .status-missing { background: #f59e0b; color: white; }
        .btn {
            background: #667eea;
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 6px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 600;
            transition: all 0.3s;
            margin: 5px;
        }
        .btn:hover {
            background: #5568d3;
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }
        .btn-success { background: #10b981; }
        .btn-success:hover { background: #059669; }
        .btn-warning { background: #f59e0b; }
        .btn-warning:hover { background: #d97706; }
        .form-group {
            margin: 15px 0;
        }
        .form-group label {
            display: block;
            margin-bottom: 5px;
            color: #333;
            font-weight: 600;
        }
        .form-group input {
            width: 100%;
            padding: 10px;
            border: 2px solid #e5e7eb;
            border-radius: 6px;
            font-size: 14px;
        }
        .form-group input:focus {
            outline: none;
            border-color: #667eea;
        }
        .output {
            background: #f9fafb;
            padding: 15px;
            border-radius: 6px;
            font-family: monospace;
            font-size: 12px;
            white-space: pre-wrap;
            max-height: 300px;
            overflow-y: auto;
            margin-top: 15px;
        }
        .alert {
            padding: 15px;
            border-radius: 6px;
            margin: 15px 0;
        }
        .alert-success { background: #d1fae5; color: #065f46; }
        .alert-error { background: #fee2e2; color: #991b1b; }
        .alert-warning { background: #fef3c7; color: #92400e; }
        .diagnostic-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 10px 0;
            border-bottom: 1px solid #e5e7eb;
        }
        .diagnostic-item:last-child {
            border-bottom: none;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔐 WireGuard Dashboard</h1>
            <p>Manage your WireGuard VPN server on Oracle Linux</p>
        </div>
        
        <div class="grid">
            <div class="card">
                <h2>Server Status</h2>
                <div id="server-status">Loading...</div>
                <button class="btn" onclick="refreshStatus()">Refresh Status</button>
            </div>
            
            <div class="card">
                <h2>Diagnostics</h2>
                <div id="diagnostics">Loading...</div>
                <button class="btn btn-warning" onclick="runAutoFix()">Auto-Fix Issues</button>
            </div>
        </div>
        
        <div class="card">
            <h2>Add New Client</h2>
            <div class="form-group">
                <label>Client Name</label>
                <input type="text" id="client-name" placeholder="e.g., laptop, phone, work-computer">
            </div>
            <button class="btn btn-success" onclick="addClient()">Add Client</button>
            <div id="add-client-result"></div>
        </div>
        
        <div class="card">
            <h2>Active Connections</h2>
            <div id="connections" class="output">Loading...</div>
        </div>
    </div>
    
    <script>
        function refreshStatus() {
            fetch('/api/status')
                .then(r => r.json())
                .then(data => {
                    const statusDiv = document.getElementById('server-status');
                    const statusClass = data.status === 'running' ? 'status-running' : 'status-stopped';
                    statusDiv.innerHTML = `
                        <div class="status-badge ${statusClass}">${data.status.toUpperCase()}</div>
                    `;
                    
                    document.getElementById('connections').textContent = data.output || 'No active connections';
                });
            
            fetch('/api/diagnostics')
                .then(r => r.json())
                .then(data => {
                    const diagDiv = document.getElementById('diagnostics');
                    diagDiv.innerHTML = `
                        <div class="diagnostic-item">
                            <span>IP Forwarding</span>
                            <span class="status-badge status-${data.ip_forward}">${data.ip_forward}</span>
                        </div>
                        <div class="diagnostic-item">
                            <span>NAT Rules</span>
                            <span class="status-badge status-${data.nat_rules}">${data.nat_rules}</span>
                        </div>
                        <div class="diagnostic-item">
                            <span>WireGuard Interface</span>
                            <span class="status-badge status-${data.wg_interface === 'up' ? 'enabled' : 'disabled'}">${data.wg_interface}</span>
                        </div>
                        <div class="diagnostic-item">
                            <span>Firewall</span>
                            <span class="status-badge status-${data.firewall}">${data.firewall}</span>
                        </div>
                    `;
                });
        }
        
        function addClient() {
            const clientName = document.getElementById('client-name').value;
            if (!clientName) {
                alert('Please enter a client name');
                return;
            }
            
            fetch('/api/add-client', {
                method: 'POST',
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                body: 'client_name=' + encodeURIComponent(clientName)
            })
            .then(r => r.json())
            .then(data => {
                const resultDiv = document.getElementById('add-client-result');
                if (data.success) {
                    resultDiv.innerHTML = `
                        <div class="alert alert-success">
                            ${data.message}<br>
                            <a href="${data.download_url}" class="btn" style="margin-top: 10px;">Download Config</a>
                        </div>
                    `;
                    document.getElementById('client-name').value = '';
                    refreshStatus();
                } else {
                    resultDiv.innerHTML = `<div class="alert alert-error">Error: ${data.error}</div>`;
                }
            });
        }
        
        function runAutoFix() {
            if (!confirm('Run auto-fix? This will restart WireGuard and modify firewall rules.')) return;
            
            fetch('/api/auto-fix', {method: 'POST'})
            .then(r => r.json())
            .then(data => {
                const diagDiv = document.getElementById('diagnostics');
                if (data.success) {
                    diagDiv.innerHTML = `
                        <div class="alert alert-success">
                            Auto-fix completed:<br>
                            ${data.fixes.map(f => '✓ ' + f).join('<br>')}
                        </div>
                    ` + diagDiv.innerHTML;
                } else {
                    diagDiv.innerHTML = `
                        <div class="alert alert-error">
                            Auto-fix failed: ${data.error}<br>
                            Completed: ${data.fixes.join(', ')}
                        </div>
                    ` + diagDiv.innerHTML;
                }
                setTimeout(refreshStatus, 2000);
            });
        }
        
        // Initial load
        refreshStatus();
        setInterval(refreshStatus, 30000); // Refresh every 30 seconds
    </script>
</body>
</html>
        '''

def run_server(port=8080):
    server = HTTPServer(('0.0.0.0', port), WireGuardHandler)
    print(f'WireGuard Dashboard running on http://0.0.0.0:{port}')
    print('Press Ctrl+C to stop')
    server.serve_forever()

if __name__ == '__main__':
    run_server()
PYEOF

chmod +x app.py

# Create systemd service
sudo tee /etc/systemd/system/wireguard-dashboard.service > /dev/null <<EOF
[Unit]
Description=WireGuard Web Dashboard
After=network.target wg-quick@wg0.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/wireguard-dashboard
ExecStart=/usr/bin/python3 /opt/wireguard-dashboard/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the dashboard
sudo systemctl daemon-reload
sudo systemctl enable wireguard-dashboard
sudo systemctl start wireguard-dashboard

# Configure firewall
sudo firewall-cmd --permanent --add-port=8080/tcp 2>/dev/null || true
sudo firewall-cmd --reload 2>/dev/null || true

echo ""
echo "============================================="
echo "WireGuard Dashboard installed successfully!"
echo "============================================="
echo ""
echo "Access the dashboard at: http://YOUR_SERVER_IP:8080"
echo ""
echo "Don't forget to configure Oracle Cloud Security List:"
echo "Add Ingress Rule: Source 0.0.0.0/0, TCP, Port 8080"
echo ""
echo "To stop the dashboard: sudo systemctl stop wireguard-dashboard"
echo "To start the dashboard: sudo systemctl start wireguard-dashboard"

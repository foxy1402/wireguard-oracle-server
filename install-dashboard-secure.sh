#!/bin/bash

###############################################################################
# WireGuard Web Dashboard Setup Script - SECURE VERSION WITH PASSWORD
# Includes first-time password setup and proper authentication
###############################################################################

set -e

echo "Installing WireGuard Web Dashboard (Secure Version)..."

# Install dependencies
sudo dnf install -y python3 python3-pip

# Create dashboard directory
mkdir -p /opt/wireguard-dashboard
cd /opt/wireguard-dashboard

# Create Python web dashboard with password authentication
cat > app.py <<'PYEOF'
#!/usr/bin/env python3
import subprocess
import os
import json
import urllib.parse
import hashlib
import secrets
from http.server import HTTPServer, BaseHTTPRequestHandler
from http.cookies import SimpleCookie

# Password storage file
PASSWORD_FILE = '/opt/wireguard-dashboard/password.hash'
SESSION_FILE = '/opt/wireguard-dashboard/session.key'

def hash_password(password):
    """Hash a password for storing."""
    salt = secrets.token_hex(16)
    pwdhash = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt.encode('utf-8'), 100000)
    return salt + ':' + pwdhash.hex()

def verify_password(stored_password, provided_password):
    """Verify a stored password against one provided by user"""
    salt, pwdhash = stored_password.split(':')
    check_hash = hashlib.pbkdf2_hmac('sha256', provided_password.encode('utf-8'), salt.encode('utf-8'), 100000)
    return pwdhash == check_hash.hex()

def get_session_token():
    """Get or create session token"""
    if os.path.exists(SESSION_FILE):
        with open(SESSION_FILE, 'r') as f:
            return f.read().strip()
    else:
        token = secrets.token_urlsafe(32)
        with open(SESSION_FILE, 'w') as f:
            f.write(token)
        os.chmod(SESSION_FILE, 0o600)
        return token

def is_password_set():
    """Check if password has been set"""
    return os.path.exists(PASSWORD_FILE)

def check_auth(handler):
    """Check if user is authenticated"""
    if not is_password_set():
        return True  # Allow access if no password set yet
    
    cookie = SimpleCookie()
    if 'Cookie' in handler.headers:
        cookie.load(handler.headers['Cookie'])
    
    if 'session' in cookie:
        session_token = get_session_token()
        return cookie['session'].value == session_token
    
    return False

class WireGuardHandler(BaseHTTPRequestHandler):
    
    def do_GET(self):
        # Setup page (first time)
        if not is_password_set() and self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(self.get_setup_html().encode())
            return
        
        # Login page
        if self.path == '/login':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(self.get_login_html().encode())
            return
        
        # Check authentication for all other pages
        if not check_auth(self):
            self.send_response(302)
            self.send_header('Location', '/login')
            self.end_headers()
            return
        
        # Main dashboard
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
        
        elif self.path == '/logout':
            self.send_response(302)
            self.send_header('Set-Cookie', 'session=; Max-Age=0')
            self.send_header('Location', '/login')
            self.end_headers()
        
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        data = urllib.parse.parse_qs(post_data.decode())
        
        # Setup password (first time)
        if self.path == '/api/setup':
            password = data.get('password', [''])[0]
            confirm = data.get('confirm', [''])[0]
            
            if not password or len(password) < 8:
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'success': False, 'error': 'Password must be at least 8 characters'}).encode())
                return
            
            if password != confirm:
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'success': False, 'error': 'Passwords do not match'}).encode())
                return
            
            # Save hashed password
            hashed = hash_password(password)
            with open(PASSWORD_FILE, 'w') as f:
                f.write(hashed)
            os.chmod(PASSWORD_FILE, 0o600)
            
            # Create session
            session_token = get_session_token()
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Set-Cookie', f'session={session_token}; Path=/; HttpOnly; Max-Age=86400')
            self.end_headers()
            self.wfile.write(json.dumps({'success': True}).encode())
            return
        
        # Login
        if self.path == '/api/login':
            password = data.get('password', [''])[0]
            
            if not is_password_set():
                self.send_response(302)
                self.send_header('Location', '/')
                self.end_headers()
                return
            
            with open(PASSWORD_FILE, 'r') as f:
                stored_password = f.read().strip()
            
            if verify_password(stored_password, password):
                session_token = get_session_token()
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.send_header('Set-Cookie', f'session={session_token}; Path=/; HttpOnly; Max-Age=86400')
                self.end_headers()
                self.wfile.write(json.dumps({'success': True}).encode())
            else:
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'success': False, 'error': 'Invalid password'}).encode())
            return
        
        # Check authentication for other POST requests
        if not check_auth(self):
            self.send_response(401)
            self.end_headers()
            return
        
        if self.path == '/api/add-client':
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
            # Check if wg0 exists first
            check_interface = subprocess.run(['ip', 'link', 'show', 'wg0'], 
                                            capture_output=True, text=True)
            
            if check_interface.returncode != 0:
                return {'status': 'stopped', 'output': 'Interface wg0 not found'}
            
            # Check service status
            service_check = subprocess.run(['systemctl', 'is-active', 'wg-quick@wg0'],
                                          capture_output=True, text=True)
            
            # Get wg show output
            output = subprocess.check_output(['wg', 'show'], stderr=subprocess.STDOUT).decode()
            
            # WireGuard service shows "active (exited)" which is normal
            # So we check if interface exists and has output
            status = 'running' if output.strip() else 'stopped'
            
            return {
                'status': status,
                'output': output,
                'service_state': service_check.stdout.strip()
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
        
        # WireGuard Interface - IMPROVED CHECK
        try:
            # Check if interface exists (better than checking UP state)
            wg_check = subprocess.run(['ip', 'link', 'show', 'wg0'], 
                                     capture_output=True, text=True)
            if wg_check.returncode == 0:
                # Check if it has an IP assigned
                ip_check = subprocess.run(['ip', 'addr', 'show', 'wg0'],
                                         capture_output=True, text=True)
                diagnostics['wg_interface'] = 'up' if '10.8.0.1' in ip_check.stdout else 'down'
            else:
                diagnostics['wg_interface'] = 'down'
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
    
    def get_setup_html(self):
        return '''
<!DOCTYPE html>
<html>
<head>
    <title>WireGuard Dashboard - First Time Setup</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .setup-box {
            background: white;
            border-radius: 10px;
            padding: 40px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            max-width: 400px;
            width: 100%;
        }
        h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 24px;
        }
        p {
            color: #666;
            margin-bottom: 30px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            color: #333;
            font-weight: 600;
        }
        input {
            width: 100%;
            padding: 12px;
            border: 2px solid #e5e7eb;
            border-radius: 6px;
            font-size: 14px;
        }
        input:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            width: 100%;
            background: #667eea;
            color: white;
            border: none;
            padding: 12px;
            border-radius: 6px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: background 0.3s;
        }
        button:hover {
            background: #5568d3;
        }
        .alert {
            padding: 12px;
            border-radius: 6px;
            margin-bottom: 20px;
        }
        .alert-error {
            background: #fee2e2;
            color: #991b1b;
        }
        .alert-success {
            background: #d1fae5;
            color: #065f46;
        }
        .info-box {
            background: #f0f9ff;
            border-left: 4px solid #667eea;
            padding: 15px;
            margin-bottom: 20px;
            border-radius: 4px;
        }
        .info-box ul {
            margin-left: 20px;
            color: #334155;
        }
        .info-box li {
            margin: 5px 0;
        }
    </style>
</head>
<body>
    <div class="setup-box">
        <h1>🔐 Welcome to WireGuard Dashboard</h1>
        <p>Please set a password to secure your dashboard</p>
        
        <div class="info-box">
            <strong>Password Requirements:</strong>
            <ul>
                <li>At least 8 characters</li>
                <li>Use a strong, unique password</li>
                <li>Store it safely (you'll need it to login)</li>
            </ul>
        </div>
        
        <div id="message"></div>
        
        <form id="setupForm">
            <div class="form-group">
                <label>Password</label>
                <input type="password" id="password" required minlength="8" placeholder="Enter password">
            </div>
            <div class="form-group">
                <label>Confirm Password</label>
                <input type="password" id="confirm" required minlength="8" placeholder="Confirm password">
            </div>
            <button type="submit">Set Password & Continue</button>
        </form>
    </div>
    
    <script>
        document.getElementById('setupForm').addEventListener('submit', function(e) {
            e.preventDefault();
            
            const password = document.getElementById('password').value;
            const confirm = document.getElementById('confirm').value;
            const messageDiv = document.getElementById('message');
            
            if (password !== confirm) {
                messageDiv.innerHTML = '<div class="alert alert-error">Passwords do not match!</div>';
                return;
            }
            
            if (password.length < 8) {
                messageDiv.innerHTML = '<div class="alert alert-error">Password must be at least 8 characters!</div>';
                return;
            }
            
            fetch('/api/setup', {
                method: 'POST',
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                body: 'password=' + encodeURIComponent(password) + '&confirm=' + encodeURIComponent(confirm)
            })
            .then(r => r.json())
            .then(data => {
                if (data.success) {
                    messageDiv.innerHTML = '<div class="alert alert-success">Password set successfully! Redirecting...</div>';
                    setTimeout(() => window.location.href = '/', 1000);
                } else {
                    messageDiv.innerHTML = '<div class="alert alert-error">' + data.error + '</div>';
                }
            });
        });
    </script>
</body>
</html>
        '''
    
    def get_login_html(self):
        return '''
<!DOCTYPE html>
<html>
<head>
    <title>WireGuard Dashboard - Login</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .login-box {
            background: white;
            border-radius: 10px;
            padding: 40px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            max-width: 400px;
            width: 100%;
        }
        h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 24px;
        }
        p {
            color: #666;
            margin-bottom: 30px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            color: #333;
            font-weight: 600;
        }
        input {
            width: 100%;
            padding: 12px;
            border: 2px solid #e5e7eb;
            border-radius: 6px;
            font-size: 14px;
        }
        input:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            width: 100%;
            background: #667eea;
            color: white;
            border: none;
            padding: 12px;
            border-radius: 6px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: background 0.3s;
        }
        button:hover {
            background: #5568d3;
        }
        .alert {
            padding: 12px;
            border-radius: 6px;
            margin-bottom: 20px;
        }
        .alert-error {
            background: #fee2e2;
            color: #991b1b;
        }
    </style>
</head>
<body>
    <div class="login-box">
        <h1>🔐 WireGuard Dashboard</h1>
        <p>Please enter your password</p>
        
        <div id="message"></div>
        
        <form id="loginForm">
            <div class="form-group">
                <label>Password</label>
                <input type="password" id="password" required placeholder="Enter your password">
            </div>
            <button type="submit">Login</button>
        </form>
    </div>
    
    <script>
        document.getElementById('loginForm').addEventListener('submit', function(e) {
            e.preventDefault();
            
            const password = document.getElementById('password').value;
            const messageDiv = document.getElementById('message');
            
            fetch('/api/login', {
                method: 'POST',
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                body: 'password=' + encodeURIComponent(password)
            })
            .then(r => r.json())
            .then(data => {
                if (data.success) {
                    window.location.href = '/';
                } else {
                    messageDiv.innerHTML = '<div class="alert alert-error">Invalid password!</div>';
                }
            });
        });
    </script>
</body>
</html>
        '''
    
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
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .header h1 {
            color: #333;
            margin-bottom: 10px;
        }
        .header p {
            color: #666;
        }
        .logout-btn {
            background: #ef4444;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 6px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 600;
            text-decoration: none;
        }
        .logout-btn:hover {
            background: #dc2626;
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
        .status-up { background: #10b981; color: white; }
        .status-down { background: #f59e0b; color: white; }
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
        .alert-info { background: #dbeafe; color: #1e40af; }
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
            <div>
                <h1>🔐 WireGuard Dashboard</h1>
                <p>Manage your WireGuard VPN server on Oracle Linux</p>
            </div>
            <a href="/logout" class="logout-btn">Logout</a>
        </div>
        
        <div class="alert alert-info">
            <strong>ℹ️ Interface Status Note:</strong> If "WireGuard Interface" shows "down" but you have active connections,
            <strong>this is often a false alarm</strong>. WireGuard runs as "active (exited)" which is normal.
            Check "Active Connections" below - if you see recent handshakes, your VPN is working correctly!
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
                    
                    let statusHtml = `
                        <div class="status-badge ${statusClass}">${data.status.toUpperCase()}</div>
                    `;
                    
                    if (data.service_state) {
                        statusHtml += `<p style="margin-top: 10px; font-size: 13px; color: #666;">
                            Service: ${data.service_state}
                        </p>`;
                    }
                    
                    statusDiv.innerHTML = statusHtml;
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
                            <span class="status-badge status-${data.wg_interface}">${data.wg_interface}</span>
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
Description=WireGuard Web Dashboard (Secure)
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
PUBLIC_IP=$(curl -s ifconfig.me)
echo "Access the dashboard at: http://${PUBLIC_IP}:8080"
echo ""
echo "🔐 FIRST TIME SETUP:"
echo "  1. Open http://${PUBLIC_IP}:8080 in your browser"
echo "  2. You'll see a 'Set Password' screen"
echo "  3. Create a strong password (at least 8 characters)"
echo "  4. Login with your new password"
echo ""
echo "⚠️  IMPORTANT - Oracle Cloud Security List:"
echo "Add Ingress Rule: Source 0.0.0.0/0, TCP, Port 8080"
echo ""
echo "📖 Password reset (if you forget it):"
echo "  sudo rm -f /opt/wireguard-dashboard/password.hash"
echo "  sudo systemctl restart wireguard-dashboard"
echo "  Then visit the dashboard URL to set a new password"
echo ""
echo "Commands:"
echo "  Stop dashboard:    sudo systemctl stop wireguard-dashboard"
echo "  Start dashboard:   sudo systemctl start wireguard-dashboard"
echo "  Restart dashboard: sudo systemctl restart wireguard-dashboard"

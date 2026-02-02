#!/bin/bash

###############################################################################
# Upgrade to Enhanced Dashboard with Client Management
###############################################################################

echo "Upgrading WireGuard Dashboard..."

# Stop current dashboard
sudo systemctl stop wireguard-dashboard

# Backup old app
sudo cp /opt/wireguard-dashboard/app.py /opt/wireguard-dashboard/app.py.backup 2>/dev/null || true

# Create enhanced dashboard
sudo tee /opt/wireguard-dashboard/app.py > /dev/null << 'PYEOF'
#!/usr/bin/env python3
import subprocess
import os
import json
import urllib.parse
import hashlib
import secrets
import re
from http.server import HTTPServer, BaseHTTPRequestHandler
from http.cookies import SimpleCookie

PASSWORD_FILE = '/opt/wireguard-dashboard/password.hash'
SESSION_FILE = '/opt/wireguard-dashboard/session.key'

def hash_password(password):
    salt = secrets.token_hex(16)
    pwdhash = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt.encode('utf-8'), 100000)
    return salt + ':' + pwdhash.hex()

def verify_password(stored_password, provided_password):
    salt, pwdhash = stored_password.split(':')
    check_hash = hashlib.pbkdf2_hmac('sha256', provided_password.encode('utf-8'), salt.encode('utf-8'), 100000)
    return pwdhash == check_hash.hex()

def get_session_token():
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
    return os.path.exists(PASSWORD_FILE)

def check_auth(handler):
    if not is_password_set():
        return True
    cookie = SimpleCookie()
    if 'Cookie' in handler.headers:
        cookie.load(handler.headers['Cookie'])
    if 'session' in cookie:
        session_token = get_session_token()
        return cookie['session'].value == session_token
    return False

def get_configured_clients():
    """Parse wg0.conf to get all configured clients"""
    clients = []
    try:
        with open('/etc/wireguard/wg0.conf', 'r') as f:
            content = f.read()
        
        # Find all [Peer] sections
        peer_sections = re.split(r'\[Peer\]', content)[1:]  # Skip [Interface] section
        
        for section in peer_sections:
            lines = section.strip().split('\n')
            client = {}
            
            for line in lines:
                line = line.strip()
                if line.startswith('#'):
                    # Client name is in comment
                    client['name'] = line.replace('#', '').strip()
                elif line.startswith('PublicKey'):
                    client['public_key'] = line.split('=')[1].strip()
                elif line.startswith('AllowedIPs'):
                    client['allowed_ips'] = line.split('=')[1].strip()
            
            if 'public_key' in client:
                clients.append(client)
    except Exception as e:
        print(f"Error reading clients: {e}")
    
    return clients

def get_active_connections():
    """Get active WireGuard connections with handshake times"""
    connections = {}
    try:
        output = subprocess.check_output(['wg', 'show', 'wg0'], stderr=subprocess.STDOUT).decode()
        
        # Parse wg show output
        current_peer = None
        for line in output.split('\n'):
            line = line.strip()
            if line.startswith('peer:'):
                current_peer = line.split(':')[1].strip().rstrip('=')
                connections[current_peer] = {}
            elif current_peer and line.startswith('endpoint:'):
                connections[current_peer]['endpoint'] = line.split(':')[1].strip()
            elif current_peer and line.startswith('allowed ips:'):
                connections[current_peer]['allowed_ips'] = line.split(':')[1].strip()
            elif current_peer and line.startswith('latest handshake:'):
                handshake = line.split(':', 1)[1].strip()
                connections[current_peer]['handshake'] = handshake
            elif current_peer and line.startswith('transfer:'):
                transfer = line.split(':', 1)[1].strip()
                connections[current_peer]['transfer'] = transfer
    except Exception as e:
        print(f"Error getting connections: {e}")
    
    return connections

class WireGuardHandler(BaseHTTPRequestHandler):
    
    def do_GET(self):
        if not is_password_set() and self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(self.get_setup_html().encode())
            return
        
        if self.path == '/login':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(self.get_login_html().encode())
            return
        
        if not check_auth(self):
            self.send_response(302)
            self.send_header('Location', '/login')
            self.end_headers()
            return
        
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
        
        elif self.path == '/api/clients':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            configured = get_configured_clients()
            active = get_active_connections()
            
            # Merge configured clients with active connections
            for client in configured:
                pub_key = client.get('public_key', '')
                if pub_key in active and 'handshake' in active[pub_key]:
                    # Client is connected (has recent handshake)
                    client['active'] = True
                    client['handshake'] = active[pub_key]['handshake']
                    client['endpoint'] = active[pub_key].get('endpoint', 'Unknown')
                    client['transfer'] = active[pub_key].get('transfer', 'No data')
                else:
                    # Client is offline (no handshake data)
                    client['active'] = False
                    client['handshake'] = 'Never connected'
            
            self.wfile.write(json.dumps({'clients': configured}).encode())
        
        elif self.path == '/api/diagnostics':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            diagnostics = self.run_diagnostics()
            self.wfile.write(json.dumps(diagnostics).encode())
        
        elif self.path.startswith('/download/'):
            client_name = self.path.split('/')[-1].replace('.conf', '')
            self.download_config(client_name)
        
        elif self.path.startswith('/api/qr/'):
            client_name = self.path.split('/')[-1]
            try:
                config_file = f'/etc/wireguard/client_{client_name}.conf'
                with open(config_file, 'r') as f:
                    config_content = f.read()
                qr_svg = subprocess.check_output(['qrencode', '-t', 'svg', '-o', '-'], input=config_content.encode()).decode()
                self.send_response(200)
                self.send_header('Content-type', 'image/svg+xml')
                self.end_headers()
                self.wfile.write(qr_svg.encode())
            except FileNotFoundError:
                self.send_response(404)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'error': 'Client not found'}).encode())
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'error': str(e)}).encode())
        
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
            
            hashed = hash_password(password)
            with open(PASSWORD_FILE, 'w') as f:
                f.write(hashed)
            os.chmod(PASSWORD_FILE, 0o600)
            
            session_token = get_session_token()
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Set-Cookie', f'session={session_token}; Path=/; HttpOnly; Max-Age=86400')
            self.end_headers()
            self.wfile.write(json.dumps({'success': True}).encode())
            return
        
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
        
        elif self.path == '/api/delete-client':
            client_public_key = data.get('public_key', [''])[0]
            
            if client_public_key:
                result = self.delete_client(client_public_key)
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
            check_interface = subprocess.run(['ip', 'link', 'show', 'wg0'],
                                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
            
            if check_interface.returncode != 0:
                return {'status': 'stopped', 'output': 'Interface wg0 not found'}
            
            service_check = subprocess.run(['systemctl', 'is-active', 'wg-quick@wg0'],
                                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
            
            output = subprocess.check_output(['wg', 'show'], stderr=subprocess.STDOUT).decode()
            
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
        
        try:
            ip_forward = subprocess.check_output(['sysctl', 'net.ipv4.ip_forward']).decode().strip()
            diagnostics['ip_forward'] = 'enabled' if '= 1' in ip_forward else 'disabled'
        except:
            diagnostics['ip_forward'] = 'error'
        
        try:
            nat_rules = subprocess.check_output(['iptables', '-t', 'nat', '-L', 'POSTROUTING', '-n']).decode()
            diagnostics['nat_rules'] = 'configured' if 'MASQUERADE' in nat_rules else 'missing'
        except:
            diagnostics['nat_rules'] = 'error'
        
        try:
            wg_check = subprocess.run(['ip', 'link', 'show', 'wg0'],
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
            if wg_check.returncode == 0:
                ip_check = subprocess.run(['ip', 'addr', 'show', 'wg0'],
                                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
                diagnostics['wg_interface'] = 'up' if '10.8.0.1' in ip_check.stdout else 'down'
            else:
                diagnostics['wg_interface'] = 'down'
        except:
            diagnostics['wg_interface'] = 'down'
        
        try:
            firewall_rules = subprocess.check_output(['firewall-cmd', '--list-ports']).decode()
            diagnostics['firewall'] = 'configured' if '51820/udp' in firewall_rules else 'not configured'
        except:
            diagnostics['firewall'] = 'not running'
        
        return diagnostics
    
    def add_client(self, client_name):
        try:
            config_file = '/etc/wireguard/wg0.conf'
            with open(config_file, 'r') as f:
                content = f.read()
            
            import re
            ips = re.findall(r'AllowedIPs = 10\.8\.0\.(\d+)', content)
            next_ip = max([int(ip) for ip in ips]) + 1 if ips else 2
            
            private_key = subprocess.check_output(['wg', 'genkey']).decode().strip()
            public_key = subprocess.check_output(['wg', 'pubkey'], input=private_key.encode()).decode().strip()
            preshared_key = subprocess.check_output(['wg', 'genpsk']).decode().strip()
            
            with open('/etc/wireguard/server_public.key', 'r') as f:
                server_public = f.read().strip()
            
            public_ip = subprocess.check_output(['curl', '-s', 'ifconfig.me']).decode().strip()
            
            peer_config = f"""
[Peer]
# {client_name}
PublicKey = {public_key}
PresharedKey = {preshared_key}
AllowedIPs = 10.8.0.{next_ip}/32
"""
            with open(config_file, 'a') as f:
                f.write(peer_config)
            
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
            
            subprocess.run(['systemctl', 'restart', 'wg-quick@wg0'])
            
            return {
                'success': True,
                'message': f'Client {client_name} added successfully',
                'download_url': f'/download/{client_name}.conf'
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def delete_client(self, public_key):
        try:
            config_file = '/etc/wireguard/wg0.conf'
            with open(config_file, 'r') as f:
                content = f.read()
            
            # Find and remove the peer section
            sections = re.split(r'(\[Peer\])', content)
            new_content = sections[0]  # Keep [Interface] section
            
            i = 1
            while i < len(sections):
                if sections[i] == '[Peer]':
                    peer_content = sections[i + 1] if i + 1 < len(sections) else ''
                    if f'PublicKey = {public_key}' not in peer_content:
                        # Keep this peer
                        new_content += sections[i] + peer_content
                    i += 2
                else:
                    i += 1
            
            with open(config_file, 'w') as f:
                f.write(new_content)
            
            subprocess.run(['systemctl', 'restart', 'wg-quick@wg0'])
            
            return {'success': True, 'message': 'Client deleted successfully'}
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
            subprocess.run(['sysctl', '-w', 'net.ipv4.ip_forward=1'], check=True)
            fixes.append('IP forwarding enabled')
            
            iface = subprocess.check_output(['ip', 'route']).decode()
            iface = iface.split('default via')[1].split()[2] if 'default via' in iface else 'ens3'
            
            subprocess.run(['iptables', '-t', 'nat', '-A', 'POSTROUTING', '-s', '10.8.0.0/24', '-o', iface, '-j', 'MASQUERADE'], check=False)
            fixes.append('NAT rules added')
            
            subprocess.run(['firewall-cmd', '--permanent', '--add-port=51820/udp'], check=False)
            subprocess.run(['firewall-cmd', '--permanent', '--zone=public', '--add-masquerade'], check=False)
            subprocess.run(['firewall-cmd', '--reload'], check=False)
            fixes.append('Firewall configured')
            
            subprocess.run(['systemctl', 'restart', 'wg-quick@wg0'], check=True)
            fixes.append('WireGuard restarted')
            
            return {'success': True, 'fixes': fixes}
        except Exception as e:
            return {'success': False, 'error': str(e), 'fixes': fixes}
    
    def get_setup_html(self):
        return '''<!DOCTYPE html><html><head><title>WireGuard Dashboard - Setup</title><meta name="viewport" content="width=device-width, initial-scale=1"><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}.setup-box{background:white;border-radius:10px;padding:40px;box-shadow:0 10px 40px rgba(0,0,0,0.2);max-width:400px;width:100%}h1{color:#333;margin-bottom:10px;font-size:24px}p{color:#666;margin-bottom:30px}.form-group{margin-bottom:20px}label{display:block;margin-bottom:5px;color:#333;font-weight:600}input{width:100%;padding:12px;border:2px solid #e5e7eb;border-radius:6px;font-size:14px}input:focus{outline:none;border-color:#667eea}button{width:100%;background:#667eea;color:white;border:none;padding:12px;border-radius:6px;font-size:16px;font-weight:600;cursor:pointer}button:hover{background:#5568d3}.alert{padding:12px;border-radius:6px;margin-bottom:20px}.alert-error{background:#fee2e2;color:#991b1b}.info-box{background:#f0f9ff;border-left:4px solid #667eea;padding:15px;margin-bottom:20px;border-radius:4px}.info-box ul{margin-left:20px;color:#334155}.info-box li{margin:5px 0}</style></head><body><div class="setup-box"><h1>WireGuard Dashboard</h1><p>Set a password to secure your dashboard</p><div class="info-box"><strong>Password Requirements:</strong><ul><li>At least 8 characters</li><li>Use a strong, unique password</li></ul></div><div id="message"></div><form id="setupForm"><div class="form-group"><label>Password</label><input type="password" id="password" required minlength="8"></div><div class="form-group"><label>Confirm Password</label><input type="password" id="confirm" required minlength="8"></div><button type="submit">Set Password</button></form></div><script>document.getElementById('setupForm').addEventListener('submit',function(e){e.preventDefault();const password=document.getElementById('password').value;const confirm=document.getElementById('confirm').value;const messageDiv=document.getElementById('message');if(password!==confirm){messageDiv.innerHTML='<div class="alert alert-error">Passwords do not match!</div>';return}if(password.length<8){messageDiv.innerHTML='<div class="alert alert-error">Password must be at least 8 characters!</div>';return}fetch('/api/setup',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:'password='+encodeURIComponent(password)+'&confirm='+encodeURIComponent(confirm)}).then(r=>r.json()).then(data=>{if(data.success){window.location.href='/'}else{messageDiv.innerHTML='<div class="alert alert-error">'+data.error+'</div>'}})});</script></body></html>'''
    
    def get_login_html(self):
        return '''<!DOCTYPE html><html><head><title>WireGuard Dashboard - Login</title><meta name="viewport" content="width=device-width, initial-scale=1"><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}.login-box{background:white;border-radius:10px;padding:40px;box-shadow:0 10px 40px rgba(0,0,0,0.2);max-width:400px;width:100%}h1{color:#333;margin-bottom:10px;font-size:24px}p{color:#666;margin-bottom:30px}.form-group{margin-bottom:20px}label{display:block;margin-bottom:5px;color:#333;font-weight:600}input{width:100%;padding:12px;border:2px solid #e5e7eb;border-radius:6px;font-size:14px}input:focus{outline:none;border-color:#667eea}button{width:100%;background:#667eea;color:white;border:none;padding:12px;border-radius:6px;font-size:16px;font-weight:600;cursor:pointer}button:hover{background:#5568d3}.alert{padding:12px;border-radius:6px;margin-bottom:20px}.alert-error{background:#fee2e2;color:#991b1b}</style></head><body><div class="login-box"><h1>WireGuard Dashboard</h1><p>Please enter your password</p><div id="message"></div><form id="loginForm"><div class="form-group"><label>Password</label><input type="password" id="password" required></div><button type="submit">Login</button></form></div><script>document.getElementById('loginForm').addEventListener('submit',function(e){e.preventDefault();const password=document.getElementById('password').value;fetch('/api/login',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:'password='+encodeURIComponent(password)}).then(r=>r.json()).then(data=>{if(data.success){window.location.href='/'}else{document.getElementById('message').innerHTML='<div class="alert alert-error">Invalid password!</div>'}})});</script></body></html>'''
    
    def get_dashboard_html(self):
        return '''<!DOCTYPE html><html><head><title>WireGuard Dashboard</title><meta name="viewport" content="width=device-width, initial-scale=1"><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);min-height:100vh;padding:20px}.container{max-width:1400px;margin:0 auto}.header{background:white;border-radius:10px;padding:30px;margin-bottom:20px;box-shadow:0 10px 40px rgba(0,0,0,0.1);display:flex;justify-content:space-between;align-items:center}.header h1{color:#333;margin-bottom:10px}.header p{color:#666}.logout-btn{background:#ef4444;color:white;border:none;padding:10px 20px;border-radius:6px;cursor:pointer;font-size:14px;font-weight:600;text-decoration:none}.logout-btn:hover{background:#dc2626}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:20px;margin-bottom:20px}.card{background:white;border-radius:10px;padding:25px;box-shadow:0 10px 40px rgba(0,0,0,0.1)}.card h2{color:#333;margin-bottom:15px;font-size:20px}.status-badge{display:inline-block;padding:5px 15px;border-radius:20px;font-size:14px;font-weight:600;margin:5px 0}.status-running{background:#10b981;color:white}.status-stopped{background:#ef4444;color:white}.status-enabled{background:#10b981;color:white}.status-disabled{background:#ef4444;color:white}.status-up{background:#10b981;color:white}.status-down{background:#f59e0b;color:white}.status-configured{background:#10b981;color:white}.status-missing{background:#f59e0b;color:white}.btn{background:#667eea;color:white;border:none;padding:10px 20px;border-radius:6px;cursor:pointer;font-size:14px;font-weight:600;transition:all 0.3s;margin:5px;display:inline-block}.btn:hover{background:#5568d3}.btn-success{background:#10b981}.btn-success:hover{background:#059669}.btn-warning{background:#f59e0b}.btn-warning:hover{background:#d97706}.btn-danger{background:#ef4444}.btn-danger:hover{background:#dc2626}.btn-small{padding:6px 12px;font-size:12px}.form-group{margin:15px 0}.form-group label{display:block;margin-bottom:5px;color:#333;font-weight:600}.form-group input{width:100%;padding:10px;border:2px solid #e5e7eb;border-radius:6px;font-size:14px}.form-group input:focus{outline:none;border-color:#667eea}.alert{padding:15px;border-radius:6px;margin:15px 0}.alert-success{background:#d1fae5;color:#065f46}.alert-error{background:#fee2e2;color:#991b1b}.alert-info{background:#dbeafe;color:#1e40af}.diagnostic-item{display:flex;justify-content:space-between;align-items:center;padding:10px 0;border-bottom:1px solid #e5e7eb}.diagnostic-item:last-child{border-bottom:none}.client-table{width:100%;border-collapse:collapse;margin-top:15px}.client-table th,.client-table td{padding:12px;text-align:left;border-bottom:1px solid #e5e7eb}.client-table th{background:#f9fafb;font-weight:600;color:#333}.client-table tr:hover{background:#f9fafb}.active-dot{display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:8px}.active-dot.online{background:#10b981}.active-dot.offline{background:#ef4444}.modal{display:none;position:fixed;z-index:1000;left:0;top:0;width:100%;height:100%;background:rgba(0,0,0,0.6);align-items:center;justify-content:center}.modal.show{display:flex}.modal-content{background:white;padding:30px;border-radius:10px;max-width:400px;box-shadow:0 20px 60px rgba(0,0,0,0.3);position:relative}.modal-content h3{margin-bottom:20px;color:#333;text-align:center}.close{position:absolute;right:15px;top:10px;font-size:28px;font-weight:bold;color:#999;cursor:pointer;background:none;border:none;padding:0}.close:hover{color:#333}.qr-container{text-align:center;padding:10px}.qr-container svg{max-width:100%;height:auto}</style></head><body><div class="container"><div class="header"><div><h1>WireGuard Dashboard</h1><p>Manage your WireGuard VPN clients</p></div><a href="/logout" class="logout-btn">Logout</a></div><div class="grid"><div class="card"><h2>Server Status</h2><div id="server-status">Loading...</div><button class="btn" onclick="refreshStatus()">Refresh</button></div><div class="card"><h2>Diagnostics</h2><div id="diagnostics">Loading...</div><button class="btn btn-warning" onclick="runAutoFix()">Auto-Fix</button></div></div><div class="card"><h2>Add New Client</h2><div class="form-group"><label>Client Name</label><input type="text" id="client-name" placeholder="e.g., phone, laptop, tablet"></div><button class="btn btn-success" onclick="addClient()">Add Client</button><div id="add-client-result"></div></div><div class="card"><h2>Configured Clients</h2><div id="clients-list">Loading...</div></div></div><div id="qrModal" class="modal" onclick="if(event.target===this)closeQR()"><div class="modal-content"><button class="close" onclick="closeQR()">&times;</button><h3 id="qrTitle">QR Code</h3><div class="qr-container" id="qrContainer">Loading...</div></div></div><script>function refreshStatus(){fetch('/api/status').then(r=>r.json()).then(data=>{const statusDiv=document.getElementById('server-status');const statusClass=data.status==='running'?'status-running':'status-stopped';let statusHtml=`<div class="status-badge ${statusClass}">${data.status.toUpperCase()}</div>`;if(data.service_state){statusHtml+=`<p style="margin-top:10px;font-size:13px;color:#666;">Service: ${data.service_state}</p>`}statusDiv.innerHTML=statusHtml});fetch('/api/diagnostics').then(r=>r.json()).then(data=>{const diagDiv=document.getElementById('diagnostics');diagDiv.innerHTML=`<div class="diagnostic-item"><span>IP Forwarding</span><span class="status-badge status-${data.ip_forward}">${data.ip_forward}</span></div><div class="diagnostic-item"><span>NAT Rules</span><span class="status-badge status-${data.nat_rules}">${data.nat_rules}</span></div><div class="diagnostic-item"><span>WireGuard Interface</span><span class="status-badge status-${data.wg_interface}">${data.wg_interface}</span></div><div class="diagnostic-item"><span>Firewall</span><span class="status-badge status-${data.firewall}">${data.firewall}</span></div>`});loadClients()}function loadClients(){fetch('/api/clients').then(r=>r.json()).then(data=>{const clientsDiv=document.getElementById('clients-list');if(data.clients.length===0){clientsDiv.innerHTML='<p style="color:#666;text-align:center;padding:20px;">No clients configured yet. Add one above!</p>';return}let html='<table class="client-table"><thead><tr><th>Status</th><th>Name</th><th>IP Address</th><th>Last Handshake</th><th>Transfer</th><th>Actions</th></tr></thead><tbody>';data.clients.forEach(client=>{const isActive=client.active;const statusDot=`<span class="active-dot ${isActive?'online':'offline'}"></span>`;const statusText=isActive?'Connected':'Offline';const handshake=client.handshake||'Never';const transfer=client.transfer||'-';const ip=client.allowed_ips||'Unknown';const name=client.name||'Unnamed';html+=`<tr><td>${statusDot}${statusText}</td><td><strong>${name}</strong></td><td>${ip}</td><td>${handshake}</td><td style="font-size:12px;color:#666">${transfer}</td><td><button class="btn btn-small" onclick="showQR('${name}')">QR</button> <a href="/download/${name}.conf" class="btn btn-small btn-success">Download</a><button class="btn btn-small btn-danger" onclick="deleteClient('${client.public_key}','${name}')">Delete</button></td></tr>`});html+='</tbody></table>';clientsDiv.innerHTML=html})}function addClient(){const clientName=document.getElementById('client-name').value;if(!clientName){alert('Please enter a client name');return}fetch('/api/add-client',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:'client_name='+encodeURIComponent(clientName)}).then(r=>r.json()).then(data=>{const resultDiv=document.getElementById('add-client-result');if(data.success){resultDiv.innerHTML=`<div class="alert alert-success">${data.message}<br><a href="${data.download_url}" class="btn btn-success" style="margin-top:10px;">Download ${clientName}.conf</a></div>`;document.getElementById('client-name').value='';loadClients()}else{resultDiv.innerHTML=`<div class="alert alert-error">Error: ${data.error}</div>`}})}function deleteClient(publicKey,name){if(!confirm(`Delete client "${name}"?\\n\\nThis will:\\n- Remove from server\\n- Disconnect if currently active\\n- Cannot be undone!`))return;fetch('/api/delete-client',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:'public_key='+encodeURIComponent(publicKey)}).then(r=>r.json()).then(data=>{if(data.success){alert('Client deleted successfully!');loadClients()}else{alert('Error deleting client: '+data.error)}})}function runAutoFix(){if(!confirm('Run auto-fix? This will restart WireGuard.'))return;fetch('/api/auto-fix',{method:'POST'}).then(r=>r.json()).then(data=>{if(data.success){alert('Auto-fix completed!\\n\\n'+data.fixes.join('\\n'))}else{alert('Auto-fix failed: '+data.error)}setTimeout(refreshStatus,2000)})}function showQR(n){document.getElementById('qrTitle').textContent='QR Code - '+n;document.getElementById('qrContainer').innerHTML='Loading...';document.getElementById('qrModal').classList.add('show');fetch('/api/qr/'+n).then(r=>r.text()).then(svg=>{document.getElementById('qrContainer').innerHTML=svg}).catch(()=>{document.getElementById('qrContainer').innerHTML='<p style="color:#ef4444">Error loading QR code</p>'})}function closeQR(){document.getElementById('qrModal').classList.remove('show')}refreshStatus();setInterval(refreshStatus,30000);setInterval(loadClients,10000);</script></body></html>'''

def run_server(port=8080):
    server = HTTPServer(('0.0.0.0', port), WireGuardHandler)
    print(f'WireGuard Dashboard running on http://0.0.0.0:{port}')
    server.serve_forever()

if __name__ == '__main__':
    run_server()
PYEOF

# Restart dashboard
sudo systemctl restart wireguard-dashboard

# Check status
sleep 2
sudo systemctl status wireguard-dashboard --no-pager

echo ""
echo "============================================="
echo "Dashboard Upgraded!"
echo "============================================="
echo ""
echo "New features:"
echo "  ✅ Lists all configured clients"
echo "  ✅ Shows active vs offline clients"
echo "  ✅ Displays last handshake time"
echo "  ✅ Download any client config"
echo "  ✅ Delete clients with confirmation"
echo "  ✅ Auto-refresh every 30 seconds"
echo ""
echo "Refresh your browser to see the new dashboard!"
echo ""

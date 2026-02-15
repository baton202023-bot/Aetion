# Project Prometheus

**Project Prometheus** is a lightweight, asynchronous Command and Control (C2) framework designed for internal systems administration and automated task orchestration. It consists of a **Python-based Master Node (Server)** and a **VBScript-based Implant (Client)** that communicates over HTTP.

---

## System Architecture

The framework utilizes a polling mechanism where the client checks in periodically to receive instructions, ensuring compatibility with environments where persistent reverse shells might be unstable.

### Core Components

* **Production Server (`server.py`):** The central hub for operator interaction. It manages multiple sessions, queues commands, hosts PowerShell scripts, and organizes exfiltrated data.
* **Production Client (`client.vbs`):** A stealthy, native Windows script that executes commands, manages local file system navigation, and performs in-memory PowerShell execution.

---

## Key Features

* **Case-Insensitive Script Hosting:** The server serves payloads from the `/Scripts/` directory regardless of URL casing (e.g., `/scripts/test.ps1` matches `/Scripts/test.ps1`).
* **In-Memory Execution:** The `INVOKE` command pulls PowerShell scripts directly into memory, bypassing the need to write `.ps1` files to the target's disk.
* **Stream Merging (`*>&1`):** Captures all PowerShell output streams, including `Write-Host` and error messages, providing full visibility into script execution.
* **Session Persistence:** Includes command history (up-arrow) and automatic directory tracking via custom HTTP headers (`X-CWD`).
* **Automated Looting:** Files retrieved via the `DOWNLOAD` command are automatically organized in the `Loot/[ClientID]/` directory.

---

## Command Reference

### Session Management

| Command | Description |
| --- | --- |
| **SESSIONS** | List all active implants currently checking in. |
| **USE [ID]** | Select a specific implant to interact with. |
| **BACK** | Return to the global broadcast menu. |
| **EXIT** | Terminate the Master Node. |

### File System & Execution

| Command | Description |
| --- | --- |
| **LS / DIR** | List files and folders in the current remote directory. |
| **CD [path]** | Change the working directory on the target. |
| **CAT [file]** | Read the contents of a text file remotely. |
| **DOWNLOAD [file]** | Securely exfiltrate a file to the local `Loot/` folder. |
| **INVOKE [script]** | Execute a script from the `Scripts/` folder in memory via PowerShell. |
| **SHELL [cmd]** | Execute a native Windows command prompt command. |

---

## Setup & Deployment

### 1. Server Configuration

Edit the `CONFIGURATION` section in `server.py`:

```python
IP_ADDR = "192.168.0.20" # Your local IP
PORT = 8080              # Desired Port

```

Place any PowerShell scripts you wish to deploy into the `/Scripts` folder.

### 2. Client Configuration

Edit the `CONFIGURATION` section in `client.vbs` to match your server:

```vbscript
strServer = "http://192.168.0.20:8080"

```

### 3. Running the Framework

1. **Start the Server:**
`python server.py`
2. **Execute the Client:**
Double-click `client.vbs` or run via CLI: `wscript.exe client.vbs`.

---

> [!IMPORTANT]
> **Project Prometheus** is intended for authorized administrative use and security testing only. Ensure you have explicit permission before deploying the client on any system.

**Would you like me to generate a specific PowerShell script template to place in your `Scripts/` folder for testing the `INVOKE` command?**
### SHOUTOUT
Huge shoutout to https://github.com/bitsadmin/revbshell/ for bringing the idea and concept of it.

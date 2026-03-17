
# Telepresence Quick Start Guide (Windows)

This guide covers installing Telepresence, connecting to your Kubernetes cluster, intercepting services, and troubleshooting common issues on Windows.

---

## 1. Install Telepresence

```powershell
# Download the latest release
$url = "https://app.getambassador.io/download/tel2oss/releases/download/v2.21.1/telepresence-windows-amd64.zip"
$output = "$env:TEMP\telepresence.zip"
Invoke-WebRequest -Uri $url -OutFile $output

# Extract to Program Files
Expand-Archive -Path $output -DestinationPath "C:\Program Files\Telepresence" -Force

# Add to PATH (run as Administrator)
$path = [Environment]::GetEnvironmentVariable("Path", "Machine")
$newPath = "C:\Program Files\Telepresence;" + $path
[Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")

# Refresh current session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Verify installation
telepresence version
```

---

## 2. Cluster Setup & Connect

```powershell
# Ensure kubectl works
kubectl get nodes

# Install Telepresence Traffic Manager in your cluster
telepresence helm install

# Connect to your cluster
telepresence connect

# Verify daemons are running
telepresence version

# List available services
telepresence list

# Check status
telepresence status
```

---

## 3. Intercept a Service

```powershell
# Basic intercept - redirect ALL traffic
telepresence intercept <deployment-name> --port <local-port>:<remote-port>

# Example: Intercept deployment "my-api" running on port 80, redirect to local port 8080
telepresence intercept my-api --port 8080:80
```

---

## 4. Run Your Local Application

Your local app on the specified port will now receive traffic from the cluster.

```powershell
python app.py
# or
node server.js
# or
dotnet run
```

---

## 5. Advanced: Selective Intercept (Filter Traffic)

Intercept only traffic matching specific HTTP headers:

```powershell
telepresence intercept my-api --port 8080:80 --http-header=x-debug-user=zakir
```

---

## 6. Common Telepresence Commands

```powershell
# List active intercepts
telepresence list

# Stop an intercept but stay connected
telepresence leave <deployment-name>

# Disconnect from cluster
telepresence quit

# Gather logs for troubleshooting
telepresence gather-logs
```

---

## 7. Example Workflow

```powershell
# 1. Connect
telepresence connect

# 2. See what's available
telepresence list

# 3. Intercept your service
telepresence intercept my-backend-api --port 3000:8080

# 4. Run your local code (in a new terminal or IDE)
npm start  # or python app.py, dotnet run, etc.

# 5. Test - traffic from cluster now hits your local app!
# Make requests to your service through the cluster

# 6. When done, clean up
telepresence leave my-backend-api
telepresence quit
```

---

## 8. Troubleshooting

### "traffic-manager not found"
```powershell
# Install it first
telepresence helm install
```

### "connection failed"
```powershell
# Check kubectl works
kubectl get pods -n ambassador

# Reinstall traffic manager
telepresence helm uninstall
telepresence helm install
```

### "permission denied"
```powershell
# Run PowerShell as Administrator
telepresence connect
```

### "port already in use"
```powershell
# Check what's using the port
netstat -ano | findstr :<port>

# Use a different local port
telepresence intercept my-api --port 8081:80
```

---

## 9. Other Tools Similar to Telepresence

| Tool          | Type         | License    | Requires Root | Traffic Mode   | File Sync      | Env Vars | Best For                    |
|---------------|-------------|------------|---------------|---------------|---------------|----------|-----------------------------|
| mirrord       | Proxy        | MIT        | No            | Mirror/Steal  | Yes           | Yes      | Process-level interception   |
| Telepresence  | Proxy        | Apache 2.0 | Yes           | Intercept     | Volume mount   | Yes      | Mature, full-featured        |
| Gefyra        | Proxy        | Apache 2.0 | No            | Replace       | No            | No       | Docker-first, simplicity     |
| Skaffold      | Build/Deploy | Apache 2.0 | No            | N/A           | Hot reload     | N/A      | Automation, CI/CD            |
| Tilt          | Build/Deploy | Apache 2.0 | No            | N/A           | Live updates   | N/A      | Multi-service visibility     |
| Okteto        | Remote Dev   | Apache 2.0 | No            | N/A           | Bidirectional  | Yes      | Cloud-native development     |
| DevSpace      | Hybrid       | Apache 2.0 | No            | N/A           | Yes           | Yes      | Customization                |
| Garden        | Orchestration| MPL 2.0    | No            | N/A           | Hot reload     | Yes      | Complex dependencies         |

Recommendation by Use Case

## Recommendations by Use Case

### For mirrord-like experience (process-level debugging):
- **mirrord** – Best overall for this specific use case
- **Telepresence** – More mature, CNCF project
- **Gefyra** – Simpler, Docker-based

### For fast inner-loop development:
- **Tilt** – Best UI and developer experience
- **Skaffold** – Google-backed, mature
- **DevSpace** – Lightweight alternative

### For remote development:
- **Okteto** – Purpose-built for this
- **Telepresence** – Good remote cluster support

### For complex microservices:
- **Tilt** – Best visibility
- **Garden** – Dependency management
- **Skaffold** – Flexible automation

### For teams new to Kubernetes:
- **Skaffold** – Easiest to start
- **DevSpace** – Good documentation
- **mirrord** – Minimal setup

---

## My Recommendation

**If you're specifically looking for a mirrord alternative with similar capabilities:**
- **Telepresence** – Most feature-complete, but requires root
- **Gefyra** – Simpler and more stable, but Docker-only
- **DevSpace** – Good middle ground with file sync

**If you're open to different approaches that might work better:**
- **Tilt** – For best developer experience with multiple services
- **Skaffold** – For production-parity and CI/CD integration
- **Okteto** – For eliminating local Kubernetes entirely

---

## mirrord OSS (Open Source) – FREE

- mirrord is free and open source under MIT License ([GitHub](https://github.com/metalbear-co/mirrord))
- Full functionality for individual developers
- No restrictions on core features
- Free forever

---

## Tool Summaries

### 1. Telepresence ⭐⭐⭐⭐⭐
- **License:** Apache 2.0 (Open Source)
- **Status:** CNCF Sandbox Project
- **GitHub:** https://github.com/telepresenceio/telepresence

**How it differs from mirrord:**
- Creates a VPN-like tunnel to the cluster, while mirrord works on the process level by injecting a shared library
- Requires root access unless installed via package manager, while mirrord doesn't require root
- Relies on creating a VPN which can lead to compatibility issues with service meshes or corporate VPNs

**Pros:**
- Most mature tool (CNCF project)
- Strong community support
- Full-featured
- Works on Windows natively

**Cons:**
- Setup can be finicky with different network configurations
- Requires VPN-style connection
- More resource-intensive

---

### 2. Gefyra ⭐⭐⭐⭐
- **License:** Apache 2.0 (Open Source)
- **GitHub:** https://github.com/gefyrahq/gefyra
- **Website:** https://gefyra.dev

**How it works:**
- Connects a locally running Docker container to the remote cluster's network using Wireguard VPN
- Users who have switched from Telepresence often praise Gefyra for its stability and less intrusive nature

**Pros:**
- Simpler and more stable than Telepresence
- No root privileges required (if Docker access available)
- Better for corporate firewalls (UDP-based)
- Born from frustration with Telepresence reliability

**Cons:**
- Requires Docker (development must happen in containers)
- Less flexible than alternatives
- Smaller community

**Best for:** Teams using Docker-based workflows wanting simplicity

---

### 3. Skaffold ⭐⭐⭐⭐⭐
- **License:** Apache 2.0 (Open Source by Google)
- **GitHub:** https://github.com/GoogleContainerTools/skaffold
- **Website:** https://skaffold.dev

**Different approach:** Build/deploy automation rather than proxying

**Pros:**
- Backed by Google, very mature
- Excellent CI/CD integration
- Flexible and pluggable
- Production-parity environments

**Cons:**
- Slower feedback loop (must rebuild containers)
- Different philosophy than proxy-based tools

**Best for:** Teams wanting automated workflows and CI/CD integration

---

### 4. Tilt ⭐⭐⭐⭐⭐
- **License:** Apache 2.0 (Open Source)
- **GitHub:** https://github.com/tilt-dev/tilt
- **Website:** https://tilt.dev

**Features:**
- Visual web UI for managing services
- Live updates to running containers
- File sync without full rebuilds
- Excellent for multi-service architectures

**Best for:** Teams with complex microservices needing visibility

---

### 5. DevSpace ⭐⭐⭐⭐
- **License:** Apache 2.0 (Open Source)
- **GitHub:** https://github.com/loft-sh/devspace
- **Website:** https://devspace.sh

**Features:**
- Real-time file synchronization
- Port forwarding
- Development containers
- Works with existing tools

**Best for:** Teams wanting customization and lightweight tools

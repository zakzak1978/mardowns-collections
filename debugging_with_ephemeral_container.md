# Debugging with Ephemeral Containers

### One-Time: Enable Process Namespace Sharing

```yaml
spec:
  template:
    spec:
      shareProcessNamespace: true   # ← ADD THIS
      containers:
      - name: your-signalr-app
        image: your-registry/your-app:latest
        # ... your existing config
```

### Apply the deployment

```bash
kubectl apply -f your-deployment.yaml
```

### Find the Pod

```bash
# Replace with your label selector
POD=$(kubectl get pod -l app=my-signalr-app -o jsonpath='{.items[0].metadata.name}')
echo "Pod: $POD"

# Get app container's runAsUser (e.g., 1001 or www-data → resolves to APP_UID)
# This helps if vsdbg needs APP_UID checks (rare, but for completeness)
APP_UID=$(kubectl exec "$POD" -n feature-readonlyroot -c sdp-daas-api -- \
  sh -c 'ps -p 1 -o uid= 2>/dev/null | xargs || echo "1000"')

echo "App UID: $APP_UID"
App UID: 101
```

### Launch Ephemeral Debug Container (Copy Pod)

```bash
# This creates a *copy* of the pod called $POD-debug
kubectl debug $POD -n feature-readonlyroot \
  --image=mcr.microsoft.com/dotnet/sdk:8.0 \
  --share-processes \
  --copy-to=debug-pod \
  --profile=general \
  -it -- bash
```

> You now have a shell inside the debug container, sharing PIDs with the original app.

### In case apps are running as non-root user, launch Ephemeral Debug Container (As Root) as below
```bash
# Creates a root-enabled copy pod
kubectl debug $POD -n feature-readonlyroot \
  --image=mcr.microsoft.com/dotnet/sdk:8.0 \
  --share-processes \
  --copy-to=debug-pod \
  --profile=general \
  -it -- bash \
  --overrides='{"spec": {"securityContext": {"runAsUser": 0}}}'  # Explicit root (UID 0)
```
> You're now in a root shell inside the ephemeral container (named debugger-*), sharing PIDs with your non-root app.

```bash
kubectl delete pod debug-pod -n feature-readonlyroot --grace-period=0 --force
```
### Inside the Debug Shell: Install vsdbg & Attach (Root Handles Non-Root)
Run these in the ephemeral container shell (as root):

```bash
# 1. Install tools (root can do this)
apt-get update && apt-get install -y curl unzip procps

# 2. Install vsdbg to a root-owned path
curl -sSL https://aka.ms/getvsdbgsh | bash /dev/stdin -v latest -l /vsdbg

# 3. Find your .NET process (non-root, but visible)
ps aux | grep '[d]otnet'  # Shows app PID, e.g., www-data 42 ... dotnet YourApp.dll
PID=$(ps aux | grep '[d]otnet' | awk '{print $2}')  # Auto-grab PID
echo "Attaching to PID: $PID"

# 4. Attach vsdbg as root (listens on 5678; attaches to non-root PID)
cd /vsdbg && ./vsdbg --interpreter=vscode --attach $PID
```

- Why root works: vsdbg runs elevated in the ephemeral container, ptracing your non-root app PID. No permission error.
- Keep shell open — sustains vsdbg.
If ps fails (rare), fallback: kubectl exec $POD -- ps aux | grep dotnet in another terminal.

> Keep this terminal open — vsdbg is now waiting for VS Code.

### Port-Forward Debug Port (New Terminal)

```bash
kubectl port-forward $POD-debug 5678:5678 &
PF_PID=$!
echo "Port-forward PID: $PF_PID"
```

> This forwards localhost:5678 → vsdbg inside the debug pod.

### VS Code: launch.json

Create `.vscode/launch.json` in your local project:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Attach to SignalR Pod (Ephemeral)",
      "type": "coreclr",
      "request": "attach",
      "processId": "${command:pickProcess}",
      "connect": {
        "host": "localhost",
        "port": 5678
      },
      "sourceFileMap": {
        "/app": "${workspaceFolder}",
        "/src": "${workspaceFolder}"
      },
      "justMyCode": false
    }
  ]
}
```

> Adjust `/app` or `/src` to match where your code is mounted in the container.

### Start Debugging

Press F5 in VS Code.  
Select "Attach to SignalR Pod (Ephemeral)".  
VS Code connects → shows list of processes → pick the dotnet process.  
Breakpoints turn solid → you're in!

### Set Breakpoints in SignalR Code

```csharp
// sample code
public class ChatHub : Hub
{
    public override Task OnConnectedAsync()
    {
        // ← Break here to see connection context
        var connectionId = Context.ConnectionId;
        return base.OnConnectedAsync();
    }

    public override Task OnDisconnectedAsync(Exception exception)
    {
        // ← Break here to see WHY it fails
        var error = exception?.Message;
        return base.OnDisconnectedAsync(exception);
    }
}
```

Trigger a client connection → hit the breakpoint → inspect:

- exception → is it WebSocketClosed, timeout, auth?
- Context.Items, Context.User
- Call stack → see if middleware aborted

### Troubleshooting (Non-Root)

| Issue                           | Fix                                                                 |
|--------------------------------|---------------------------------------------------------------------|
| `Insufficient privileges`      | Ephemeral must run as root (`runAsUser: 0`)                         |
| `PID not visible`              | `shareProcessNamespace: true` missing                               |
| `ptrace: Operation not permitted` | Run: `echo 0 > /proc/sys/kernel/yama/ptrace_scope` (if allowed)  |
| `Breakpoints not hit`          | Rebuild with `<DebugType>portable</DebugType>` and include PDBs     |
| `Source not found`             | Fix `sourceFileMap` in `launch.json`                                |

### Clean Up

```bash
# 1. Stop port-forward (Ctrl+C or kill)
# 2. Delete debug pod
kubectl delete pod $POD-debug --grace-period=0 --force
```

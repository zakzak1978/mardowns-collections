# Kubernetes Debugging Guide with Debug-Pod

This document provides a comprehensive guide for troubleshooting Kubernetes pods using debug pods, focusing on networking and other common issues. It includes commands for use within ephemeral containers, copied debug pods, or node-level debugging.

## Introduction to Debugging Pods

In Kubernetes, a "debug-pod" refers to using ephemeral debug containers via `kubectl debug` to troubleshoot issues interactively without altering the original pod. Ephemeral containers are ideal for pods lacking debugging tools or those crashing. You can also create a copied debug pod or debug directly on a node.

**Prerequisites**:
- `kubectl` installed and cluster access.
- Common debug images: `busybox` (basic tools), `ubuntu` (more utilities), `nicolaka/netshoot` (network-focused tools like `tcpdump`, `traceroute`).

## Starting a Debug Session

Use `kubectl debug` to attach an ephemeral container or create a debug pod copy. Below are the key commands:

### Attach Ephemeral Container
```
kubectl debug <pod-name> -it --image=busybox:1.28 --target=<container-name>
```
- `--image`: Specifies the debug image.
- `--target`: Targets a specific container if process namespaces aren't shared.
- `-it`: Enables interactive mode with TTY.

### Create Copied Debug Pod
```
kubectl debug <pod-name> -it --copy-to=<debug-pod-name> --image=ubuntu --share-processes
```
- `--copy-to`: Names the new debug pod.
- `--share-processes`: Shares process namespaces.
- `--set-image=*=<new-image>`: Changes all container images (e.g., to add tools).
- `--container=<container-name>`: Targets a specific container.

### Debug on Node
```
kubectl debug node/<node-name> -it --image=ubuntu
```
- Mounts node's filesystem at `/host`.
- Runs in host namespaces (IPC, Network, PID).

### Apply Security Profiles
- `--profile=netadmin`: For network admin capabilities (e.g., `tcpdump`).
- `--profile=sysadmin`: For full system admin access.
- Example:
  ```
  kubectl debug <pod-name> -it --image=busybox --profile=netadmin
  ```

Once inside the debug container, you'll get a shell prompt to run troubleshooting commands.

## Networking Troubleshooting

Networking issues often involve pod-to-pod connectivity, DNS resolution, service access, or CNI plugin problems (e.g., Calico, Flannel). Start by checking basics outside the pod:

```
kubectl get nodes
kubectl get pods -o wide  # View pod IPs
kubectl get services
kubectl describe service <service-name>
```

Inside the debug container, use these commands:

### Basic Connectivity
- Ping a pod or external host:
  ```
  ping <pod-ip>  # Test pod-to-pod
  ping 8.8.8.8   # Test external connectivity
  ```
- Curl a service or endpoint:
  ```
  curl <service-ip>:<port>  # Test service access
  curl -v <pod-ip>:<port>   # Verbose mode for headers/errors
  ```
- Netcat (nc) for port testing:
  ```
  nc -zv <pod-ip> <port>  # Check if port is open
  nc -l -p <port>         # Listen on a port (test incoming)
  ```

### DNS Resolution
- Dig or nslookup (install `bind-tools` in Alpine-based images with `apk add bind-tools`):
  ```
  dig <service-name>.<namespace>.svc.cluster.local
  nslookup <service-name>
  ```
- Check DNS configuration:
  ```
  cat /etc/resolv.conf
  ```

### Advanced Network Diagnostics
- Traceroute to trace paths:
  ```
  traceroute <pod-ip>  # Or mtr for ongoing monitoring
  ```
- Tcpdump for packet capture (requires netadmin or netshoot image):
  ```
  tcpdump -i eth0 -nn host <pod-ip>  # Capture traffic to/from a host
  tcpdump -i any port 80 -w capture.pcap  # Save to file
  ```
- Iptables or ip rules for routing/firewall:
  ```
  iptables -L -n -v  # List rules
  ip route show      # Show routing table
  ip addr show       # Show interfaces and IPs
  ```
- Arp or neighbor discovery:
  ```
  arp -a  # ARP table
  ```
- Socket stats:
  ```
  ss -tuln  # Listening sockets
  netstat -anp
  ```

### Common Networking Scenarios
- **Pod-to-service issues**: Curl the ClusterIP; check endpoints with `kubectl get ep <service-name>`.
- **Node-to-pod**: From node debug, `curl --interface <interface> <pod-ip>`.
- **Network policy blocks**: `kubectl describe networkpolicy`.
- **CNI logs**: On node, `journalctl -u kubelet` or check CNI plugin pods.
- **Use netshoot pod**: Deploy `nicolaka/netshoot` and exec into it for advanced tools.

## Other Troubleshooting

For non-networking issues like crashes, resource usage, or configuration errors:

### Pod Status and Events
Outside the pod:
```
kubectl describe pod <pod-name>  # Events, conditions
kubectl logs <pod-name> -c <container>  # Container logs
kubectl get events --field-selector involvedObject.name=<pod-name>
```

### Inside Debug Container
- Processes and resource usage:
  ```
  ps aux  # List processes (if shared namespaces)
  top     # CPU/memory usage
  free -h # Memory stats
  df -h   # Disk usage
  ```
- File system inspection:
  ```
  ls -la /path/to/dir
  cat /path/to/file  # e.g., config files
  find / -name <file>  # Search files
  ```
- Environment variables:
  ```
  env  # List all
  echo $VAR_NAME
  ```
- Application-specific:
  ```
  strace -p <pid>  # Trace system calls (if strace installed)
  gdb -p <pid>     # Attach debugger (if gdb available)
  ```
- Crash debugging:
  - Check previous logs for CrashLoopBackOff:
    ```
    kubectl logs <pod-name> --previous
    ```
  - Core dumps (if enabled):
    ```
    ls /core
    ulimit -c unlimited
    ```
- Volume mounts: Navigate to mounted paths (e.g., `/host` in node debug).
- Security contexts: Use `--profile=baseline` for restricted access.

### Common Scenarios
- **Pending pods**: Check scheduling with `kubectl get pods -o yaml | grep nodeName`; debug affinity/taints.
- **Error status**: Inspect pod spec with `kubectl get pod <pod-name> -o yaml`.
- **Resource limits**: Monitor with `kubectl top pod`.

## Additional Tips
- For complex issues, use `kubectl cluster-info dump` or monitoring tools (e.g., Prometheus).
- If using `netshoot`, deploy a pod:
  ```
  kubectl run netshoot --image=nicolaka/netshoot --rm -it -- /bin/sh
  ```
- Provide pod YAML or error messages for targeted help.
- Ensure debug image compatibility (e.g., `busybox` for lightweight, `ubuntu` for more tools).

This guide is a reference for troubleshooting Kubernetes pods. Save and adapt as needed for your cluster environment.

# Installing Debugging Tools in an Ubuntu Debug Pod

When using an `ubuntu` image (e.g., `ubuntu:latest` or `ubuntu:20.04`) for a Kubernetes debug pod, the base image is minimal and lacks many debugging tools. This guide lists essential tools for networking and general troubleshooting, along with commands to install them. It assumes you’re inside a debug container started with `kubectl debug <pod-name> -it --image=ubuntu` or a similar command.

## Prerequisites
- You’re in an interactive shell inside the Ubuntu debug container.
- The container has internet access to download packages (verify with `ping 8.8.8.8`).
- You have sufficient permissions (e.g., `--profile=sysadmin` for `kubectl debug` if root operations are needed).

## Initial Setup
The default Ubuntu image may not have `apt` fully configured. Run the following to update the package index:

```bash
apt update
```

If `apt update` fails due to missing dependencies or repositories, ensure internet connectivity or check `/etc/apt/sources.list`. A minimal `/etc/apt/sources.list` for Ubuntu 20.04 might look like:

```bash
deb http://archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ focal-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse
```

Edit it if needed (use `vi` or `nano` if installed, or install `nano` later).

## Essential Tools and Installation Commands

Below are tools commonly used for networking and general troubleshooting, grouped by purpose, with installation commands. Run these inside the debug container after `apt update`.

### Networking Tools
These tools help diagnose connectivity, DNS, routing, and packet issues.

1. **ping** (Test connectivity)
   - Package: `iputils-ping`
   - Install:
     ```bash
     apt install iputils-ping -y
     ```
   - Usage: `ping <pod-ip>` or `ping 8.8.8.8`

2. **curl** (Test HTTP/HTTPS endpoints)
   - Package: `curl`
   - Install:
     ```bash
     apt install curl -y
     ```
   - Usage: `curl <service-ip>:<port>` or `curl -v <pod-ip>:<port>`

3. **netcat (nc)** (Test ports, listen, or transfer data)
   - Package: `netcat-openbsd` or `netcat-traditional`
   - Install:
     ```bash
     apt install netcat-openbsd -y
     ```
   - Usage: `nc -zv <pod-ip> <port>` or `nc -l -p <port>`

4. **dig** and **nslookup** (DNS resolution)
   - Package: `dnsutils`
   - Install:
     ```bash
     apt install dnsutils -y
     ```
   - Usage: `dig <service-name>.<namespace>.svc.cluster.local` or `nslookup <service-name>`

5. **traceroute** (Trace network path)
   - Package: `traceroute`
   - Install:
     ```bash
     apt install traceroute -y
     ```
   - Usage: `traceroute <pod-ip>`

6. **tcpdump** (Packet capture; requires netadmin privileges)
   - Package: `tcpdump`
   - Install:
     ```bash
     apt install tcpdump -y
     ```
   - Usage: `tcpdump -i eth0 -nn host <pod-ip>` or `tcpdump -i any port 80 -w capture.pcap`
   - Note: Use `--profile=netadmin` with `kubectl debug` for permissions.

7. **iproute2** (Advanced networking: `ip`, `ss`)
   - Package: `iproute2`
   - Install:
     ```bash
     apt install iproute2 -y
     ```
   - Usage: `ip addr show`, `ip route show`, `ss -tuln`

8. **iptables** (Firewall and routing rules)
   - Package: `iptables`
   - Install:
     ```bash
     apt install iptables -y
     ```
   - Usage: `iptables -L -n -v`

9. **arp** (ARP table inspection)
   - Package: `net-tools` (also includes `netstat`)
   - Install:
     ```bash
     apt install net-tools -y
     ```
   - Usage: `arp -a` or `netstat -anp`

10. **mtr** (Continuous traceroute with ping)
    - Package: `mtr`
    - Install:
      ```bash
      apt install mtr -y
      ```
    - Usage: `mtr <pod-ip>`

### General Troubleshooting Tools
These tools help with process inspection, file system analysis, and debugging.

1. **ps** (Process listing; usually pre-installed, but ensure full features)
   - Package: `procps`
   - Install:
     ```bash
     apt install procps -y
     ```
   - Usage: `ps aux`

2. **top** (Real-time process monitoring)
   - Package: `procps` (same as `ps`)
   - Install:
     ```bash
     apt install procps -y
     ```
   - Usage: `top`

3. **free** (Memory usage)
   - Package: `procps`
   - Install:
     ```bash
     apt install procps -y
     ```
   - Usage: `free -h`

4. **df** (Disk usage; usually pre-installed)
   - Package: `coreutils`
   - Install:
     ```bash
     apt install coreutils -y
     ```
   - Usage: `df -h`

5. **find** (Search files; usually pre-installed)
   - Package: `findutils`
   - Install:
     ```bash
     apt install findutils -y
     ```
   - Usage: `find / -name <file>`

6. **strace** (Trace system calls)
   - Package: `strace`
   - Install:
     ```bash
     apt install strace -y
     ```
   - Usage: `strace -p <pid>`

7. **gdb** (Debugger for crashes)
   - Package: `gdb`
   - Install:
     ```bash
     apt install gdb -y
     ```
   - Usage: `gdb -p <pid>`

8. **nano** or **vi/vim** (Text editing for configs)
   - Package: `nano` or `vim`
   - Install:
     ```bash
     apt install nano -y
     apt install vim -y
     ```
   - Usage: `nano /path/to/file` or `vim /path/to/file`

9. **less** (View large files)
   - Package: `less`
   - Install:
     ```bash
     apt install less -y
     ```
   - Usage: `less /path/to/file`

10. **htop** (Enhanced process viewer)
    - Package: `htop`
    - Install:
      ```bash
      apt install htop -y
      ```
    - Usage: `htop`

## Installing All Tools at Once
To install all the above tools in one go, use:

```bash
apt update
apt install -y iputils-ping curl netcat-openbsd dnsutils traceroute tcpdump iproute2 iptables net-tools mtr procps coreutils findutils strace gdb nano vim less htop
```

This ensures you have a comprehensive toolkit for networking and general debugging.

## Considerations
- **Image Size**: The `ubuntu` image grows significantly after installing tools. For lightweight debugging, consider `busybox` or `alpine` with `apk` (though Alpine has different package names, e.g., `apk add bind-tools` for `dig`).
- **Permissions**: Tools like `tcpdump` require `--profile=netadmin` or root privileges. Use `--profile=sysadmin` for broader access.
- **Ephemeral Nature**: Ephemeral containers don’t persist after exit. Save any outputs (e.g., `tcpdump` captures) to a mounted volume or copy out with `kubectl cp`.
- **Alternative Image**: For networking-heavy tasks, consider `nicolaka/netshoot`, which comes with many tools pre-installed (`tcpdump`, `mtr`, `dig`, etc.).
- **Package Availability**: If a tool isn’t found, ensure `/etc/apt/sources.list` includes `universe` and `multiverse` repositories, then rerun `apt update`.

## Verifying Installation
After installation, verify tools are available:

```bash
ping -V  # Check ping version
curl --version
dig -v
tcpdump --version
ss --version
```

## Example Workflow
1. Start debug pod:
   ```bash
   kubectl debug <pod-name> -it --image=ubuntu --profile=netadmin
   ```
2. Update and install tools:
   ```bash
   apt update
   apt install -y iputils-ping curl netcat-openbsd dnsutils traceroute tcpdump
   ```
3. Test connectivity:
   ```bash
   ping <pod-ip>
   curl <service-ip>:<port>
   dig <service-name>.<namespace>.svc.cluster.local
   ```
4. Capture packets if needed:
   ```bash
   tcpdump -i eth0 -nn host <pod-ip> -w capture.pcap
   ```

## Notes
- If you need a specific Ubuntu version, specify it (e.g., `ubuntu:20.04` instead of `ubuntu:latest`) for consistency.
- For persistent debugging, create a copied pod with `kubectl debug --copy-to` and install tools there.
- If tools fail to install, check for repository issues or connectivity (`curl http://archive.ubuntu.com`).
- For advanced networking, deploy a `netshoot` pod instead:
  ```bash
  kubectl run netshoot --image=nicolaka/netshoot --rm -it -- /bin/sh
  ```

This guide equips you with the tools needed for effective troubleshooting in an Ubuntu-based debug pod. Save and refer to it as needed.
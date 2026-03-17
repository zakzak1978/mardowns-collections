# NATS JetStream Troubleshooting & Verification Guide

This document provides a comprehensive reference for verifying, monitoring, and troubleshooting NATS JetStream deployments in Kubernetes.

---

## Table of Contents

1. [Overview](#overview)
2. [Key Concepts](#key-concepts)
3. [Prerequisites](#prerequisites)
4. [Verification Commands](#verification-commands)
5. [Stream Management](#stream-management)
6. [Consumer Management](#consumer-management)
7. [Account & Quota Management](#account--quota-management)
8. [Common Issues & Solutions](#common-issues--solutions)
9. [NUI Web Interface](#nui-web-interface)
10. [Quick Reference Cheat Sheet](#quick-reference-cheat-sheet)

---

## Overview

### What is NATS?

NATS is a high-performance messaging system for cloud-native applications, IoT messaging, and microservices architectures.

### What is JetStream?

JetStream is NATS' built-in persistence layer that provides:
- **Streams**: Persistent message storage
- **Consumers**: Message delivery mechanisms (push/pull)
- **At-least-once / exactly-once delivery**
- **Message replay and acknowledgment**

### Architecture in This Environment

```
┌─────────────────────────────────────────────────────────────────┐
│                         Kubernetes Cluster                       │
│  ┌─────────────────┐    ┌─────────────────┐    ┌──────────────┐ │
│  │   NATS Server   │    │    NATS NUI     │    │   nats-box   │ │
│  │   (nats-0)      │◄───│   (Web UI)      │    │  (CLI Tool)  │ │
│  │   Port: 4222    │    │   Port: 31311   │    │              │ │
│  └────────┬────────┘    └─────────────────┘    └──────────────┘ │
│           │                                                      │
│           ▼                                                      │
│  ┌─────────────────┐                                            │
│  │   JetStream     │                                            │
│  │   (Persistence) │                                            │
│  │   - Streams     │                                            │
│  │   - Consumers   │                                            │
│  └─────────────────┘                                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Concepts

### Streams

A **Stream** is a message store that:
- Captures messages published to specific subjects
- Persists messages to disk or memory
- Applies retention policies (limits, interest, workqueue)

| Property | Description |
|----------|-------------|
| **Subjects** | Subject patterns the stream listens to (e.g., `dvnapistream.messagebroker.*`) |
| **Retention** | `Limits` (keep until limits reached), `Interest` (keep while consumers exist), `WorkQueue` (delete after ack) |
| **Storage** | `File` (persistent) or `Memory` (ephemeral) |
| **Replicas** | Number of copies for high availability |
| **Discard Policy** | `Old` (drop oldest) or `New` (reject new) when limits are reached |

### Consumers

A **Consumer** is a stateful view of a stream that:
- Tracks which messages have been delivered/acknowledged
- Supports push (server sends) or pull (client requests) delivery
- Maintains acknowledgment state

| Property | Description |
|----------|-------------|
| **Durable** | Named consumer that survives restarts |
| **Ephemeral** | Temporary consumer deleted when inactive |
| **Ack Policy** | `Explicit` (client acks), `None` (fire-and-forget), `All` (ack all prior) |
| **Replay Policy** | `Instant` (fast replay) or `Original` (replay at original rate) |
| **Deliver Policy** | `All`, `Last`, `New`, `ByStartSequence`, `ByStartTime` |

### Message Flow

```
Publisher → Subject → Stream → Consumer → Subscriber
                         │
                         ▼
                    Persistence
                    (File/Memory)
```

---

## Prerequisites

### Environment Variables

```powershell
# Set these for convenience
$NAMESPACE = "nats-kdistaging"
$NATS_URL = "nats://10.2.16.101:4222"
$NATS_BOX_POD = "nats-box-756db4975-cppxd"  # Update with actual pod name
```

### Find the nats-box Pod

```powershell
# List nats-box pods
kubectl get pods -n $NAMESPACE | findstr /i nats-box

# Or with label selector
kubectl get pods -n $NAMESPACE -l app=nats-box
```

### Verify NATS Server Connectivity

```powershell
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL server ping
```

---

## Verification Commands

### 1. Check NATS Server Status

```powershell
# Server info
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL server info

# Server list (cluster members)
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL server list

# Server ping (latency check)
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL server ping
```

### 2. Check Account Information

```powershell
# Account info including JetStream limits and usage
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL account info
```

**What to look for:**
- `Storage`: Current usage vs limit
- `Memory`: Current usage vs limit
- `Streams`: Number of streams vs limit
- `Consumers`: Number of consumers vs limit

### 3. List All Streams

```powershell
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL stream ls
```

**Output columns:**
| Column | Description |
|--------|-------------|
| Name | Stream name |
| Messages | Current message count |
| Size | Current storage size |
| Last Message | Time since last message received |

### 4. Get Detailed Stream Info

```powershell
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL stream info <stream-name>

# Example:
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL stream info dvnapistream
```

**Key fields to check:**

| Field | Description | What to Look For |
|-------|-------------|------------------|
| Subjects | Subject patterns | Verify publishers use matching subjects |
| Retention | Retention policy | `Limits`, `Interest`, or `WorkQueue` |
| Discard Policy | What happens at limit | `Old` (evict oldest) or `New` (reject) |
| Maximum Age | TTL for messages | Messages older than this are deleted |
| Maximum Messages | Message count cap | `unlimited` or specific number |
| Maximum Bytes | Storage cap | `unlimited` or specific size |
| Messages | Current count | Should increase with new messages |
| First Sequence | Oldest message seq | Compare with Last to see window |
| Last Sequence | Newest message seq | Should increase when publishing |
| Active Consumers | Consuming clients | 0 means no one is reading |

### 5. List Consumers for a Stream

```powershell
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL consumer ls <stream-name>

# Example:
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL consumer ls dvnapistream
```

### 6. Get Consumer Details

```powershell
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL consumer info <stream-name> <consumer-name>

# Example:
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL consumer info dvnapistream splicingserviceconsumer2
```

**Key fields:**
| Field | Description |
|-------|-------------|
| Ack Floor | Last acknowledged sequence |
| Pending | Messages delivered but not acked |
| Waiting | Pull consumers waiting for messages |
| Redelivered | Messages sent more than once |

---

## Stream Management

### Create a Stream

```powershell
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL stream add <stream-name> \
  --subjects "<subject.pattern>" \
  --storage file \
  --retention limits \
  --discard old \
  --max-age 24h \
  --max-bytes 1GB \
  --max-msgs 1000000
```

### Update Stream Limits

```powershell
# Increase max messages
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL stream update <stream-name> --max-msgs <number>

# Increase max bytes
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL stream update <stream-name> --max-bytes <size>

# Remove limits (unlimited)
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL stream update <stream-name> --max-msgs 0 --max-bytes 0

# Change max age
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL stream update <stream-name> --max-age 48h
```

### Purge Stream (Delete All Messages)

```powershell
# Purge all messages (keeps stream config and consumers)
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL stream purge <stream-name> --force

# Purge messages older than a duration
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL stream purge <stream-name> --keep 1000

# Purge by sequence
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL stream purge <stream-name> --seq 50000
```

### Delete a Stream

```powershell
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL stream rm <stream-name> --force
```

---

## Consumer Management

### Create a Consumer

```powershell
# Durable pull consumer
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL consumer add <stream-name> <consumer-name> \
  --pull \
  --deliver all \
  --ack explicit \
  --replay instant \
  --max-deliver 3

# Durable push consumer
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL consumer add <stream-name> <consumer-name> \
  --deliver-subject "<delivery.subject>" \
  --deliver all \
  --ack explicit
```

### Delete a Consumer

```powershell
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL consumer rm <stream-name> <consumer-name> --force
```

---

## Account & Quota Management

### Check JetStream Usage

```powershell
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL account info
```

**Sample output interpretation:**

```
JetStream Account Information:

Account Usage:
    Storage: 56 MiB        ← Current disk usage
    Memory: 0 B            ← Current memory usage
    Streams: 4             ← Number of streams
    Consumers: 22          ← Number of consumers

Account Limits:
    Memory: 0 B of Unlimited       ← No memory limit
    Storage: 56 MiB of Unlimited   ← No storage limit
    Streams: 4 of Unlimited        ← No stream count limit
```

### Understanding Limits

| Limit Type | Effect When Reached |
|------------|---------------------|
| Max Messages | Oldest messages evicted (if Discard: Old) |
| Max Bytes | Oldest messages evicted (if Discard: Old) |
| Max Age | Messages older than age auto-deleted |
| Max Per Subject | Per-subject message limit |

---

## Common Issues & Solutions

### Issue 1: Stream Message Count Stuck / Not Increasing

**Symptoms:**
- Message count stays constant
- `Last Sequence` timestamp not advancing

**Diagnosis:**

```powershell
# Check stream state
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL stream info <stream-name>

# Watch for new messages (wait 30+ seconds)
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL sub "<stream-subjects>" --count 3
```

**Possible Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| **Publisher not running** | Check publisher pods/services are healthy |
| **Publisher using wrong subject** | Verify subject matches stream's subject pattern |
| **Max limits reached (Discard: Old)** | Increase limits or accept that old messages are evicted |
| **Max Age evicting messages** | Messages older than Max Age are auto-deleted |
| **Account quota full** | Increase account-level JetStream limits |

### Issue 2: 503 Service Temporarily Unavailable

**Symptoms:**
- Intermittent 503 errors accessing NUI or NATS
- Works sometimes, fails other times

**Diagnosis:**

```powershell
# Check service endpoints
kubectl get endpoints nats-nui -n $NAMESPACE -o wide

# Watch for endpoint changes (should stay stable)
kubectl get endpoints nats-nui -n $NAMESPACE -w

# Check pod status
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=nui
```

**Possible Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| **No endpoints / pod not ready** | Check pod health, increase resources |
| **Ingress reload** | Add retry annotations to ingress |
| **App Gateway probe failure** | Configure proper health probe path |
| **Resource exhaustion** | Increase pod memory/CPU limits |

### Issue 3: 404 Not Found on External URL

**Symptoms:**
- External URL returns nginx 404
- Port-forward works locally

**Diagnosis:**

```powershell
# Check ingress exists
kubectl get ingress -n $NAMESPACE

# Describe ingress rules
kubectl describe ingress <ingress-name> -n $NAMESPACE
```

**Possible Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| **No ingress deployed** | Deploy ingress manifest |
| **Ingress path mismatch** | Verify path pattern matches URL |
| **App Gateway missing path rule** | Add path rule in Azure App Gateway |
| **Wrong host header** | Verify ingress host matches request |

### Issue 4: Consumer Lag / Messages Piling Up

**Symptoms:**
- Stream messages increasing
- Consumer `Pending` count growing
- Consumer not keeping up

**Diagnosis:**

```powershell
# Check consumer state
kubectl exec -n $NAMESPACE $NATS_BOX_POD -- nats -s $NATS_URL consumer info <stream> <consumer>
```

**Key metrics:**
- `Pending`: Messages delivered but not acked
- `Ack Floor`: Last acknowledged sequence
- `Redelivered`: Messages sent multiple times

**Solutions:**
- Scale consumer replicas
- Increase consumer processing capacity
- Check for slow/blocked consumer logic
- Verify network connectivity to consumer

### Issue 5: HTTP 502/503 Error When Loading Stream Messages in NUI

**Symptoms:**
- NUI loads successfully, streams are visible
- Clicking "LOAD MOST RECENT" or "LOAD PREVIOUS ONES" shows error
- Error popup: `http:error:502` or `http:error:503`
- Error message: `SyntaxError: Unexpected token '<', "<html>... is not valid JSON`

**Diagnosis:**

```powershell
# Check NUI pod status
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=nui

# Check for OOMKilled or CrashLoopBackOff
kubectl describe pod nats-nui-0 -n $NAMESPACE | Select-String -Pattern "Last State|Reason|Exit Code|OOMKilled"

# Check NUI pod logs for errors
kubectl logs -n $NAMESPACE nats-nui-0 --tail=50

# Check ingress annotations
kubectl get ingress nats-nui -n $NAMESPACE -o yaml
```

**Root Causes & Solutions:**

| Cause | Symptoms | Solution |
|-------|----------|----------|
| **NUI OOMKilled** | Pod in CrashLoopBackOff, Exit Code 137, `Reason: OOMKilled` | Increase memory limit (see below) |
| **Ingress timeout** | Large messages cause timeout | Add proxy timeout annotations |
| **Proxy buffer too small** | Large JSON responses truncated | Add proxy buffer annotations |

**Solution A: Increase NUI Memory Limit**

```powershell
# Check current limits
kubectl get pod nats-nui-0 -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources}'

# Patch StatefulSet to increase memory (256Mi → 1Gi)
kubectl patch statefulset nats-nui -n $NAMESPACE --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value": "1Gi"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value": "256Mi"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value": "500m"}
]'

# Wait for pod restart
kubectl rollout status statefulset/nats-nui -n $NAMESPACE
```

**Solution B: Add Ingress Proxy Annotations**

Update your ingress manifest with these annotations:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nats-nui
  namespace: nats-kdistaging
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/use-regex: "true"
    # Proxy timeout settings for large message payloads
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
    # Buffer settings for large JSON responses
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-buffer-size: "128k"
    nginx.ingress.kubernetes.io/proxy-buffers-number: "4"
```

Apply the ingress:

```powershell
kubectl apply -f nats-nui.ing.yaml
```

**Annotation Reference:**

| Annotation | Value | Purpose |
|------------|-------|---------|
| `proxy-read-timeout` | 300 | Wait up to 5 min for response (large messages) |
| `proxy-send-timeout` | 300 | Wait up to 5 min for request |
| `proxy-connect-timeout` | 60 | Connection establishment timeout |
| `proxy-body-size` | 50m | Allow large request/response bodies |
| `proxy-buffer-size` | 128k | Buffer size for large JSON responses |
| `proxy-buffers-number` | 4 | Number of buffers for streaming |

### Issue 6: NUI Pod in CrashLoopBackOff

**Symptoms:**
- `kubectl get pods` shows `CrashLoopBackOff` status
- High restart count (10+)
- Pod starts then crashes repeatedly

**Diagnosis:**

```powershell
# Check current status and restart count
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=nui

# Check previous container logs (before crash)
kubectl logs -n $NAMESPACE nats-nui-0 --previous --tail=50

# Check crash reason
kubectl describe pod nats-nui-0 -n $NAMESPACE | Select-String -Pattern "Last State|Reason|Exit Code" -Context 0,2
```

**Common Exit Codes:**

| Exit Code | Reason | Solution |
|-----------|--------|----------|
| **137** | OOMKilled (out of memory) | Increase memory limit to 1Gi+ |
| **1** | Application error | Check logs for exception details |
| **143** | SIGTERM (graceful shutdown) | Normal during rollout/scale |

**Solution: Increase Resources**

For OOMKilled (Exit Code 137):

```powershell
# Recommended resource settings for NUI handling large streams
kubectl patch statefulset nats-nui -n $NAMESPACE --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources", "value": {
    "limits": {"cpu": "500m", "memory": "1Gi"},
    "requests": {"cpu": "100m", "memory": "256Mi"}
  }}
]'
```

**Prevention:**
- Update `nui-values.yaml` with higher resource limits:

```yaml
resources:
  limits:
    cpu: 500m
    memory: 1Gi  # Increased from 256Mi
  requests:
    cpu: 100m
    memory: 256Mi
```

---

## NUI Web Interface

### Access Methods

#### 1. External URL (via Ingress + App Gateway)

```
https://sec-staging.sc.kognif.ai/nats-nui/
```

**Requirements:**
- Ingress deployed in cluster
- Azure App Gateway path rule configured

#### 2. Port-Forward (Local Access)

```powershell
# Find service port
kubectl get svc nats-nui -n $NAMESPACE

# Port-forward
kubectl port-forward -n $NAMESPACE svc/nats-nui 8080:31311

# Open browser
# http://localhost:8080/
```

### NUI Features

| Tab | Description |
|-----|-------------|
| **Connections** | Manage NATS server connections |
| **Streams** | View/edit streams, see message counts |
| **Consumers** | View consumer state, pending messages |
| **Messages** | Publish/subscribe to subjects |
| **Buckets** | Key-Value store management |

### NUI Stream Operations

- **View Stream Info**: Click stream name → see config, state, limits
- **Purge Messages**: Streams → select stream → PURGE
- **Delete Stream**: Streams → select stream → DELETE
- **Edit Stream**: Streams → select stream → EDIT

---

## Quick Reference Cheat Sheet

### Essential Commands

```powershell
# Set variables
$NS = "nats-kdistaging"
$URL = "nats://10.2.16.101:4222"
$POD = "nats-box-756db4975-cppxd"

# Server health
kubectl exec -n $NS $POD -- nats -s $URL server ping

# Account info (JetStream limits)
kubectl exec -n $NS $POD -- nats -s $URL account info

# List streams
kubectl exec -n $NS $POD -- nats -s $URL stream ls

# Stream details
kubectl exec -n $NS $POD -- nats -s $URL stream info dvnapistream

# List consumers
kubectl exec -n $NS $POD -- nats -s $URL consumer ls dvnapistream

# Consumer details
kubectl exec -n $NS $POD -- nats -s $URL consumer info dvnapistream <consumer-name>

# Subscribe to test (watch for messages)
kubectl exec -n $NS $POD -- nats -s $URL sub "dvnapistream.messagebroker.*" --count 5

# Publish test message
kubectl exec -n $NS $POD -- nats -s $URL pub "dvnapistream.messagebroker.test" "hello"

# Purge stream
kubectl exec -n $NS $POD -- nats -s $URL stream purge dvnapistream --force

# Port-forward NUI
kubectl port-forward -n $NS svc/nats-nui 8080:31311
```

### Kubernetes Health Checks

```powershell
# NATS server pods
kubectl get pods -n $NS -l app.kubernetes.io/name=nats

# NUI pod
kubectl get pods -n $NS -l app.kubernetes.io/name=nui

# nats-box pod
kubectl get pods -n $NS | findstr nats-box

# Service endpoints
kubectl get endpoints -n $NS

# Ingress rules
kubectl get ingress -n $NS
kubectl describe ingress nats-nui -n $NS

# Pod logs
kubectl logs -n $NS <pod-name> --tail=100
```

### Stream State Interpretation

| Scenario | What It Means |
|----------|---------------|
| `Messages` constant, `Last Sequence` advancing | Limits reached, old messages evicted |
| `Messages` constant, `Last Sequence` constant | No new messages being published |
| `Messages` growing, `Last Sequence` advancing | Normal operation, messages accumulating |
| `Messages` = 0 | Stream empty (purged or never used) |

### Consumer State Interpretation

| Field | Healthy | Unhealthy |
|-------|---------|-----------|
| Pending | Low/zero | High and growing |
| Redelivered | Zero or low | High (ack failures) |
| Waiting (pull) | Some waiting | Zero (consumers not polling) |

---

## Environment-Specific Configuration

### Namespace Mapping

| Environment | Namespace | NATS URL | NUI External URL |
|-------------|-----------|----------|------------------|
| scaasdev | nats-scaasdev | nats://10.2.16.101:4222 | https://scaas-dev.kognif.ai/poseidonnext/nats-nui/ |
| scaasqa | nats-scaasqa | nats://10.2.16.200:4222 | https://scaas-qa.kognif.ai/k8s/nats-nui/ |
| kdistaging | nats-kdistaging | nats://10.2.16.101:4222 | https://sec-staging.sc.kognif.ai/nats-nui/ |

### Current Streams (kdistaging)

| Stream | Subjects | Purpose |
|--------|----------|---------|
| dvnapistream | dvnapistream.messagebroker.* | DVNAPI message broker |
| splicingservicestream | splicingservicestream.* | Splicing service events |
| awsstream | awsstream.* | AWS integration |
| StreamName | (custom) | (custom purpose) |

---

## Helm Values Configuration Reference

This section documents the NATS Helm values used in deployment (`nats-values.yaml`).

### Storage Configuration

#### JetStream File Storage (Persistent)

```yaml
nats:
  jetstream:
    enabled: true
    fileStorage:
      enabled: true
      size: 10Gi
      storageClassName: {STORAGE_CLASS}  # e.g., managed-premium-retain
```

| Setting | Value | Description |
|---------|-------|-------------|
| `fileStorage.enabled` | `true` | Persistent disk storage enabled |
| `fileStorage.size` | **10Gi** | Maximum persistent storage per NATS pod |
| `fileStorage.storageClassName` | `{STORAGE_CLASS}` | Token replaced at deploy time |

**Effect:** Streams using `Storage: File` write to a 10Gi PVC. With `managed-premium-retain`, data persists even if the pod or PVC is deleted (reclaim policy: Retain).

#### JetStream Memory Storage (Ephemeral)

```yaml
nats:
  jetstream:
    memStorage:
      enabled: true
      size: 512Mi
```

| Setting | Value | Description |
|---------|-------|-------------|
| `memStorage.enabled` | `true` | In-memory storage enabled |
| `memStorage.size` | **512Mi** | Maximum RAM for memory-backed streams |

**Effect:** Streams using `Storage: Memory` are limited to 512Mi total. Data is lost on pod restart.

#### Config-Level JetStream Limits

```yaml
config:
  jetstream:
    enabled: true
    maxMemoryStore: 512Mi
    maxFileStore: 10Gi
```

| Setting | Value | Description |
|---------|-------|-------------|
| `maxMemoryStore` | **512Mi** | JetStream memory quota (matches memStorage) |
| `maxFileStore` | **10Gi** | JetStream file quota (matches fileStorage) |

**Effect:** These are the account-level limits reported by `nats account info`.

### Service Configuration

```yaml
service:
  enabled: true
  ports:
    nats:
      enabled: true
      port: 4222
  merge:
    metadata:
      annotations:
        service.beta.kubernetes.io/azure-load-balancer-internal: "true"
    spec:
      type: LoadBalancer
      loadBalancerIP: "{NATS_LOADBALANCER_IP}"  # e.g., 10.2.16.101
```

| Setting | Value | Description |
|---------|-------|-------------|
| `service.type` | `LoadBalancer` | Exposed via Azure Internal Load Balancer |
| `loadBalancerIP` | `{NATS_LOADBALANCER_IP}` | Static IP for stable connection URL |
| `annotation` | `azure-load-balancer-internal: "true"` | Internal-only LB (not internet-facing) |
| `ports.nats.port` | `4222` | Standard NATS client port |

**Effect:** Services connect to `nats://<static-ip>:4222` consistently, even after pod restarts.

### Resource Limits (NATS Container)

```yaml
container:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 768Mi
```

| Resource | Requests | Limits |
|----------|----------|--------|
| CPU | 100m | 500m |
| Memory | 256Mi | 768Mi |

**Effect:** NATS pod is guaranteed 256Mi RAM and can burst to 768Mi.

> ⚠️ **Warning:** If JetStream memory usage (512Mi) + NATS overhead exceeds 768Mi, the pod may OOMKill.
>
> **Recommendation:** Raise `limits.memory` to at least **1Gi** if you enable memory-backed streams:
> ```yaml
> limits:
>   memory: 1Gi
> ```

### Other Settings

```yaml
config:
  merge:
    max_payload: << 4MB >>
```

| Setting | Value | Description |
|---------|-------|-------------|
| `max_payload` | **4MB** | Maximum message size |

### Token Replacement at Deploy Time

These tokens in the YAML are replaced by `deploy-nats.yml` via `replace_tokens.sh`:

| Token | Example Value | Source |
|-------|---------------|--------|
| `{NATS_LOADBALANCER_IP}` | `10.2.16.101` | Variable group (e.g., N00662_northeurope_EnvironmentSpecifics) |
| `{STORAGE_CLASS}` | `managed-premium-retain` | Variable group |

### Capacity Planning

| Metric | Config Limit | Typical Usage |
|--------|--------------|---------------|
| File Storage | 10Gi | ~56 MiB (0.5%) for 4 streams |
| Memory Storage | 512Mi | 0 B (unused) |
| Streams | Unlimited | 4 |
| Consumers | Unlimited | 22 |
| Max Message Size | 4MB | Varies by publisher |

**Scaling considerations:**
- Increase `fileStorage.size` if total stream data approaches 10Gi
- Increase `container.resources.limits.memory` if using memory-backed streams
- Increase `container.resources.limits.cpu` for high-throughput scenarios

---

## Understanding StorageClass

### What is a StorageClass?

A **StorageClass** is a Kubernetes resource that defines:
- **What type of storage** to provision (SSD, HDD, network-attached, etc.)
- **How it's provisioned** (dynamically created when a PVC is requested)
- **What happens when deleted** (reclaim policy)

Think of it as a "storage template" that tells Kubernetes how to create persistent disks.

### How StorageClass is Used in NATS

When NATS deploys with JetStream enabled:

1. Kubernetes creates a **PersistentVolumeClaim (PVC)** requesting 10Gi
2. The PVC references StorageClass `managed-premium-retain`
3. Azure dynamically provisions a **Premium SSD Managed Disk**
4. The disk is mounted into the NATS pod at the JetStream data directory

```
┌─────────────────────────────────────────────────────────────────┐
│  NATS Pod                                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  JetStream Data Directory                                │   │
│  │  /data/jetstream/                                        │   │
│  │  - Streams (dvnapistream, splicingservicestream, etc.)   │   │
│  │  - Consumer state                                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ▲                                      │
│                          │ mounted                              │
└──────────────────────────┼──────────────────────────────────────┘
                           │
┌──────────────────────────┼──────────────────────────────────────┐
│  PersistentVolumeClaim   │                                      │
│  (10Gi, managed-premium-retain)                                 │
└──────────────────────────┼──────────────────────────────────────┘
                           │
┌──────────────────────────┼──────────────────────────────────────┐
│  Azure Premium SSD Managed Disk (actual storage)                │
│  - High IOPS, low latency                                       │
│  - Retained even if PVC deleted                                 │
└─────────────────────────────────────────────────────────────────┘
```

### What Does `managed-premium-retain` Do?

It's a custom StorageClass with two key properties:

#### 1. Managed Premium (Storage Type)

| Property | Value |
|----------|-------|
| Provisioner | `disk.csi.azure.com` (Azure CSI driver) |
| Disk Type | **Premium SSD** (high IOPS, low latency) |
| Use Case | Production workloads, databases, message brokers |

**Premium SSD vs Other Tiers:**

| Tier | IOPS | Latency | Cost | Use Case |
|------|------|---------|------|----------|
| Premium SSD | High (up to 20,000) | ~1ms | Higher | Production, databases |
| Standard SSD | Medium | ~5ms | Medium | Dev/test, light workloads |
| Standard HDD | Low | ~10ms | Lower | Backup, archival |

#### 2. Retain (Reclaim Policy)

This is the critical data protection setting:

| Policy | What Happens When PVC is Deleted |
|--------|----------------------------------|
| **Delete** | Underlying disk is **deleted** (data lost forever) |
| **Retain** | Underlying disk is **kept** (data preserved) |

**With `managed-premium-retain`:**
- If you `kubectl delete pvc <jetstream-pvc>` or uninstall NATS Helm release
- The Azure Managed Disk is **NOT deleted**
- Your JetStream data (streams, consumers, messages) survives
- You can manually reattach the disk later to recover data

### Data Persistence Scenarios

| Scenario | With `Delete` Policy | With `Retain` Policy |
|----------|---------------------|----------------------|
| Helm uninstall NATS | All streams/messages **lost** | Disk retained, data safe |
| Accidental PVC deletion | Data **lost** | Data preserved |
| Pod restart | Data survives | Data survives |
| Pod rescheduled to new node | Data survives | Data survives |
| Cluster migration | Must backup manually | Can reattach disk |

### Verify StorageClass and PVC

```powershell
# List all storage classes in cluster
kubectl get storageclass

# Describe the specific storage class
kubectl get storageclass managed-premium-retain -o yaml

# View PVCs for NATS JetStream
kubectl get pvc -n nats-kdistaging

# Describe PVC to see bound disk details
kubectl describe pvc -n nats-kdistaging
```

**Expected StorageClass definition:**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-premium-retain
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_LRS  # Premium SSD, Locally Redundant Storage
reclaimPolicy: Retain   # ← Key setting - keeps disk on PVC deletion
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true  # Allows resizing PVC without data loss
```

### Why This Matters for NATS JetStream

JetStream stores critical data:
- **Streams**: Message history, sequences, metadata
- **Consumers**: Acknowledgment state, delivery tracking
- **Buckets**: Key-Value store data

Using `Retain` policy ensures:
- Safe Helm upgrades (data preserved during reinstall)
- Protection against accidental deletions
- Disaster recovery options (disk can be reattached)
- Compliance with data retention requirements

> ⚠️ **Important:** With `Retain` policy, orphaned disks accumulate if not manually cleaned up. Monitor Azure Managed Disks for unused volumes after cluster changes.

---

## Additional Resources

- [NATS Documentation](https://docs.nats.io/)
- [JetStream Documentation](https://docs.nats.io/nats-concepts/jetstream)
- [NATS CLI Reference](https://docs.nats.io/using-nats/nats-tools/nats_cli)
- [NATS NUI GitHub](https://github.com/nats-nui/nui)
- [Internal: Pipelines/nats/README.md](./README.md)

---

*Last updated: February 4, 2026*

## Identification of agentpool and extended Node Pools in AKS

In your Azure Kubernetes Service (AKS) cluster (`DemoCluster` in resource group `N00482_westeurope`), the `az aks show` command output lists two node pools: `agentpool` (auto-scaling disabled) and `extended` (auto-scaling enabled). You’ve asked how I identified `agentpool` as a system node pool and `extended` as a user-defined node pool, and how you can verify these designations yourself. Since your cluster does not use Node Auto-Provisioning (NAP), as you’ve confirmed `--node-provisioning-mode Auto` was not enabled, this section explains the reasoning behind these identifications and provides straightforward commands to confirm them, focusing solely on node pool roles and avoiding networking details.

### How I Identified agentpool as a System Node Pool

The `agentpool` node pool was identified as a **system node pool** based on the following evidence and AKS conventions:

1. **Default Naming Convention**:
   - When you create an AKS cluster using `az aks create` (e.g., `az aks create -n DemoCluster -g N00482_westeurope -c 2`), AKS automatically creates a default node pool named `agentpool` unless a custom name is specified. This default node pool is designated as a **system node pool** to host critical Kubernetes components, such as CoreDNS, kube-proxy, and metrics-server.
   - The name `agentpool` matches this default convention, strongly suggesting it’s the system node pool created at cluster setup.

2. **Auto-Scaling Disabled (`AutoScaling: False`)**:
   - The `az aks show` output shows `agentpool` has `AutoScaling: False`, meaning it has a fixed number of nodes (e.g., 2, as possibly set by `-c 2` during creation). System node pools typically use a fixed node count to ensure stability for critical system pods, which require consistent resources and should not be disrupted by dynamic scaling.
   - This contrasts with user node pools, which often enable auto-scaling for flexible application workloads.

3. **Role in Hosting System Pods**:
   - System node pools are designed to run Kubernetes system components. These pods are typically deployed in the `kube-system` namespace and are scheduled on nodes with specific taints or labels to isolate them from user workloads.
   - While the `az aks show` output doesn’t directly show workloads, the `agentpool`’s characteristics align with hosting system pods, as it’s the default pool created for this purpose.

4. **Expected Taints and Labels**:
   - System node pools in AKS are often tainted with `CriticalAddonsOnly=true:NoSchedule` to restrict them to system pods and labeled with `kubernetes.azure.com/mode=system` to indicate their role. These properties are standard for default node pools like `agentpool`, though not visible in the `az aks show` output.

### How I Identified extended as a User-Defined Node Pool

The `extended` node pool was identified as a **user-defined node pool** with **Cluster Autoscaler** based on the following evidence:

1. **Non-Default Naming**:
   - Unlike `agentpool`, the name `extended` is not an AKS default, indicating it was manually created, either during cluster setup (via additional `az aks nodepool add` commands) or post-creation. User-defined node pools are given custom names to reflect their purpose, such as `extended` for additional application capacity.
   - The custom name suggests `extended` was intentionally added to handle user workloads, not system components.

2. **Auto-Scaling Enabled (`AutoScaling: True`)**:
   - The `az aks show` output shows `extended` has `AutoScaling: True`, meaning it uses Cluster Autoscaler to dynamically adjust the number of nodes between `minCount` and `maxCount` based on pod scheduling needs. This is typical for user node pools, which host application workloads (e.g., web servers, APIs) that experience variable demand.
   - Cluster Autoscaler scales up when pods are unschedulable due to insufficient resources and scales down when nodes are underutilized, making it suitable for user workloads but less common for system node pools.

3. **Role in Hosting Application Workloads**:
   - User node pools are designed to run application pods, which are typically deployed in user namespaces (e.g., `default`) rather than `kube-system`. The `extended` pool’s auto-scaling capability aligns with hosting dynamic workloads, such as microservices or batch jobs.
   - The name `extended` implies it extends cluster capacity beyond the default `agentpool`, a common pattern for user node pools.

4. **Lack of System Restrictions**:
   - User node pools generally lack restrictive taints like `CriticalAddonsOnly`, allowing any pod to schedule on them unless specific taints are applied. The `extended` pool is likely labeled with `kubernetes.azure.com/mode=user` or has no specific mode, making it open to user workloads.

### How You Can Verify These Designations

To confirm that `agentpool` is a system node pool and `extended` is a user-defined node pool, you can use the following commands to inspect their properties, labels, taints, and workloads. These commands are tailored to your AKS cluster and require `kubectl` and `az` CLI with appropriate permissions.

#### 1. Check Node Pool Mode Labels
AKS labels nodes with `kubernetes.azure.com/mode` to indicate their role (`system` or `user`).
```powershell
kubectl get nodes -o custom-columns=NAME:.metadata.name,LABELS:.metadata.labels.kubernetes\.azure\.com/mode
```
- **Expected Output**:
  ```
  NAME                       LABELS
  aks-agentpool-12345678-0   system
  aks-agentpool-12345678-1   system
  aks-extended-98765432-0    user
  aks-extended-98765432-1    user
  ```
- **Interpretation**:
  - Nodes with `aks-agentpool-*` (from `agentpool`) should have `LABELS: system`, confirming system node pool.
  - Nodes with `aks-extended-*` (from `extended`) should have `LABELS: user` or no mode label, indicating a user node pool.

#### 2. Inspect Node Taints
System node pools often have taints to restrict them to system pods.
```powershell
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```
- **Expected Output**:
  ```
  NAME                       TAINTS
  aks-agentpool-12345678-0   [map[effect:NoSchedule key:CriticalAddonsOnly value:true]]
  aks-agentpool-12345678-1   [map[effect:NoSchedule key:CriticalAddonsOnly value:true]]
  aks-extended-98765432-0    <none>
  aks-extended-98765432-1    <none>
  ```
- **Interpretation**:
  - `agentpool` nodes with `CriticalAddonsOnly=true:NoSchedule` taints are system node pools, as they restrict non-system pods.
  - `extended` nodes with no taints (or different taints) are user node pools, open to application pods.

#### 3. List Pods by Node
Check which pods run on each node pool to confirm workload types.
```powershell
kubectl get pods -A -o wide --field-selector spec.nodeName=$(kubectl get nodes -l kubernetes.azure.com/mode=system -o jsonpath='{.items[0].metadata.name}')
```
- **Purpose**: Lists pods on a system node (from `agentpool`).
- **Expected Output**: Pods in `kube-system` namespace (e.g., `coredns-*`, `kube-proxy-*`), confirming system workloads.
- For `extended`:
  ```powershell
  kubectl get pods -A -o wide --field-selector spec.nodeName=$(kubectl get nodes -l kubernetes.azure.com/mode=user -o jsonpath='{.items[0].metadata.name}')
  ```
- **Expected Output**: Application pods in user namespaces (e.g., `default`), confirming user workloads.

#### 4. Verify Node Pool Details with Azure CLI
Check node pool configurations to confirm their roles.
```powershell
# For agentpool
az aks nodepool show -g N00482_westeurope --cluster-name DemoCluster --name agentpool --query "{Name:name, Mode:mode, AutoScaling:enableAutoScaling}"
# For extended
az aks nodepool show -g N00482_westeurope --cluster-name DemoCluster --name extended --query "{Name:name, Mode:mode, AutoScaling:enableAutoScaling}"
```
- **Expected Output**:
  ```
  # agentpool
  {
    "Name": "agentpool",
    "Mode": "System",
    "AutoScaling": false
  }
  # extended
  {
    "Name": "extended",
    "Mode": "User",
    "AutoScaling": true
  }
  ```
- **Interpretation**:
  - `Mode: System` for `agentpool` confirms it’s a system node pool.
  - `Mode: User` for `extended` confirms it’s a user node pool.

#### 5. Check Node Pool Labels
Inspect node pool labels to identify their association.
```powershell
kubectl get nodes -o custom-columns=NAME:.metadata.name,NODEPOOL:.metadata.labels.kubernetes\.azure\.com/agentpool
```
- **Expected Output**:
  ```
  NAME                       NODEPOOL
  aks-agentpool-12345678-0   agentpool
  aks-agentpool-12345678-1   agentpool
  aks-extended-98765432-0    extended
  aks-extended-98765432-1    extended
  ```
- **Interpretation**: Confirms which nodes belong to `agentpool` vs. `extended`, aligning with their roles.

### Why These Commands Work

- **Labels and Taints**: AKS uses `kubernetes.azure.com/mode` labels and taints to enforce node pool roles. System node pools are explicitly marked and restricted, while user node pools are more permissive.
- **Pod Placement**: System pods in `kube-system` namespace are scheduled on system node pools, while user pods run on user node pools, reflecting their purpose.
- **Azure Metadata**: The `az aks nodepool show` command directly queries the `Mode` property, which Azure sets to `System` or `User` during node pool creation, providing definitive confirmation.

### Additional Notes

- **agentpool Creation**: Likely created automatically with `az aks create`, as it’s the default system node pool. Its fixed size ensures stability for system components.
- **extended Creation**: Likely added with `az aks nodepool add --name extended --enable-cluster-autoscaler`, explaining its custom name and auto-scaling.
- **No NAP Context**: Since NAP is not enabled, your cluster uses standard AKS node pool management, with `extended` relying on Cluster Autoscaler, not Karpenter’s `NodePool` CRDs (see [Default vs. Custom NAP Configuration](#default-vs-custom-nap-configuration)).

### Best Practices for Verification

- **Use Azure CLI for Definitive Mode**: The `az aks nodepool show` command’s `Mode` field is the most reliable way to confirm node pool roles.
- **Check Taints First**: Taints like `CriticalAddonsOnly` are a strong indicator of system node pools.
- **Monitor Pod Placement**: Regularly check pod distribution to ensure system pods stay on `agentpool` and user pods on `extended`:
  ```powershell
  kubectl get pods -A -o wide
  ```
- **Document Node Pools**: Note each node pool’s role and configuration for easier management.

### Practical Example

To verify roles in your cluster:
1. **Check Mode**:
   ```powershell
   az aks nodepool show -g N00482_westeurope --cluster-name DemoCluster --name agentpool --query "mode"
   az aks nodepool show -g N00482_westeurope --cluster-name DemoCluster --name extended --query "mode"
   ```
   Expect `"System"` for `agentpool` and `"User"` for `extended`.
2. **Inspect Taints**:
   ```powershell
   kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
   ```
   Look for `CriticalAddonsOnly` on `agentpool` nodes.
3. **List Pods**:
   ```powershell
   kubectl get pods -n kube-system -o wide
   ```
   Confirm system pods (e.g., `coredns-*`) run on `agentpool` nodes.

**Outcome**: You confirm `agentpool` hosts system pods and `extended` hosts user workloads with auto-scaling.
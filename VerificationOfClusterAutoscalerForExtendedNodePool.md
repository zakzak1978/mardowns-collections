## Verification of Cluster Autoscaler for extended Node Pool

In your Azure Kubernetes Service (AKS) cluster (`DemoCluster` in resource group `N00482_westeurope`), the `az aks show` command output indicates that the `extended` node pool has `AutoScaling: True`, while `agentpool` has `AutoScaling: False`. You’ve asked how I determined that `extended` uses Cluster Autoscaler and for a command to verify this. Since your cluster does not use Node Auto-Provisioning (NAP), as confirmed by the `NotRegistered` status of the `NodeAutoProvisioningPreview` feature, this section explains why `AutoScaling: True` signifies Cluster Autoscaler in a standard AKS setup, provides commands to confirm this for the `extended` node pool, and clarifies its role as a user-defined node pool.

### Why `AutoScaling: True` Indicates Cluster Autoscaler

The `AutoScaling: True` designation for the `extended` node pool in your `az aks show` output indicates that Cluster Autoscaler is enabled for that node pool. Here’s the reasoning:

1. **AKS Auto-Scaling Mechanism**:
   - In a standard AKS cluster without NAP, the only built-in auto-scaling mechanism for node pools is **Cluster Autoscaler**, a Kubernetes component that adjusts the number of nodes in a node pool based on workload demands.
   - When `enableAutoScaling` is set to `true` for a node pool (as shown by `AutoScaling: True`), AKS configures Cluster Autoscaler to manage that node pool’s node count within defined `minCount` and `maxCount` limits.

2. **Output Context**:
   - Your command queried `agentPoolProfiles[].{Name:name, AutoScaling:enableAutoScaling}`, where `enableAutoScaling` directly corresponds to the `enableAutoScaling` property in AKS node pool configurations. For `extended`, `AutoScaling: True` means this property is enabled, activating Cluster Autoscaler.
   - `agentpool` has `AutoScaling: False`, indicating no auto-scaling (fixed node count), typical for system node pools (see [Identification of agentpool and extended Node Pools in AKS](#identification-of-agentpool-and-extended-node-pools-in-aks)).

3. **Cluster Autoscaler Behavior**:
   - Cluster Autoscaler monitors pod scheduling:
     - **Scale-Up**: Adds nodes (up to `maxCount`) when pods cannot be scheduled due to insufficient resources.
     - **Scale-Down**: Removes underutilized nodes (down to `minCount`) when utilization falls below a threshold (e.g., 50%).
   - This aligns with `extended` being a user-defined node pool for application workloads, which benefit from dynamic scaling.

4. **No NAP**:
   - Since NAP is not enabled (no `--node-provisioning-mode Auto` or Karpenter), Cluster Autoscaler is the only auto-scaling option available in your cluster. NAP would use Karpenter’s `NodePool` CRDs, which are absent (see [Comparison of AKS Node Pools and Karpenter Node Pools](#comparison-of-aks-node-pools-and-karpenter-node-pools)).

5. **Azure Documentation**:
   - Azure documentation confirms that enabling `enableAutoScaling` on a node pool activates Cluster Autoscaler, setting `minCount` and `maxCount` to define the scaling range. This matches the `AutoScaling: True` status for `extended`.

### Commands to Verify Cluster Autoscaler for extended

To confirm that the `extended` node pool uses Cluster Autoscaler and to inspect its configuration, use the following Azure CLI and `kubectl` commands. These commands check the node pool’s auto-scaling settings, scaling limits, and Cluster Autoscaler activity.

#### 1. Check Node Pool Auto-Scaling Status
Use `az aks nodepool show` to verify `enableAutoScaling` and retrieve `minCount` and `maxCount` for `extended`.
```powershell
az aks nodepool show -g N00482_westeurope --cluster-name DemoCluster --name extended --query "{Name:name, AutoScaling:enableAutoScaling, MinCount:minCount, MaxCount:maxCount}" -o table
```
- **Expected Output**:
  ```
  Name      AutoScaling  MinCount  MaxCount
  --------  -----------  --------  --------
  extended  True         1         10
  ```
- **Interpretation**:
  - `AutoScaling: True` confirms Cluster Autoscaler is enabled.
  - `MinCount` and `MaxCount` define the scaling range (e.g., 1–10 nodes).
  - If `AutoScaling: False`, no auto-scaling is active (as with `agentpool`).

#### 2. Verify Node Pool Mode and Scaling Details
Confirm `extended` is a user node pool with Cluster Autoscaler.
```powershell
az aks nodepool show -g N00482_westeurope --cluster-name DemoCluster --name extended --query "{Name:name, Mode:mode, AutoScaling:enableAutoScaling, CurrentCount:count}" -o table
```
- **Expected Output**:
  ```
  Name      Mode  AutoScaling  CurrentCount
  --------  ----  -----------  ------------
  extended  User  True         3
  ```
- **Interpretation**:
  - `Mode: User` confirms `extended` is a user node pool for application workloads.
  - `AutoScaling: True` reiterates Cluster Autoscaler usage.
  - `CurrentCount` shows the current number of nodes (e.g., 3).

#### 3. Check Cluster Autoscaler Logs
Inspect Cluster Autoscaler activity via Kubernetes events or logs to confirm it’s managing `extended`.
```powershell
kubectl get events -A --field-selector involvedObject.kind=Node --sort-by=.metadata.creationTimestamp
```
- **Expected Output**: Look for events like:
  ```
  10m   Normal   Scaling   node/aks-extended-98765432-0   Scaled up node pool extended to 3 nodes
  5m    Normal   Scaling   node/aks-extended-98765432-1   Scaled down node pool extended due to low utilization
  ```
- **Interpretation**: Events mentioning `extended` indicate Cluster Autoscaler actions (scale-up/down).

To view Cluster Autoscaler logs:
```powershell
kubectl logs -n kube-system -l app=cluster-autoscaler --tail=100
```
- **Expected Output**: Logs may include:
  ```
  Scaling up node pool extended due to unschedulable pods
  Removing node aks-extended-98765432-1 from node pool extended
  ```
- **Interpretation**: Confirms Cluster Autoscaler is actively managing `extended`.

#### 4. List Nodes in extended Node Pool
Verify nodes belong to `extended` and check their labels.
```powershell
kubectl get nodes -l kubernetes.azure.com/agentpool=extended -o custom-columns=NAME:.metadata.name,NODEPOOL:.metadata.labels.kubernetes\.azure\.com/agentpool
```
- **Expected Output**:
  ```
  NAME                       NODEPOOL
  aks-extended-98765432-0    extended
  aks-extended-98765432-1    extended
  ```
- **Interpretation**: Nodes labeled with `extended` are managed by Cluster Autoscaler if `AutoScaling: True`.

#### 5. Confirm Absence of Karpenter
Since NAP is not enabled, ensure no Karpenter `NodePool` CRDs exist, ruling out other auto-scaling mechanisms.
```powershell
kubectl get nodepool
kubectl get aksnodeclass
```
- **Expected Output**: `No resources found`.
- **Interpretation**: Confirms `extended`’s auto-scaling is handled by Cluster Autoscaler, not Karpenter.

### Why These Commands Work

- **Azure CLI (`az aks nodepool show`)**: Directly queries AKS node pool properties (`enableAutoScaling`, `minCount`, `maxCount`, `mode`), providing definitive confirmation of Cluster Autoscaler.
- **Kubernetes Events and Logs**: Cluster Autoscaler runs as a pod in the `kube-system` namespace (`cluster-autoscaler-*`) and logs scaling actions, linking them to node pools like `extended`.
- **Node Labels**: The `kubernetes.azure.com/agentpool` label ties nodes to their node pool, helping identify which nodes are auto-scaled.
- **Karpenter Absence**: Checking for `NodePool` CRDs ensures `extended`’s auto-scaling isn’t confused with NAP/Karpenter.

### Additional Notes

- **Cluster Autoscaler in AKS**: Enabled per node pool, not cluster-wide. Your `agentpool` (`AutoScaling: False`) is fixed, while `extended` (`AutoScaling: True`) is dynamic.
- **extended as User Node Pool**: Its user mode and auto-scaling align with hosting application workloads, unlike `agentpool`’s system role (see [Identification of agentpool and extended Node Pools in AKS](#identification-of-agentpool-and-extended-node-pools-in-aks)).
- **No NAP**: The absence of NAP means `extended` relies on Cluster Autoscaler, not Karpenter’s dynamic provisioning (see [Comparison of AKS Node Pools and Karpenter Node Pools](#comparison-of-aks-node-pools-and-karpenter-node-pools)).

### Best Practices for Verification

- **Start with Azure CLI**: Use `az aks nodepool show` for the most reliable confirmation of `enableAutoScaling`.
- **Monitor Events**: Regularly check events to track Cluster Autoscaler actions:
  ```powershell
  kubectl get events -A --field-selector involvedObject.kind=Node
  ```
- **Review Logs**: Periodically inspect Cluster Autoscaler logs for troubleshooting:
  ```powershell
  kubectl logs -n kube-system -l app=cluster-autoscaler
  ```
- **Validate Node Counts**: Ensure `extended`’s node count aligns with workload needs:
  ```powershell
  kubectl get nodes -l kubernetes.azure.com/agentpool=extended
  ```
- **Document Settings**: Note `minCount` and `maxCount` for `extended` to plan capacity.

### Practical Example

To confirm `extended` uses Cluster Autoscaler:
1. **Check Auto-Scaling**:
   ```powershell
   az aks nodepool show -g N00482_westeurope --cluster-name DemoCluster --name extended --query "{AutoScaling:enableAutoScaling, MinCount:minCount, MaxCount:maxCount}" -o table
   ```
   Expect `AutoScaling: True`, e.g., `MinCount: 1`, `MaxCount: 10`.
2. **View Events**:
   ```powershell
   kubectl get events -A --field-selector involvedObject.kind=Node | grep extended
   ```
   Look for scaling events tied to `extended`.
3. **Check Logs**:
   ```powershell
   kubectl logs -n kube-system -l app=cluster-autoscaler --tail=50 | grep extended
   ```
   Confirm scaling actions for `extended`.

**Outcome**: You verify `extended` uses Cluster Autoscaler, with scaling limits and active management.
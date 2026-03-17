## Node Pools and Karpenter Node Pools

In your Azure Kubernetes Service (AKS) cluster (`DemoCluster` in resource group `N00482_westeurope`), the `az aks nodepool` command manages standard node pools, such as `agentpool` (auto-scaling disabled) and `extended` (auto-scaling enabled), as shown in your earlier `az aks show` output. Since you’ve confirmed that `--node-provisioning-mode Auto` was not enabled and the `NodeAutoProvisioningPreview` feature is `NotRegistered`, your cluster does not use Node Auto-Provisioning (NAP) or Karpenter. You’ve asked how these standard AKS node pools differ from node pools managed by Karpenter in a NAP-enabled AKS cluster. This section explains the `az aks nodepool` command’s role, compares standard AKS node pools with Karpenter-managed node pools, and provides methods to verify their configurations, keeping the focus on node pool management as per your request to avoid networking details.

### What is `az aks nodepool`?

The `az aks nodepool` command is part of the Azure CLI and is used to manage node pools in an AKS cluster. A **node pool** in AKS is a group of nodes (Azure virtual machines) with the same configuration, such as VM size, OS type, and scaling settings, that run Kubernetes workloads. In your non-NAP cluster, `az aks nodepool` manages the `agentpool` (system node pool for Kubernetes components) and `extended` (user node pool with Cluster Autoscaler).

#### Key Operations with `az aks nodepool`

- **List Node Pools**:

  ```powershell
  az aks nodepool list -g N00482_westeurope --cluster-name DemoCluster -o table
  ```

  Displays all node pools, e.g., `agentpool` and `extended`, with details like node count and auto-scaling status.
- **Show Node Pool Details**:

  ```powershell
  az aks nodepool show -g N00482_westeurope --cluster-name DemoCluster --name agentpool
  ```

  Returns configuration details, e.g., `mode` (System/User), `vmSize`, `count`, `enableAutoScaling`.
- **Add Node Pool**:

  ```powershell
  az aks nodepool add -g N00482_westeurope --cluster-name DemoCluster --name newpool --node-count 2 --mode User
  ```

  Creates a new user node pool.
- **Scale Node Pool**:

  ```powershell
  az aks nodepool scale -g N00482_westeurope --cluster-name DemoCluster --name agentpool --node-count 3
  ```

  Adjusts the node count for a fixed-size pool like `agentpool`.
- **Update Node Pool**:

  ```powershell
  az aks nodepool update -g N00482_westeurope --cluster-name DemoCluster --name extended --min-count 2 --max-count 10 --enable-cluster-autoscaler
  ```

  Modifies settings, e.g., auto-scaling limits for `extended`.
- **Delete Node Pool**:

  ```powershell
  az aks nodepool delete -g N00482_westeurope --cluster-name DemoCluster --name extended
  ```

  Removes a node pool (not recommended for `agentpool` without a replacement system pool).

In your cluster, `agentpool` is a system node pool with a fixed size, and `extended` is a user node pool with Cluster Autoscaler, managed via these commands (see Identification of agentpool and extended Node Pools in AKS).

### Standard AKS Node Pools vs. Karpenter Node Pools

Standard AKS node pools (managed by `az aks nodepool`) and Karpenter-managed node pools (in a NAP-enabled cluster) serve the same purpose—providing nodes for Kubernetes workloads—but differ significantly in their management, flexibility, and scaling mechanisms. Below is a detailed comparison based on your cluster’s context.

#### 1. Management and Configuration

- **Standard AKS Node Pools** (Your Cluster: `agentpool`, `extended`):

  - **Managed By**: Azure AKS service via `az aks nodepool` commands or Azure Portal.
  - **Configuration**: Defined as Azure resources with fixed or auto-scaling settings. Each node pool has a specific VM size, OS type, and mode (System or User).
    - `agentpool`: Fixed size (`AutoScaling: False`), mode `System`, hosts Kubernetes components (e.g., CoreDNS).
    - `extended`: Cluster Autoscaler enabled (`AutoScaling: True`), mode `User`, hosts application workloads.
  - **Creation**: Created during cluster setup (`agentpool` by default) or added manually (`extended` via `az aks nodepool add`).
  - **Example**:

    ```powershell
    az aks nodepool show -g N00482_westeurope --cluster-name DemoCluster --name extended --query "{Name:name, Mode:mode, VMSize:vmSize, AutoScaling:enableAutoScaling, MinCount:minCount, MaxCount:maxCount}"
    ```

    Output:

    ```json
    {
      "Name": "extended",
      "Mode": "User",
      "VMSize": "Standard_D2s_v3",
      "AutoScaling": true,
      "MinCount": 1,
      "MaxCount": 10
    }
    ```
  - **Persistence**: Node pools are persistent Azure resources until deleted, with nodes replaced only during upgrades or scaling.

- **Karpenter Node Pools** (NAP-Enabled Cluster):

  - **Managed By**: Karpenter, an open-source auto-scaler, using Kubernetes Custom Resource Definitions (CRDs) like `NodePool` and `AKSNodeClass`.
  - **Configuration**: Defined via Kubernetes YAML manifests, offering granular control over node requirements (e.g., CPU, memory, instance types) and disruption policies. Multiple `NodePool` CRDs can coexist, each referencing an `AKSNodeClass` for Azure-specific settings (e.g., VM size, image).
    - Example `NodePool`: Specifies node requirements (e.g., `spot` instances, Linux OS) and consolidation policies.
    - Example `AKSNodeClass`: Defines VM size (e.g., `Standard_NC6s_v3` for GPUs), OS image, and tags.
  - **Creation**: Automatically created with defaults when NAP is enabled (`--node-provisioning-mode Auto`) or manually defined for custom needs (see Default vs. Custom NAP Configuration).
  - **Example**:

    ```yaml
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: spot-nodes
    spec:
      template:
        spec:
          nodeClassRef:
            name: spot-class
          requirements:
          - key: karpenter.sh/capacity-type
            operator: In
            values: ["spot"]
      disruption:
        consolidationPolicy: WhenUnderutilized
        consolidateAfter: 30s
    ---
    apiVersion: karpenter.azure.com/v1alpha2
    kind: AKSNodeClass
    metadata:
      name: spot-class
    spec:
      vmSize: Standard_D2as_v5
      imageFamily: AzureLinux
    ```

    ```powershell
    kubectl apply -f spot-nodepool.yaml
    ```
  - **Persistence**: Nodes are ephemeral, created and terminated by Karpenter based on pod needs, with `NodePool` CRDs persisting as Kubernetes resources.

#### 2. Scaling Mechanism

- **Standard AKS Node Pools**:

  - **Scaling**:
    - **agentpool**: Fixed size, manually scaled with `az aks nodepool scale`. Example:

      ```powershell
      az aks nodepool scale -g N00482_westeurope --cluster-name DemoCluster --name agentpool --node-count 3
      ```
    - **extended**: Uses Cluster Autoscaler, which scales nodes based on unschedulable pods or underutilized nodes within `minCount` and `maxCount`. Example:

      ```powershell
      az aks nodepool update -g N00482_westeurope --cluster-name DemoCluster --name extended --min-count 2 --max-count 15
      ```
  - **Behavior**: Cluster Autoscaler reacts to pod scheduling failures, adding nodes (up to `maxCount`) or removing underutilized ones (down to `minCount`). It’s slower and less granular than Karpenter, typically taking minutes to scale.
  - **Limitations**: Limited to predefined VM sizes and configurations per node pool, no support for spot instances or dynamic instance type selection.

- **Karpenter Node Pools**:

  - **Scaling**: Karpenter dynamically provisions nodes based on pod resource requests and constraints defined in `NodePool` CRDs. It:
    - Creates nodes with optimal VM sizes and types (e.g., spot or on-demand) when pods are unschedulable.
    - Consolidates or terminates nodes when underutilized, using policies like `WhenUnderutilized` or `WhenEmpty` (see Advanced Consolidation Strategies).
  - **Behavior**: Faster scaling (seconds to minutes) due to direct integration with Azure APIs and Kubernetes scheduling. Supports diverse instance types, zones, and capacity types (e.g., spot) within a single `NodePool`.
  - **Example**: If a pod requires a GPU, Karpenter provisions a node matching the `NodePool`’s requirements:

    ```powershell
    kubectl get nodes --selector=karpenter.sh/nodepool=spot-nodes
    ```

#### 3. Flexibility and Customization

- **Standard AKS Node Pools**:

  - **Customization**: Limited to VM size, OS type, node count, and auto-scaling settings at creation or update. Each node pool is homogeneous (all nodes identical).
  - **Use Cases**:
    - `agentpool`: Stable hosting for system pods (e.g., CoreDNS, metrics-server).
    - `extended`: Dynamic hosting for application workloads with basic auto-scaling.
  - **Constraints**: No support for spot instances, custom images, or advanced disruption policies. Changes require `az aks nodepool` commands, which are less flexible than Kubernetes CRDs.

- **Karpenter Node Pools**:

  - **Customization**: Highly flexible via `NodePool` and `AKSNodeClass` CRDs, supporting:
    - Multiple instance types (e.g., `Standard_D2s_v3`, `Standard_NC6s_v3`).
    - Spot or on-demand capacity.
    - Custom OS images, taints, labels, and disruption budgets.
    - Multi-tenant or workload-specific configurations (see Default vs. Custom NAP Configuration).
  - **Use Cases**: Specialized workloads (e.g., GPUs for ML), cost optimization (spot instances), compliance (specific images), or multi-tenant clusters.
  - **Example**: A `NodePool` for spot instances with GPU requirements:

    ```yaml
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: gpu-spot
    spec:
      template:
        spec:
          nodeClassRef:
            name: gpu-class
          requirements:
          - key: nvidia.com/gpu
            operator: Exists
          - key: karpenter.sh/capacity-type
            operator: In
            values: ["spot"]
    ```

#### 4. Disruption and Consolidation

- **Standard AKS Node Pools**:

  - **Disruption**: Managed by Cluster Autoscaler for `extended`, which removes underutilized nodes but lacks fine-grained control. `agentpool` nodes are not automatically consolidated.
  - **Consolidation**: Basic, based on utilization thresholds. No proactive consolidation to optimize costs.
  - **Example**: `extended` may scale down if nodes are under 50% utilized, but it doesn’t rebalance pods to fewer nodes.

- **Karpenter Node Pools**:

  - **Disruption**: Controlled via `disruption` policies in `NodePool` CRDs, with options like `consolidationPolicy` (`WhenUnderutilized`, `WhenEmpty`) and `budgets` to limit simultaneous terminations.
  - **Consolidation**: Proactive, rebalancing pods to fewer nodes to reduce costs, with customizable `consolidateAfter` timers (see Scheduling Constraints and Disruption Controls).
  - **Example**: Karpenter consolidates nodes after 30 seconds of underutilization:

    ```yaml
    disruption:
      consolidationPolicy: WhenUnderutilized
      consolidateAfter: 30s
    ```

#### 5. Drift Detection

- **Standard AKS Node Pools**:

  - **Drift**: No automated drift detection. If node configurations deviate (e.g., due to manual changes), AKS does not automatically correct them. You must update via `az aks nodepool update`.
  - **Management**: Manual intervention required to align with desired state.

- **Karpenter Node Pools**:

  - **Drift**: Automated drift detection ensures nodes match `NodePool` and `AKSNodeClass` specifications. Non-compliant nodes are replaced (see Drift Detection and Handling).
  - **Example**: If a node’s VM size changes, Karpenter terminates and replaces it:

    ```powershell
    kubectl get events -A --field-selector reason=DriftDetected
    ```

#### 6. Integration with AKS

- **Standard AKS Node Pools**:
  - **Integration**: Tightly coupled with AKS, managed as Azure resources. Compatible with Cluster Autoscaler and AKS upgrades.
  - **Your Cluster**: `agentpool` and `extended` are fully managed by AKS, with `extended` using Cluster Autoscaler for scaling.
- **Karpenter Node Pools**:
  - **Integration**: Managed by Karpenter within AKS, requiring NAP enablement (`--node-provisioning-mode Auto`). Complements standard node pools but requires the `NodeAutoProvisioningPreview` feature (currently `NotRegistered` in your subscription).
  - **Example**: NAP-enabled cluster with Karpenter managing additional nodes alongside `agentpool`.

### Comparison Table

| **Feature** | **Standard AKS Node Pools** (`az aks nodepool`) | **Karpenter Node Pools** (NAP) |
| --- | --- | --- |
| **Management** | Azure CLI (`az aks nodepool`) | Kubernetes CRDs (`NodePool`, `AKSNodeClass`) |
| **Scaling** | Cluster Autoscaler or manual | Karpenter dynamic provisioning |
| **Auto-Scaling** | `extended`: Yes; `agentpool`: No | All `NodePool`s dynamic |
| **Customization** | Limited (VM size, OS, count) | High (instance types, spot, taints, images) |
| **Disruption Control** | Basic (Cluster Autoscaler) | Advanced (consolidation, budgets) |
| **Consolidation** | Basic, reactive | Proactive, customizable |
| **Drift Detection** | None | Automated |
| **Use Case** | System (`agentpool`), basic apps (`extended`) | Specialized, cost-optimized, multi-tenant |
| **Your Cluster** | Active (`agentpool`, `extended`) | Not active (NAP disabled) |

### Verifying Node Pool Types in Your Cluster

To confirm your node pools are standard AKS node pools and check their configurations:

1. **List Node Pools**:

   ```powershell
   az aks nodepool list -g N00482_westeurope --cluster-name DemoCluster -o table
   ```

   Confirms `agentpool` (System, fixed) and `extended` (User, auto-scaling).
2. **Check Node Pool Mode**:

   ```powershell
   az aks nodepool show -g N00482_westeurope --cluster-name DemoCluster --name agentpool --query "mode"
   az aks nodepool show -g N00482_westeurope --cluster-name DemoCluster --name extended --query "mode"
   ```

   Expect `"System"` for `agentpool`, `"User"` for `extended`.
3. **Inspect Nodes**:

   ```powershell
   kubectl get nodes -o custom-columns=NAME:.metadata.name,NODEPOOL:.metadata.labels.kubernetes\.azure\.com/agentpool
   ```

   Shows nodes labeled with `agentpool` or `extended`.
4. **Check for Karpenter**:

   ```powershell
   kubectl get nodepool
   kubectl get aksnodeclass
   ```

   If NAP is disabled, these return `No resources found`, confirming no Karpenter node pools.

### Enabling Karpenter Node Pools (Optional)

To use Karpenter node pools, enable NAP as described in Analysis of NodeAutoProvisioningPreview Feature Status:

1. Register the feature:

   ```powershell
   az feature register --namespace "Microsoft.ContainerService" --name "NodeAutoProvisioningPreview"
   ```
2. Enable NAP:

   ```powershell
   az aks update -n DemoCluster -g N00482_westeurope --node-provisioning-mode Auto
   ```
3. Install Karpenter and apply CRDs:

   ```powershell
   kubectl apply -f https://raw.githubusercontent.com/Azure/karpenter-provider-azure/main/examples/default.yaml
   ```

### Best Practices

- **Maintain agentpool**: Keep `agentpool` as a system node pool for stability, avoiding auto-scaling.
- **Optimize extended**: Adjust `minCount` and `maxCount` for `extended` based on workload needs:

  ```powershell
  az aks nodepool update -g N00482_westeurope --cluster-name DemoCluster --name extended --min-count 2 --max-count 15
  ```
- **Verify Roles**: Regularly check node pool modes and workloads:

  ```powershell
  kubectl get pods -A -o wide
  ```
- **Plan for NAP**: If adopting Karpenter, test in a staging cluster to validate custom CRDs.
- **Monitor Usage**:

  ```powershell
  kubectl top nodes
  ```

### Practical Example

Your cluster runs system pods on `agentpool` and a web app on `extended`. To manage:

1. Scale `agentpool`:

   ```powershell
   az aks nodepool scale -g N00482_westeurope --cluster-name DemoCluster --name agentpool --node-count 3
   ```
2. Adjust `extended`:

   ```powershell
   az aks nodepool update -g N00482_westeurope --cluster-name DemoCluster --name extended --min-count 3 --max-count 20
   ```
3. Check Karpenter absence:

   ```powershell
   kubectl get nodepool
   ```

   Expect `No resources found`.

To add a Karpenter `NodePool` for spot instances, enable NAP and apply:

```yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: spot-web
spec:
  template:
    spec:
      nodeClassRef:
        name: default
      requirements:
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["spot"]
```

**Outcome**: Standard node pools support current workloads; Karpenter enables advanced scaling if NAP is activated.
## Default vs. Custom NAP Configuration

Node Auto-Provisioning (NAP) in Azure Kubernetes Service (AKS), enabled via `--node-provisioning-mode Auto` in your `az aks create` command, simplifies cluster scaling by dynamically provisioning and deprovisioning nodes based on workload demands. Powered by Karpenter, NAP creates default `NodePool` and `AKSNodeClass` Custom Resource Definitions (CRDs) with sensible settings to streamline cluster setup. However, custom CRDs provide granular control to tailor node configurations for specific requirements, such as specialized hardware, cost optimization, compliance, or complex scaling policies. This section elaborates on default and custom NAP configurations, when to use custom CRDs, how to override defaults, and their integration with your AKS setup using `--network-plugin azure`, `--network-plugin-mode overlay`, and `--network-dataplane cilium`.

### Understanding Default NAP Configuration

When you create an AKS cluster with `--node-provisioning-mode Auto`, NAP automatically generates default `NodePool` and `AKSNodeClass` resources to manage node provisioning. These defaults are designed for general-purpose workloads, ensuring quick setup and compatibility with AKS networking requirements, such as the overlay mode and Cilium dataplane specified in your command.

#### Default NodePool
- **Purpose**: The `NodePool` CRD defines the desired node characteristics and scaling policies for a group of nodes managed by NAP.
- **Default Settings**:
  - **Name**: `default`
  - **Requirements**: Broad compatibility, typically allowing Linux nodes with on-demand instances (e.g., `karpenter.sh/capacity-type: on-demand`, `kubernetes.io/os: linux`).
  - **Disruption Policies**: Configured with `consolidationPolicy: WhenUnderutilized` and a moderate `consolidateAfter` (e.g., `30s`) to optimize resource usage by removing underutilized nodes.
  - **Budgets**: Includes a default disruption budget (e.g., `nodes: "10%"`) to limit simultaneous node terminations during consolidation or expiration.
  - **Expiration**: Often set to `expireAfter: Never` to prevent automatic node termination unless overridden.
- **Networking Integration**: Aligns with `--network-plugin-mode overlay` and `--network-dataplane cilium`, ensuring pods use a private CIDR (e.g., `192.168.0.0/16`) and Cilium’s eBPF-based networking.
- **Example** (View default `NodePool`):
  ```powershell
  kubectl get nodepool default -o yaml
  ```
  Sample output:
  ```yaml
  apiVersion: karpenter.sh/v1beta1
  kind: NodePool
  metadata:
    name: default
  spec:
    template:
      spec:
        nodeClassRef:
          name: default
        requirements:
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        expireAfter: Never
    disruption:
      consolidationPolicy: WhenUnderutilized
      consolidateAfter: 30s
      budgets:
      - nodes: "10%"
  ```

#### Default AKSNodeClass
- **Purpose**: The `AKSNodeClass` CRD specifies Azure-specific node configurations, such as VM size, OS image, and disk settings, referenced by a `NodePool`.
- **Default Settings**:
  - **Name**: `default`
  - **Image**: Uses a recent Azure Linux image (e.g., `imageFamily: AzureLinux`) compatible with AKS.
  - **Disk**: Configures a standard OS disk size (e.g., `osDiskSizeGB: 128`).
  - **VM Size**: Selects general-purpose VM SKUs (e.g., `Standard_D2s_v3`) suitable for typical workloads.
  - **Tags**: Applies minimal Azure resource tags (e.g., `env: prod`) for resource tracking.
- **Networking Compatibility**: Supports the overlay networking mode and Cilium dataplane, ensuring seamless integration with your cluster’s networking configuration.
- **Example** (View default `AKSNodeClass`):
  ```powershell
  kubectl get aksnodeclass default -o yaml
  ```
  Sample output:
  ```yaml
  apiVersion: karpenter.azure.com/v1alpha2
  kind: AKSNodeClass
  metadata:
    name: default
  spec:
    imageFamily: AzureLinux
    osDiskSizeGB: 128
    vmSize: Standard_D2s_v3
    tags:
      env: prod
  ```

#### Benefits of Default Configuration
- **Simplicity**: Automatically created during cluster setup, requiring no manual configuration.
- **General-Purpose**: Suitable for standard workloads, such as web applications or microservices, with moderate scaling needs.
- **NAP Integration**: Optimized for NAP’s dynamic provisioning and your specified networking (overlay with Cilium), ensuring efficient pod placement and node scaling.
- **Quick Start**: Enables rapid cluster deployment, as seen in your command:
  ```powershell
  az aks create -n nap -g nap-rg -c 2 --node-provisioning-mode Auto --network-plugin azure --network-plugin-mode overlay --network-dataplane cilium
  ```

#### Limitations
- **Generic Settings**: Defaults may not suit specialized workloads (e.g., GPU-intensive tasks) or cost-sensitive environments (e.g., spot instances).
- **Limited Control**: Lacks fine-grained policies for compliance, multi-tenancy, or advanced scaling.
- **One-Size-Fits-All**: May not optimize resources for diverse workload requirements in large clusters.

### Custom NAP Configuration with CRDs

Custom `NodePool` and `AKSNodeClass` CRDs allow you to override default settings, tailoring node provisioning to specific workload needs. This is particularly valuable in NAP-enabled clusters, where dynamic scaling benefits from precise configurations to optimize performance, cost, and compliance.

#### Why Create Custom CRDs?
Custom CRDs are necessary when the default configurations do not meet your requirements. Below are detailed scenarios and examples, aligned with your NAP setup:

1. **Specialized VM Sizes or Hardware**:
   - **Scenario**: Workloads requiring GPUs (e.g., machine learning training) or high-memory VMs (e.g., in-memory databases) need specific VM SKUs unavailable in the default `Standard_D2s_v3`.
   - **Example**: Configure an `AKSNodeClass` for GPU-enabled nodes:
     ```yaml
     apiVersion: karpenter.azure.com/v1alpha2
     kind: AKSNodeClass
     metadata:
       name: gpu-class
     spec:
       imageFamily: AzureLinux
       osDiskSizeGB: 128
       vmSize: Standard_NC6s_v3  # GPU-enabled VM
       tags:
         workload: ml-training
     ```
     Reference it in a `NodePool`:
     ```yaml
     apiVersion: karpenter.sh/v1beta1
     kind: NodePool
     metadata:
       name: gpu-nodes
     spec:
       template:
         spec:
           nodeClassRef:
             name: gpu-class
           requirements:
           - key: kubernetes.io/os
             operator: In
             values: ["linux"]
           - key: nvidia.com/gpu
             operator: Exists
     ```
   - **Relevance to NAP**: NAP provisions GPU nodes only when pods require them, leveraging Cilium’s overlay networking for pod communication.

2. **Cost Optimization**:
   - **Scenario**: Use spot instances or smaller VMs to reduce costs for non-critical workloads, such as CI/CD pipelines or batch jobs.
   - **Example**: Configure a `NodePool` for spot instances:
     ```yaml
     apiVersion: karpenter.sh/v1beta1
     kind: NodePool
     metadata:
       name: spot-nodes
     spec:
       template:
         spec:
           nodeClassRef:
             name: default
           requirements:
           - key: kubernetes.io/os
             operator: In
             values: ["linux"]
           - key: karpenter.sh/capacity-type
             operator: In
             values: ["spot"]
           - key: karpenter.azure.com/sku-family
             operator: In
             values: ["D"]
       disruption:
         consolidationPolicy: WhenEmptyOrUnderutilized
         consolidateAfter: 30s
     ```
   - **Relevance to NAP**: NAP’s consolidation (see [Advanced Consolidation Strategies](#advanced-consolidation-strategies)) aggressively removes underutilized spot nodes, minimizing costs while maintaining Cilium’s networking efficiency.

3. **Compliance Needs**:
   - **Scenario**: Regulatory requirements demand specific OS images (e.g., Ubuntu 22.04) or security configurations (e.g., encrypted disks).
   - **Example**: Configure an `AKSNodeClass` for Ubuntu:
     ```yaml
     apiVersion: karpenter.azure.com/v1alpha2
     kind: AKSNodeClass
     metadata:
       name: compliance-class
     spec:
       imageFamily: Ubuntu2204
       osDiskSizeGB: 256
       osDiskType: Managed
       vmSize: Standard_D4s_v3
       tags:
         compliance: regulated
     ```
     Reference it in a `NodePool`:
     ```yaml
     apiVersion: karpenter.sh/v1beta1
     kind: NodePool
     metadata:
       name: compliance-nodes
     spec:
       template:
         spec:
           nodeClassRef:
             name: compliance-class
           requirements:
           - key: kubernetes.io/os
             operator: In
             values: ["linux"]
     ```
   - **Relevance to NAP**: NAP ensures nodes match compliance requirements, with drift detection (see [Drift Detection and Handling](#drift-detection-and-handling)) replacing non-compliant nodes.

4. **Multi-Tenant Scenarios or Advanced Scaling Policies**:
   - **Scenario**: Multi-tenant clusters require isolated node pools for different teams, or workloads need custom disruption budgets and expiration policies.
   - **Example**: Configure a `NodePool` for a specific team with strict disruption controls:
     ```yaml
     apiVersion: karpenter.sh/v1beta1
     kind: NodePool
     metadata:
       name: team-a-nodes
     spec:
       template:
         spec:
           nodeClassRef:
             name: default
           requirements:
           - key: kubernetes.io/os
             operator: In
             values: ["linux"]
           - key: topology.kubernetes.io/zone
             operator: In
             values: ["eastus-1", "eastus-2"]
           taints:
           - key: team
             value: team-a
             effect: NoSchedule
       disruption:
         consolidationPolicy: WhenEmpty
         consolidateAfter: 5m
         budgets:
         - nodes: "1"
         expireAfter: 7d
     ```
   - **Relevance to NAP**: NAP provisions nodes for Team A only when pods tolerate the `team: team-a` taint, using Cilium’s network policies for tenant isolation (see [Comparison of Calico, Cilium, and Flannel CNIs](#comparison-of-calico-cilium-and-flannel-cnis)).

#### Benefits of Custom CRDs
- **Precision**: Tailor node configurations to exact workload needs, improving performance and efficiency.
- **Cost Savings**: Optimize resource usage with spot instances or smaller VMs, leveraging NAP’s consolidation.
- **Compliance**: Meet regulatory or organizational requirements through specific OS images or configurations.
- **Flexibility**: Support diverse workloads in multi-tenant or complex clusters with isolated node pools.

#### Challenges
- **Complexity**: Requires Kubernetes and Azure expertise to define and manage CRDs.
- **Maintenance**: Custom CRDs need regular updates to align with AKS and NAP changes.
- **Testing**: Must be validated in non-production to avoid misconfigurations impacting workloads.

### Overriding Default CRDs

To customize NAP behavior, you can override the default `NodePool` and `AKSNodeClass` CRDs by creating and applying custom configurations. Below is a step-by-step process, including verification and monitoring, tailored to your NAP-enabled AKS cluster.

#### Step 1: View Default CRDs
Inspect the default configurations to understand their settings:
```powershell
# View default NodePool
kubectl get nodepool default -o yaml

# View default AKSNodeClass
kubectl get aksnodeclass default -o yaml
```
These commands display the default `NodePool` (e.g., `consolidationPolicy`, `requirements`) and `AKSNodeClass` (e.g., `vmSize`, `imageFamily`), serving as a baseline for customization.

#### Step 2: Create Custom CRDs
Define custom `AKSNodeClass` and `NodePool` resources in YAML files. Example for a cost-optimized setup using spot instances:

- **custom-aksnodeclass.yaml**:
  ```yaml
  apiVersion: karpenter.azure.com/v1alpha2
  kind: AKSNodeClass
  metadata:
    name: spot-class
  spec:
    imageFamily: AzureLinux
    osDiskSizeGB: 128
    vmSize: Standard_D2as_v5  # Smaller, cost-effective VM
    tags:
      purpose: cost-optimized
  ```

- **custom-nodepool.yaml**:
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
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: karpenter.azure.com/sku-family
          operator: In
          values: ["D"]
    disruption:
      consolidationPolicy: WhenEmptyOrUnderutilized
      consolidateAfter: 30s
      budgets:
      - nodes: "20%"
    limits:
      cpu: "50"  # Caps total CPU to control costs
  ```

#### Step 3: Apply Custom CRDs
Deploy the custom configurations:
```powershell
kubectl apply -f custom-aksnodeclass.yaml
kubectl apply -f custom-nodepool.yaml
```
These commands create the new `spot-class` `AKSNodeClass` and `spot-nodes` `NodePool`, which NAP uses to provision spot instance nodes.

#### Step 4: Verify Custom Configuration
Confirm the CRDs are applied and nodes are provisioned:
```powershell
# Check NodePool
kubectl get nodepool spot-nodes -o yaml

# Check AKSNodeClass
kubectl get aksnodeclass spot-class -o yaml

# Verify nodes
kubectl get nodes --selector=karpenter.sh/nodepool=spot-nodes
```
The `get nodes` command lists nodes managed by the `spot-nodes` NodePool, showing spot instance VMs with the specified `Standard_D2as_v5` size.

#### Step 5: Monitor NAP Behavior
Track NAP’s provisioning and consolidation actions:
```powershell
# Check events for NodePool
kubectl get events -A --field-selector involvedObject.kind=NodePool,involvedObject.name=spot-nodes

# Visualize node utilization
aks-node-viewer -resources cpu,memory -disable-pricing

# Monitor Cilium networking
cilium status
```
These commands ensure NAP provisions nodes correctly, consolidates underutilized ones, and maintains Cilium’s overlay networking.

#### Step 6: Remove or Modify Defaults (Optional)
To replace the default `NodePool`, delete it (if no nodes are managed) and rely on custom NodePools:
```powershell
kubectl delete nodepool default
```
**Caution**: Ensure custom NodePools cover all workload requirements to avoid scheduling issues. The default `AKSNodeClass` can remain unless fully replaced by custom classes.

### Integration with Your AKS Setup

Your AKS cluster, created with:
```powershell
az aks create -n nap -g nap-rg -c 2 --node-provisioning-mode Auto --network-plugin azure --network-plugin-mode overlay --network-dataplane cilium
```
leverages NAP with the following considerations:
- **Overlay Networking**: The `--network-plugin-mode overlay` requires a private pod CIDR (e.g., `--pod-cidr 192.168.0.0/16`), which custom `NodePool` and `AKSNodeClass` configurations must support. Cilium’s eBPF-based networking ensures efficient pod communication across dynamically provisioned nodes.
- **Cilium Dataplane**: The `--network-dataplane cilium` mandates Cilium for network policies and observability. Custom CRDs should align with Cilium’s capabilities, such as Layer 7 policies:
  ```yaml
  apiVersion: cilium.io/v2
  kind: CiliumNetworkPolicy
  metadata:
    name: restrict-gpu-access
  spec:
    endpointSelector:
      matchLabels:
        app: ml-workload
    ingress:
    - fromEndpoints:
      - matchLabels:
          app: frontend
      toPorts:
      - ports:
        - port: "80"
          protocol: TCP
  ```
- **Dynamic Scaling**: NAP’s ability to provision and terminate nodes based on custom CRDs enhances scalability, especially for specialized or cost-optimized workloads.

### Best Practices for Custom NAP Configuration

- **Start with Defaults**: Use default CRDs as a reference to understand NAP’s baseline behavior before customizing.
- **Define Clear Objectives**:
  - For GPUs, specify hardware requirements (e.g., `nvidia.com/gpu`).
  - For cost, prioritize `spot` capacity types and aggressive consolidation.
  - For compliance, ensure `imageFamily` and `tags` meet requirements.
- **Test in Non-Production**: Validate custom CRDs in a staging AKS cluster to confirm compatibility with NAP, Cilium, and overlay networking.
- **Use Multiple NodePools**: Create separate `NodePool` resources for different workload types (e.g., GPU, spot, compliance) to isolate configurations:
  ```powershell
  kubectl get nodepool --all
  ```
- **Monitor Resource Usage**:
  ```powershell
  kubectl get nodes --show-labels
  aks-node-viewer -resources cpu,memory -disable-pricing
  ```
- **Leverage Disruption Controls**: Configure `budgets` and `consolidateAfter` in custom `NodePool` CRDs to balance availability and efficiency (see [Scheduling Constraints and Disruption Controls](#scheduling-constraints-and-disruption-controls)).
- **Handle Drift**: Regularly update custom CRDs to align with Azure updates, using drift detection to replace non-compliant nodes (see [Drift Detection and Handling](#drift-detection-and-handling)).
- **Document Configurations**: Maintain a record of custom CRDs and their purposes to simplify cluster management.

### Practical Example

Your AKS cluster with NAP supports a mixed workload: a GPU-based machine learning application and a cost-sensitive web frontend. You create two custom NodePools:

1. **GPU NodePool**:
   ```yaml
   apiVersion: karpenter.azure.com/v1alpha2
   kind: AKSNodeClass
   metadata:
     name: gpu-class
   spec:
     imageFamily: AzureLinux
     vmSize: Standard_NC6s_v3
   ---
   apiVersion: karpenter.sh/v1beta1
   kind: NodePool
   metadata:
     name: gpu-nodes
   spec:
     template:
       spec:
         nodeClassRef:
           name: gpu-class
         requirements:
         - key: nvidia.com/gpu
           operator: Exists
   ```
   NAP provisions GPU nodes only for ML pods, using Cilium for networking.

2. **Spot NodePool**:
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
     disruption:
       consolidationPolicy: WhenEmptyOrUnderutilized
       consolidateAfter: 30s
   ```
   NAP uses spot instances for the web frontend, consolidating nodes to save costs.

**Apply and Verify**:
```powershell
kubectl apply -f gpu-nodepool.yaml
kubectl apply -f spot-nodepool.yaml
kubectl get nodes --selector=karpenter.sh/nodepool=gpu-nodes
kubectl get nodes --selector=karpenter.sh/nodepool=spot-web
kubectl get events -A --field-selector reason=NodeClaimCreated
```

**Outcome**: NAP provisions specialized nodes for each workload, with Cilium ensuring secure pod communication in overlay mode.

### Limitations and Considerations

- **Default Dependency**: Deleting the default `NodePool` without custom alternatives may disrupt workloads lacking specific node requirements.
- **Cilium Compatibility**: Custom CRDs must support `--network-dataplane cilium`, limiting CNI choices (e.g., no Calico).
- **Resource Quotas**: Ensure Azure VM quotas support custom VM sizes or spot instances for NAP provisioning.
- **Learning Curve**: Customizing CRDs requires familiarity with Karpenter and AKS configurations.

By leveraging default and custom NAP configurations, you can optimize your AKS cluster for diverse workloads while benefiting from NAP’s dynamic scaling and Cilium’s advanced networking.
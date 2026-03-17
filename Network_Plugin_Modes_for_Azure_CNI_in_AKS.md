## Network Plugin Modes for Azure CNI in AKS

In Azure Kubernetes Service (AKS), the `--network-plugin-mode` parameter, used with `--network-plugin azure` in the `az aks create` command, specifies the operational mode of the Azure Container Networking Interface (CNI) plugin. Your command includes `--network-plugin-mode overlay`, which is required for Node Auto-Provisioning (NAP) alongside `--network-dataplane cilium`. This section explains the available network plugin modes for Azure CNI in AKS, their functionality, use cases, and relevance to NAP, helping you understand the networking options for your AKS cluster.

### Overview of Azure CNI and Network Plugin Modes

The Azure CNI plugin (`--network-plugin azure`) integrates Kubernetes networking with Azure Virtual Network (VNet) infrastructure, assigning IP addresses to pods and managing network policies. The `--network-plugin-mode` parameter modifies how Azure CNI allocates IPs and routes traffic, balancing simplicity, scalability, and compatibility with AKS features like NAP. As of May 2025, Azure CNI supports two primary modes: **Dynamic** (default) and **Overlay**. These modes determine whether pods use VNet IPs or a separate overlay address space, impacting networking behavior in AKS clusters.

### Available Network Plugin Modes

Below is a detailed explanation of the two network plugin modes available for `--network-plugin azure` in AKS.

#### 1. Dynamic (Default)
- **Description**: In Dynamic mode, Azure CNI assigns pod IPs directly from the subnet associated with the AKS cluster’s node pool within the Azure VNet. Each pod receives a unique IP address from the same subnet as the nodes, enabling direct routing without encapsulation.
- **Mechanics**:
  - **IP Allocation**: Pods are allocated IPs from the node pool’s subnet (e.g., `10.0.0.0/24`). Each node is pre-assigned a block of IPs (default: 30 IPs per node) to distribute to pods, managed dynamically by Azure CNI.
  - **Routing**: Pods communicate using native VNet routing, leveraging Azure’s network infrastructure without overlays or tunneling. Nodes act as routers for their pods’ IPs.
  - **Network Policies**: Supports Kubernetes `NetworkPolicy` via Azure Network Policy Manager or integrated CNIs like Calico (not Cilium in this mode).
- **Use Cases**:
  - **Enterprise Environments**: Ideal for clusters requiring seamless integration with Azure VNet services (e.g., Azure Firewall, Application Gateway) due to native VNet IPs.
  - **Hybrid Networking**: Suitable for scenarios needing direct connectivity between pods and on-premises or other Azure resources in the same VNet.
  - **Standard Workloads**: Fits clusters with moderate pod density where subnet IP availability is not a constraint.
- **Advantages**:
  - Native VNet integration simplifies connectivity with Azure services (e.g., Azure SQL, Storage).
  - High performance due to direct routing without encapsulation overhead.
  - Supports Azure Network Security Groups (NSGs) and User-Defined Routes (UDRs) for traffic control.
- **Limitations**:
  - Consumes VNet subnet IPs, which can lead to IP exhaustion in large clusters with many pods (e.g., thousands of pods requiring a large subnet like `10.0.0.0/16`).
  - Less scalable for high-density clusters due to IP allocation limits per node.
  - Not compatible with NAP when `--network-dataplane cilium` is used, as NAP requires `--network-plugin-mode overlay`.
- **AKS NAP Relevance**:
  - **Incompatible with NAP’s Cilium Requirement**: Your command specifies `--network-dataplane cilium`, which mandates `--network-plugin-mode overlay`. Dynamic mode cannot be used in this setup, as it does not support Cilium’s overlay-based networking for NAP.
  - **Alternative Use**: If NAP is not required or you switch to a non-Cilium dataplane (e.g., Azure Network Policy), Dynamic mode is the default for Azure CNI, offering robust VNet integration.
- **Example Command** (without NAP):
  ```powershell
  az aks create `
      -n my-cluster `
      -g my-resource-group `
      -c 2 `
      --network-plugin azure `
      --network-plugin-mode dynamic  # Explicitly set, though default
  ```

#### 2. Overlay
- **Description**: In Overlay mode, Azure CNI assigns pod IPs from a private, user-defined address space (e.g., `192.168.0.0/16`) separate from the VNet’s subnet. Pods communicate over an overlay network using VXLAN encapsulation, with nodes handling tunneling.
- **Mechanics**:
  - **IP Allocation**: Pods receive IPs from a private CIDR range specified during cluster creation (e.g., `--pod-cidr 192.168.0.0/16`). Node IPs remain in the VNet subnet (e.g., `10.0.0.0/24`), but pod IPs are independent, reducing VNet IP consumption.
  - **Routing**: Pod traffic is encapsulated using VXLAN and tunneled over the node’s VNet IPs. Azure CNI manages the virtual network overlay, with Cilium (required for NAP) handling eBPF-based packet processing.
  - **Network Policies**: Supports advanced network policies via Cilium’s `CiliumNetworkPolicy`, enabling Layer 3/4 and Layer 7 policy enforcement, as mandated by `--network-dataplane cilium`.
- **Use Cases**:
  - **High-Density Clusters**: Ideal for clusters with thousands of pods, as pod IPs do not consume VNet subnet space, avoiding IP exhaustion.
  - **NAP with Cilium**: Required for AKS clusters using NAP with `--network-dataplane cilium`, as in your command, due to its compatibility with dynamic node scaling and Cilium’s eBPF capabilities.
  - **Isolated Networking**: Suits scenarios where pod IPs should be isolated from the VNet for security or simplification.
- **Advantages**:
  - Highly scalable, supporting large clusters with minimal VNet subnet requirements (e.g., a small `/24` subnet for nodes suffices).
  - Reduces IP address conflicts by using a private pod CIDR, simplifying VNet planning.
  - Enables advanced security and observability with Cilium’s eBPF-based features, critical for NAP.
- **Limitations**:
  - VXLAN encapsulation introduces slight performance overhead compared to native routing in Dynamic mode.
  - Limited integration with Azure VNet services (e.g., NSGs, UDRs) for pod IPs, as they are in a private address space.
  - Requires Cilium for NAP, limiting CNI flexibility (e.g., cannot use Calico or Azure Network Policy).
- **AKS NAP Relevance**:
  - **Mandatory for NAP with Cilium**: Your command uses `--network-plugin-mode overlay`, which is required for NAP when `--network-dataplane cilium` is specified. Overlay mode aligns with NAP’s dynamic node provisioning, as it simplifies IP management for rapidly scaling nodes and leverages Cilium’s advanced networking.
  - **Configuration**: You must specify a pod CIDR when creating the cluster, as it’s not derived from the VNet subnet:
    ```powershell
    az aks create `
        -n nap `
        -g nap-rg `
        -c 2 `
        --node-provisioning-mode Auto `
        --network-plugin azure `
        --network-plugin-mode overlay `
        --network-dataplane cilium `
        --pod-cidr 192.168.0.0/16  # Defines private pod IP range
    ```

### Comparison Table

| **Feature**                  | **Dynamic (Default)**                              | **Overlay**                                        |
|------------------------------|----------------------------------------------------|----------------------------------------------------|
| **IP Allocation**            | Pod IPs from VNet subnet (e.g., `10.0.0.0/24`)     | Pod IPs from private CIDR (e.g., `192.168.0.0/16`) |
| **Routing**                  | Native VNet routing, no encapsulation              | VXLAN overlay, encapsulated over node IPs          |
| **Scalability**              | Limited by subnet IP availability                  | Highly scalable, independent of VNet subnet        |
| **Performance**              | High (no encapsulation)                            | Slightly lower (VXLAN overhead)                    |
| **VNet Integration**         | Strong (NSGs, UDRs, Azure services)                | Limited (pod IPs not in VNet)                      |
| **Network Policies**         | Azure Network Policy or Calico                     | Cilium (`CiliumNetworkPolicy`)                     |
| **NAP Compatibility**        | Not compatible with `--network-dataplane cilium`   | Required for NAP with `--network-dataplane cilium` |
| **Use Case**                 | Enterprise, VNet-integrated workloads              | High-density clusters, NAP with Cilium             |

### Practical Example in AKS with NAP

Your command creates an AKS cluster with NAP:
```powershell
az aks create -n nap -g nap-rg -c 2 --node-provisioning-mode Auto --network-plugin azure --network-plugin-mode overlay --network-dataplane cilium --pod-cidr 192.168.0.0/16
```
- **Overlay Mode**: Pods are assigned IPs from `192.168.0.0/16`, and nodes use VNet subnet IPs (e.g., `10.0.0.0/24`). Cilium manages VXLAN tunneling and eBPF-based networking, enabling NAP to dynamically provision nodes without VNet IP exhaustion.
- **Network Policy**: Apply a Cilium policy for security:
  ```yaml
  apiVersion: cilium.io/v2
  kind: CiliumNetworkPolicy
  metadata:
    name: restrict-api
  spec:
    endpointSelector:
      matchLabels:
        app: api
    ingress:
    - fromEndpoints:
      - matchLabels:
          app: frontend
      toPorts:
      - ports:
        - port: "80"
          protocol: TCP
  ```
- **Monitoring**: Verify pod IPs and Cilium status:
  ```powershell
  kubectl get pods -o wide  # Shows pod IPs in 192.168.0.0/16
  cilium status
  ```

**Dynamic Mode Alternative** (without NAP):
If you create a cluster without NAP:
```powershell
az aks create -n my-cluster -g my-resource-group -c 2 --network-plugin azure --network-plugin-mode dynamic
```
- Pods use VNet subnet IPs (e.g., `10.0.0.0/24`), requiring a larger subnet for many pods.
- Incompatible with `--network-dataplane cilium`, so you’d use Azure Network Policy or Calico instead.

### Choosing a Network Plugin Mode for AKS

- **Use Overlay** (Your setup):
  - **Why**: Required for NAP with `--network-dataplane cilium`, as in your command. Ideal for scalable, high-density clusters with dynamic node provisioning, leveraging Cilium’s eBPF capabilities.
  - **Best For**: NAP-enabled clusters, large-scale deployments, or environments needing isolated pod IPs.
- **Use Dynamic**:
  - **Why**: Default for Azure CNI, offering native VNet integration and high performance. Suitable for non-NAP clusters or when VNet connectivity is critical.
  - **Best For**: Enterprise workloads with Azure service integration, smaller clusters, or non-Cilium CNIs.

### Best Practices

- **Match NAP Requirements**: Use `--network-plugin-mode overlay` for NAP with `--network-dataplane cilium`, ensuring compatibility with Cilium’s overlay networking.
- **Plan Pod CIDR for Overlay**: Choose a non-overlapping private CIDR (e.g., `192.168.0.0/16`) to avoid conflicts with VNet or on-premises networks.
- **Size Subnets for Dynamic Mode**: For Dynamic mode, allocate a large enough VNet subnet (e.g., `/22` or larger) to accommodate pod IPs, especially in large clusters.
- **Monitor Networking**:
  - For Overlay: Use Cilium’s Hubble for observability:
    ```powershell
    cilium hubble ui
    ```
  - For Dynamic: Check pod IP allocation:
    ```powershell
    kubectl get pods -o wide
    ```
- **Test in Staging**: Validate the chosen mode in a non-production AKS cluster to assess performance and compatibility with NAP or other features.
- **Document Networking**: Record VNet and pod CIDR configurations to simplify troubleshooting and scaling.

### Limitations and Considerations

- **Overlay**:
  - VXLAN encapsulation may introduce latency in high-throughput workloads.
  - Limited VNet service integration for pod IPs requires additional configuration (e.g., NAT gateways).
  - Locked to Cilium for NAP, reducing CNI flexibility.
- **Dynamic**:
  - Subnet IP exhaustion risks in large clusters, requiring careful VNet planning.
  - Incompatible with NAP’s Cilium dataplane, limiting its use in your setup.
  - Higher complexity for hybrid networking scenarios.

By understanding the differences between Dynamic and Overlay modes, you can optimize your AKS cluster’s networking for NAP, ensuring scalability and compatibility with Cilium as specified in your setup.

## List of Abbreviations

This section provides a comprehensive list of abbreviations used throughout the Node Auto-Provisioning (NAP) guide for Azure Kubernetes Service (AKS), along with their expansions. These terms are specific to the context of AKS, NAP, Kubernetes networking, and related configurations.

- **AKS**: Azure Kubernetes Service
- **AS**: Autonomous System
- **BGP**: Border Gateway Protocol
- **CIDR**: Classless Inter-Domain Routing
- **CNI**: Container Network Interface
- **CRD**: Custom Resource Definition
- **eBPF**: Extended Berkeley Packet Filter
- **FTP**: File Transfer Protocol
- **gRPC**: Google Remote Procedure Call
- **HTTP**: Hypertext Transfer Protocol
- **IP**: Internet Protocol
- **mTLS**: Mutual Transport Layer Security
- **NAP**: Node Auto-Provisioning
- **NSG**: Network Security Group
- **OS**: Operating System
- **PDB**: Pod Disruption Budget
- **SQL**: Structured Query Language
- **TCP**: Transmission Control Protocol
- **UDP**: User Datagram Protocol
- **UDR**: User-Defined Route
- **VM**: Virtual Machine
- **VNet**: Virtual Network
- **VXLAN**: Virtual Extensible Local Area Network
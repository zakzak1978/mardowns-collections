# Azure CNI Overlay vs. Azure CNI Node Subnet: Migration Rationale

## Introduction
This document explains the differences between Azure CNI Node Subnet and Azure CNI Overlay networking models in Azure Kubernetes Service (AKS), outlines the reasons for migrating to Azure CNI Overlay, and addresses benefits, trade-offs, and additional considerations. The migration is driven by Microsoft’s recommendation for modern AKS deployments and the need to deploy Karpenter, an open-source autoscaler requiring Azure CNI Overlay. It covers Cilium’s role, clarifies IP allocation, provides guidance on using Cilium, and includes a diagram illustrating the networking model.

## What is Azure CNI Node Subnet?
Azure CNI Node Subnet is a flat networking model where nodes and pods share IPs from the same Azure Virtual Network (VNet) subnet.

- **How it works**:
  - Each AKS node gets an IP from the VNet subnet (e.g., `192.168.1.0/24`).
  - Each pod gets a unique IP from the same subnet.
  - Nodes reserve a block of IPs (e.g., 30 for pods + 1 for the node).
  - Pods communicate directly with VNet resources without Network Address Translation (NAT).
  - External traffic uses the node’s IP via NAT.

- **Example**:
  - Subnet: `192.168.1.0/24` (256 IPs).
  - Each node reserves 31 IPs, allowing ~8 nodes and 240 pods.
  - Node IP: `192.168.1.1`, Pod IP: `192.168.1.10`.

- **Key Characteristics**:
  - Direct VNet integration with low latency.
  - Requires significant IP planning to avoid exhaustion.

## What is Azure CNI Overlay?
Azure CNI Overlay is an overlay networking model where nodes use VNet subnet IPs, but pods use IPs from a separate, private CIDR range. It uses Cilium as the default Container Network Interface (CNI).

- **How it works**:
  - Nodes get IPs from the VNet subnet (e.g., `192.168.1.0/24`).
  - Pods get IPs from a user-defined private CIDR (e.g., `10.10.0.0/16`).
  - Each node gets a `/24` block (256 IPs, 254 usable) from the private CIDR, supporting up to 250 pods per node.
  - Pod-to-pod traffic is routed directly; external traffic uses Source Network Address Translation (SNAT) via the node’s IP.
  - External resources can’t reach pod IPs directly; a Load Balancer is needed.

- **Example**:
  - Nodes: `192.168.1.0/24` (~253 nodes, as ~3 IPs are reserved).
  - Pods: `10.10.0.0/16`, with each node getting a `/24` (e.g., `10.10.1.0/24`).
  - Pod IP: `10.10.1.10`, external traffic appears from node IP `192.168.1.5`.

- **Key Characteristics**:
  - Conserves VNet IPs, as only nodes use them.
  - Private CIDR is reusable across clusters.
  - Adds slight latency for external traffic due to SNAT.

## Why Migrate to Azure CNI Overlay?
The migration is driven by the following reasons:

1. **Microsoft’s Recommendation**:
   - Microsoft promotes Azure CNI Overlay as a preferred model for modern AKS deployments, especially for large-scale or IP-constrained environments. They provide a guided migration path (via AKS documentation or portal links like “Migrate to Azure CNI Overlay”), indicating optimization for scalability, IP efficiency, and compatibility with tools like Karpenter.
   - This aligns with industry trends toward overlay networking, simplifying IP management.

2. **Karpenter Requirement**:
   - Karpenter, an open-source Kubernetes autoscaler, requires Azure CNI Overlay in AKS. Karpenter dynamically provisions nodes, and Overlay’s scalable IP allocation supports large, dynamic clusters without VNet IP exhaustion.

## Understanding the Private CIDR
In Azure CNI Overlay, pods are assigned IPs from a **private CIDR**, a user-defined IP range separate from the VNet’s subnet (e.g., `10.10.0.0/16`).

- **What is a private CIDR?**
  - A CIDR defines a range of IPs using a base address and subnet mask (e.g., `/16`). In Overlay, this range is private, used only within the cluster, and not routable outside without SNAT.
  - It’s logical, managed by Cilium, and doesn’t consume VNet IPs, making it reusable across AKS clusters.

- **IP Capacity in `10.10.0.0/16`**:
  - A `/16` CIDR provides **65,536 IPs** (`2^(32-16) = 2^16`).
  - Two IPs are reserved (network and broadcast), leaving **65,534 usable IPs**.
  - Each node gets a `/24` block:
    - **256 IPs** per block (`2^(32-24) = 2^8`), with 254 usable.
    - Supports up to **250 pods per node** (to account for overhead).
  - The private CIDR supports **~256 nodes** (`65,536 ÷ 256`), each with 250 pods, totaling **~64,000 pods** theoretically.
  - **In your case**: Your VNet subnet is `192.168.1.0/24` (~253 node IPs), capping the cluster at **~253 nodes**, supporting **~63,250 pods** (`253 × 250`). The private CIDR has excess capacity.

- **How It Works with Your VNet `/24`**:
  - **Nodes**: Each node takes 1 IP from `192.168.1.0/24` (e.g., `192.168.1.4` for node 1). With ~253 usable IPs, you can have ~253 nodes.
  - **Pods**: Each node gets a `/24` block from `10.10.0.0/16` (e.g., `10.10.1.0/24` for node 1), providing 250 pod IPs.
  - The VNet subnet limits node count, but the private CIDR ensures ample pod IPs.

- **Avoiding Overlap**:
  - **Risk**: Overlap between the private CIDR and VNet, peered VNets, or on-premises networks causes routing conflicts.
  - **Solution**:
    - Inventory networks: VNet (`192.168.1.0/24`), peered VNets, on-premises ranges.
    - Choose a non-overlapping CIDR from RFC 1918 (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`). Example: Use `10.10.0.0/16` if your VNet is `192.168.1.0/24`.
    - Validate with Azure CLI (e.g., `--pod-cidr 10.10.0.0/16`) or portal.
    - Document all ranges to prevent conflicts.

## SNAT for Pods in Azure CNI Overlay
Source Network Address Translation (SNAT) is used when pods communicate outside the AKS cluster, such as to Azure services, on-premises resources, or the internet.

- **What is SNAT?**
  - SNAT rewrites the pod’s private IP to the node’s VNet IP for outgoing traffic.
  - Example: A pod with IP `10.10.1.10` on a node with IP `192.168.1.5` sends traffic to an external resource. The resource sees the traffic as coming from `192.168.1.5`, not `10.10.1.10`.
  - The node forwards responses from the external resource back to the pod.

- **Why is SNAT Needed?**
  - **Non-Routable Pod IPs**: Pods use private CIDR IPs (e.g., `10.10.1.10`), which are only valid within the cluster’s Cilium-managed network stack and not recognized by external networks.
  - **Routability**: SNAT ensures external systems can route responses back to the node’s VNet IP, which forwards them to the pod.
  - **IP Conservation**: Using a private CIDR for pods saves VNet IPs, as only nodes require routable IPs.
  - **Security**: Hides pod IPs from external networks, reducing exposure.
  - **Compatibility**: Enables pods to access external resources without direct VNet integration, unlike Azure CNI Node Subnet.

- **Use Case: Pods Communicating with an External Database**
  - **Scenario**: A web application running in an AKS cluster needs to query an Azure Database for PostgreSQL hosted in a separate VNet.
  - **Setup**:
    - **AKS Cluster**: Nodes in `192.168.1.0/24` (e.g., Node 1 at `192.168.1.5`), pods in `10.10.0.0/16` (e.g., Pod 1 at `10.10.1.10`).
    - **Database**: Azure Database for PostgreSQL in VNet `10.1.0.0/16`, IP `10.1.0.10`.
    - **Connectivity**: VNet peering between `192.168.0.0/16` (AKS) and `10.1.0.0/16` (database).
  - **Flow**:
    - The pod (`10.10.1.10`) sends a SQL query to the database (`10.1.0.10`).
    - SNAT translates the source IP to the node’s IP (`192.168.1.5`).
    - The database receives the query from `192.168.1.5` and responds to `192.168.1.5`.
    - The node forwards the response to the pod.
  - **Benefits**:
    - **Scalability**: Multiple pods share the node’s IP via SNAT, supporting high database traffic.
    - **Security**: The database only sees node IPs, simplifying firewall rules.
    - **IP Efficiency**: Pods use the private CIDR, conserving VNet IPs.
  - **Considerations**:
    - Configure the database’s network security group to allow traffic from `192.168.1.0/24`.
    - Monitor SNAT port usage with Cilium to avoid exhaustion under high traffic.

- **Implications**:
  - **Visibility**: External systems see node IPs, requiring firewall rules for node subnets (e.g., `192.168.1.0/24`).
  - **Port Management**: Azure assigns unique source ports for SNAT to avoid conflicts. High traffic may exhaust ports, mitigated by adding nodes or optimizing SNAT settings.
  - **Latency**: SNAT adds minimal overhead compared to Node Subnet’s direct routing.
  - **Access Control**: External resources must allow node IPs in their policies.

## Using Cilium in Azure CNI Overlay
Cilium is the default CNI in Azure CNI Overlay, leveraging eBPF (extended Berkeley Packet Filter) to provide high-performance networking, advanced security, and observability for AKS clusters.

- **Introduction to Cilium**:
  - Cilium is an open-source CNI that uses eBPF, a Linux kernel technology, to manage networking at the kernel level, offering:
    - **Efficient Networking**: Processes packets directly in the kernel, enabling fast pod-to-pod routing without overlays like VXLAN.
    - **Advanced Security**: Supports fine-grained network policies based on pod labels, namespaces, or HTTP-layer rules.
    - **Observability**: Provides detailed traffic insights (e.g., flow logs, latency, DNS queries), integrable with Prometheus and Grafana.
    - **Scalability**: Manages private CIDR IPs (e.g., `10.10.0.0/16`) efficiently, supporting large clusters and Karpenter’s dynamic scaling.
  - In Azure CNI Overlay, Cilium allocates pod IPs, handles routing, and facilitates SNAT for external traffic.

- **Example: Enforcing a Network Policy**:
  - **Scenario**: Restrict pod-to-pod traffic so only frontend pods (labeled `app=frontend`) can access backend pods (labeled `app=backend`) on port 8080, blocking all other traffic to backend pods.
  - **Setup**:
    - **AKS Cluster**: Nodes in `192.168.1.0/24`, pods in `10.10.0.0/16`.
    - **Frontend Pods**: Labeled `app=frontend` (e.g., `10.10.1.10` on Node 1).
    - **Backend Pods**: Labeled `app=backend` (e.g., `10.10.2.10` on Node 2).
  - **Cilium Network Policy YAML**:
    ```yaml
    apiVersion: cilium.io/v2
    kind: CiliumNetworkPolicy
    metadata:
      name: allow-frontend-to-backend
      namespace: default
    spec:
      endpointSelector:
        matchLabels:
          app: backend
      ingress:
      - fromEndpoints:
        - matchLabels:
            app: frontend
        toPorts:
        - ports:
          - port: "8080"
            protocol: TCP
    ```
  - **How It Works**:
    - The policy allows traffic from pods labeled `app=frontend` to pods labeled `app=backend` on TCP port 8080.
    - All other traffic to backend pods is denied.
    - Apply the policy using `kubectl apply -f policy.yaml`.
  - **Verification**:
    - Test connectivity: Frontend pod (`10.10.1.10`) can reach backend pod (`10.10.2.10:8080`); other pods cannot.
    - Use Cilium’s Hubble tool (`cilium hubble observe`) to monitor allowed/denied traffic.
  - **Benefits**:
    - **Security**: Prevents unauthorized access to backend pods.
    - **Granularity**: Policies can target specific labels or ports.
    - **Observability**: Hubble provides traffic flow insights.
  - **Considerations**:
    - Ensure pods have correct labels (`app=frontend`, `app=backend`).
    - Test policies in staging to avoid disrupting workloads.
    - Monitor with Hubble to troubleshoot policy issues.

## Diagram: Azure CNI Overlay Networking
This section references a diagram from Microsoft Learn illustrating Azure CNI Overlay networking, adapted to your setup. The diagram shows two nodes with their pod CIDRs and external connectivity via NAT:

- **Node 1 (192.168.1.4)**:
  - Runs the CNI Overlay plugin (Cilium).
  - Assigned a VNet IP: `192.168.1.4` from subnet `192.168.1.0/24`.
  - Manages pod CIDR: `10.10.1.0/24`, with pods:
    - Pod 1: `10.10.1.2`
    - Pod 2: `10.10.1.3`
    - Pod 3: `10.10.1.4`
- **Node 2 (192.168.1.5)**:
  - Runs the CNI Overlay plugin.
  - Assigned a VNet IP: `192.168.1.5` from subnet `192.168.1.0/24`.
  - Manages pod CIDR: `10.10.2.0/24`, with pods:
    - Pod 1: `10.10.2.2`
    - Pod 2: `10.10.2.3`
    - Pod 3: `10.10.2.4`
- **Overlay Network**: Pods use private IPs (e.g., `10.10.1.2` to `10.10.2.3`) for internal communication, managed by Cilium.
- **NAT**: External traffic from pods (e.g., `10.10.1.2`) is translated to node IPs (e.g., `192.168.1.4`) for access to Azure Services, the Internet, and On-Premises resources.
- **VNet (192.168.1.0/24)**: Provides IPs to nodes, part of a larger VNet range (e.g., `192.168.0.0/16`).
- **Image**: ![Azure CNI Overlay Diagram](https://learn.microsoft.com/en-us/azure/aks/media/azure-cni-overlay/azure-cni-overlay.png "Diagram of Azure CNI Overlay Networking"). The diagram visually represents nodes, pod CIDRs, NAT, and external connectivity as described.
- **Reference**: See the original diagram at https://learn.microsoft.com/en-us/azure/aks/azure-cni-overlay?tabs=kubectl for a visual representation.

This setup supports IP scalability (~63,250 pods with your `/24` VNet) and aligns with Karpenter’s requirements, as discussed in the migration rationale.

## Differences Between Azure CNI Node Subnet and Overlay
| Feature | Node Subnet | Overlay |
|---------|-------------|---------|
| **IP Allocation** | Nodes and pods share VNet IPs | Nodes use VNet IPs; pods use private CIDR |
| **Pod IP Scalability** | Limited (e.g., 240 pods in `/24`) | High (~63,250 pods with VNet `/24`) |
| **External Connectivity** | Direct VNet IPs | SNAT via node IPs |
| **IP Planning** | Large subnets needed | Minimal VNet IPs; reusable CIDR |
| **Latency** | Lower for VNet traffic | Slightly higher due to SNAT |
| **CNI** | Traditional Azure CNI | Cilium (eBPF-based) |
| **Karpenter Support** | Not supported | Supported |

## Pros and Cons of Azure CNI Overlay
### Pros
- **IP Scalability**: Minimal VNet IP usage, ideal for large clusters.
- **Karpenter Compatibility**: Supports dynamic autoscaling.
- **Reusable CIDR**: Simplifies multi-cluster setups.
- **Cilium Benefits**: Advanced security (e.g., network policies), observability, and performance.
- **Cost Efficiency**: Reduces network complexity costs.
- **Microsoft Backing**: Recommended for modern AKS.

### Cons
- **Slight Latency**: SNAT adds minor overhead.
- **Limited Pod Visibility**: Requires Load Balancers for external access.
- **Migration Effort**: Involves reconfiguration and potential downtime.
- **Cilium Learning Curve**: Requires familiarity with eBPF and network policies.

## Addressing Common Questions
1. **Why are we migrating?**
   - Microsoft recommends Azure CNI Overlay for scalable AKS, and it’s required for Karpenter autoscaling.

2. **How is Overlay different?**
   - Pods use a private CIDR, nodes use VNet IPs, SNAT for external traffic, and Cilium for advanced networking, unlike Node Subnet’s shared VNet IPs.

3. **What are the benefits?**
   - Scalability, Karpenter support, IP efficiency, and Cilium’s security and observability features.

4. **Are there downsides?**
   - Minor SNAT latency, migration effort, and Cilium learning curve, but benefits outweigh these.

5. **How does the private CIDR work?**
   - `10.10.0.0/16` provides ~65,534 IPs, with each node getting a `/24` block (250 pods). With a VNet `/24`, ~253 nodes support ~63,250 pods.

6. **How do we avoid IP overlap?**
   - Choose a private CIDR (e.g., `10.10.0.0/16`) that doesn’t conflict with VNet (`192.168.1.0/24`), peered VNets, or on-premises ranges, validated during setup.

7. **What does SNAT mean for workloads?**
   - External traffic (e.g., to an external database) uses node IPs, requiring firewall updates. SNAT enables pod communication with external resources with minimal latency.

8. **What does Cilium add?**
   - High-performance networking, fine-grained network policies (e.g., restricting frontend-to-backend traffic), and observability, ideal for Karpenter and production.

9. **Will it impact workloads?**
   - Migration needs planning to minimize downtime. Update services (e
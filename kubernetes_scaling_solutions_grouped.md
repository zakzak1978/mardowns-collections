<!-- filepath: d:\_studyarea\Markdowns\kubernetes_scaling_solutions.md -->
# Decision Questions for Kubernetes Scaling Solutions with KEDA-Specific Questions

This document includes two tables to evaluate scaling solutions for Kubernetes workloads, specifically for clients requiring either cloud-only deployments on Azure Kubernetes Service (AKS) or on-premises-only Kubernetes deployments. Our workloads are primarily stateless web apps built using Angular (e.g., single-page applications served via Nginx or integrated with .NET APIs) and .NET services (e.g., ASP.NET Core APIs or event-driven processors), with all databases hosted outside the Kubernetes cluster. This implies in-cluster workloads rely on external databases (e.g., via API calls or message queues) and are typically stateless or event-driven. The first table lists general questions to evaluate Horizontal Pod Autoscaler (HPA), KEDA, and Karpenter, showing which environments each solution supports. The second table lists KEDA-specific questions to determine if KEDA is the right choice; affirmative answers indicate KEDA should be used. Each **Decision Question** includes an example tailored to Angular web apps or .NET services.

## Decision Questions Table for Kubernetes Scaling Solutions

This table lists questions to evaluate HPA, KEDA, and Karpenter for our Angular web app and .NET service workloads. The **HPA**, **KEDA**, and **Karpenter** columns indicate whether the solution is supported in cloud (AKS) or on-premises environments.

| **Category** | **Decision Questions** | **HPA** | **KEDA** | **Karpenter** |
|---|---|---|---|---|
| **Workload Characteristics** | • What is the nature of our workload? (stateless or stateful)<br>• Do workloads scale based on resource usage or external events?<br>• Do we require scale-to-zero to save costs during inactivity?<br>• What is the expected scaling frequency and speed?<br>• Are workloads sensitive to node-level resource availability?<br><br>**Examples**:<br>• Stateless Angular web app (served via Nginx) vs. external stateful database (Azure SQL)<br>• CPU usage for Angular web app vs. Service Bus queue length for .NET service<br>• .NET service processing batch jobs idle overnight, supporting Angular app<br>• Angular web app with daily traffic spikes vs. real-time .NET service for queue processing<br>• .NET service for high-memory API processing, supporting Angular app | Cloud (AKS), On-Premises | Cloud (AKS), On-Premises | Cloud (AKS) |
| **Event-Driven Requirements** | • Do workloads depend on external event sources?<br>• How diverse are our event sources?<br>• Is event-driven scaling critical for our application?<br><br>**Examples**:<br>• Service Bus queue for .NET service processing orders, supporting Angular app<br>• Service Bus, Event Hubs, and Blob Storage triggers for .NET services supporting Angular app<br>• Real-time analytics .NET service on streaming data, supporting Angular app | Cloud (AKS), On-Premises | Cloud (AKS), On-Premises | Cloud (AKS) |
| **Cost Considerations** | • What is our budget for scaling operations?<br>• Can we afford temporary node over-provisioning?<br>• Is minimizing idle resource costs a priority?<br>• Are we optimizing for cost-efficient VM types?<br>• Do we have predictable workload patterns?<br><br>**Examples**:<br>• Limited budget for Angular web app querying external database<br>• E-commerce Angular web app during Black Friday sales<br>• Nightly batch .NET services supporting Angular app, idle during daytime<br>• Using spot instances for non-critical .NET services supporting Angular app<br>• Angular web app with steady daily traffic vs. sporadic .NET service for IoT data processing | Cloud (AKS), On-Premises | Cloud (AKS), On-Premises | Cloud (AKS) |
| **Operational Complexity** | • What is our team's expertise with Kubernetes?<br>• How much operational overhead are we willing to accept?<br>• Do we need simple setup and maintenance?<br><br>**Examples**:<br>• Small team new to Kubernetes vs. experienced DevOps team managing Angular apps and .NET services<br>• Minimal management for a startup's Angular app vs. full control for enterprise .NET services<br>• Quick deployment for Angular app MVP vs. robust system for production .NET services | Cloud (AKS), On-Premises | Cloud (AKS), On-Premises | Cloud (AKS) |
| **On-Premises Compatibility** | • Are we deploying on-premises Kubernetes?<br>• Do on-premises workloads rely on local event sources?<br>• How critical is on-premises support for our clients?<br><br>**Examples**:<br>• On-prem cluster for data privacy compliance, hosting Angular app and .NET services<br>• RabbitMQ for on-prem .NET service message queues supporting Angular app<br>• Government client requiring on-prem deployment for Angular app and .NET services | Cloud (AKS), On-Premises | Cloud (AKS), On-Premises | Cloud (AKS) |
| **AKS Integration** | • Are we using Azure-specific services?<br>• Are we comfortable with tools in preview?<br>• Do we require Azure-specific optimizations?<br><br>**Examples**:<br>• Azure Service Bus for .NET services supporting Angular app<br>• Adopting new AKS features for Angular app and .NET services innovation<br>• Cost Management for budget tracking of Angular app and .NET services | Cloud (AKS), On-Premises | Cloud (AKS), On-Premises | Cloud (AKS) |
| **Infrastructure Needs** | • Do we need to increase pods per node?<br>• Can we adjust VNet subnet (e.g., to /22)?<br>• Do nodes have sufficient CPU/memory for increased pod density?<br>• Are workloads dynamic, requiring frequent node additions/removals?<br><br>**Examples**:<br>• High-density Angular apps and .NET services (200 pods/node)<br>• Expanding AKS subnet for Angular app and .NET service pod density<br>• Running 200 Angular apps and .NET services on a single node<br>• CI/CD pipelines for Angular apps and .NET services with variable resource needs | Cloud (AKS), On-Premises | Cloud (AKS), On-Premises | Cloud (AKS) |
| **Monitoring and Metrics** | • What metrics are critical for scaling?<br>• Do we need fast metric-driven scaling?<br>• Are monitoring tools available?<br><br>**Examples**:<br>• CPU usage for Angular app vs. queue length for .NET service backend<br>• Real-time user activity tracking for Angular app via .NET service<br>• Grafana dashboards for Angular app and .NET service performance | Cloud (AKS), On-Premises | Cloud (AKS), On-Premises | Cloud (AKS) |
| **Strategic Goals** | • Are we prioritizing cost over performance?<br>• How future-proof should the solution be?<br>• Are clients planning to stay cloud-only or on-premises-only?<br><br>**Examples**:<br>• Budget-conscious startup with Angular app vs. high-performance .NET service for trading platform<br>• Long-term enterprise Angular/.NET app vs. short-term prototype<br>• Cloud-based SaaS Angular app vs. on-prem .NET services for compliance | Cloud (AKS), On-Premises | Cloud (AKS), On-Premises | Cloud (AKS) |

## Horizontal Pod Autoscaler (HPA)

### HPA Pros and Cons Table

| **Category** | **Pros** | **Cons** |
|---|---|---|
| **Workload Support** | • Simple for stateless Angular applications<br>• Supports external stateful applications with custom metrics | • Not optimized for event-driven .NET services<br>• No support for event-driven applications |
| **Scaling Mechanism** | • Scales on CPU/memory usage<br>• Reliable for steady workloads (~30s)<br>• Simple pod scaling on existing nodes | • No event-based scaling<br>• Slow for real-time bursts<br>• Limited by node capacity |
| **Cost Efficiency** | • Low cost (~$0.01/hour/pod in AKS)<br>• Predictable pod costs | • No scale-to-zero capability<br>• Idle pods add costs<br>• Minimum replicas required |
| **Operational Ease** | • Simple for new teams<br>• Low operational overhead<br>• Lightweight and ideal for MVP setup<br>• Native Kubernetes support | • Limited to resource-based scaling<br>• Limited scaling flexibility |
| **Environment Support** | • Works in both cloud and on-premises<br>• Excellent compatibility for government clients | • Limited event support on-premises<br>• Not applicable for event-based queues |
| **Integration** | • Strong Azure Monitor integration<br>• Mature tool in AKS<br>• Good Azure-specific optimizations | • Limited on-prem support for Azure services<br>• Limited optimization capabilities on-prem |
| **Infrastructure** | • Supports high-density workloads<br>• Works with VNet subnet planning | • Requires node monitoring<br>• Node capacity limits scaling |
| **Monitoring** | • Supports various metrics<br>• Compatible with Azure Monitor and Grafana | • No event metrics<br>• Limited to resource metrics |
| **Strategic Fit** | • Balances cost/performance<br>• Mature with strong community<br>• Works for cloud and on-prem deployments | • No scale-to-zero for cost-sensitive workloads<br>• Limited for event-driven prototypes<br>• Limited flexibility for specialized deployments |

## KEDA (Kubernetes Event-Driven Autoscaling)

### KEDA Pros and Cons Table

| **Category** | **Pros** | **Cons** |
|---|---|---|
| **Workload Support** | • Ideal for stateless event-driven .NET services<br>• Supports external stateful applications with triggers<br>• Dynamic pod scaling on existing nodes | • Needs event source for external stateful applications<br>• Limited by node capacity (memory constraints) |
| **Event Handling** | • Scales on events (Service Bus, RabbitMQ)<br>• Fast (~10s) scaling for real-time services<br>• Supports diverse event sources (Service Bus, Event Hubs) | • Requires event source configuration<br>• Dependent on event source latency<br>• Setup complexity for multiple sources |
| **Cost Efficiency** | • Very low cost with scale-to-zero<br>• Minimizes costs for idle .NET services<br>• Suits sporadic, event-driven workloads | • Event source costs (e.g., Service Bus)<br>• Limited by node capacity during spikes<br>• Requires event triggers for cost optimization |
| **Operational Aspects** | • Moderate operational expertise required<br>• Flexible for enterprises with .NET services<br>• Supports events for production services | • Requires Helm and event setup for new teams<br>• ScaledObjects add operational overhead<br>• Event source complexity for MVPs |
| **Environment Support** | • Works in both cloud and on-premises<br>• Supports local event sources (RabbitMQ)<br>• Good for on-premises .NET service queues | • Requires event source setup on-premises<br>• Event source dependency for on-premises<br>• Local sources needed on-prem for Azure services |
| **Azure Integration** | • Strong Service Bus integration in AKS<br>• Mature and stable for innovative services<br>• Strong Azure-specific optimizations | • No significant cons for AKS integration<br>• Limited to local sources on-prem |
| **Infrastructure** | • Supports high pod density in AKS<br>• Works with VNet subnet planning<br>• Allows monitoring of workload limits | • Requires node monitoring<br>• Not applicable on-prem for VNet adjustments<br>• Node capacity limits scaling |
| **Monitoring** | • Supports event-based metrics<br>• Fast real-time tracking via events<br>• Compatible with Azure Monitor and Grafana | • Event source setup for queue metrics<br>• Event source dependency for fast scaling<br>• Event source monitoring setup required |
| **Strategic Fit** | • Prioritizes cost with scale-to-zero<br>• Growing solution for various applications<br>• Excellent for both cloud and on-prem compliance | • Event-driven dependency for trading platforms<br>• Event source dependency for future-proofing<br>• Event source setup for deployment flexibility |

## Karpenter

### Karpenter Pros and Cons Table

| **Category** | **Pros** | **Cons** |
|---|---|---|
| **Workload Support** | • Handles stateless Angular apps via node scaling<br>• Scales nodes for unschedulable pods<br>• Provisions nodes for high-memory API processing | • Not supported on-premises without custom provider<br>• Not applicable for external stateful applications<br>• No pod scale-to-zero |
| **Scaling Mechanism** | • Handles bursts via node scaling (~90s)<br>• Terminates idle nodes in AKS<br>• Dynamic node provisioning | • Not metric/event-driven<br>• Slower than KEDA (~90s vs ~10s)<br>• Not event-driven |
| **Cost Efficiency** | • Moderate cost (~$0.10/hour/node)<br>• Optimizes node provisioning for traffic spikes<br>• Uses spot VMs for cost savings | • Higher costs during bursts<br>• Only available in cloud (AKS)<br>• No pod-level cost optimization |
| **Operational Aspects** | • Powerful for experienced teams<br>• Optimizes nodes for enterprise workloads<br>• Advanced for production in AKS | • Complex IAM and preview status<br>• High operational overhead (IAM, node management)<br>• Complex setup |
| **Environment Support** | • Only supported in cloud (AKS)<br>• Not viable for on-premises deployments | • Requires custom provider (e.g., vSphere) for on-premises<br>• Not viable for on-prem clients<br>• Not supported for on-prem compliance requirements |
| **Azure Integration** | • Integrates with VM scale sets (preview)<br>• Powerful for innovative AKS apps<br>• Strong Azure-specific optimizations | • Preview status for some AKS features<br>• Not supported on-premises for Azure services<br>• Cloud-only solution |
| **Infrastructure** | • Supports /22 subnet and node scaling<br>• Feasible with VNet, IAM in AKS<br>• Dynamic node scaling for CI/CD pipelines | • Not supported on-premises for infrastructure needs<br>• Not supported for VNet subnet adjustment on-prem<br>• Not supported for node management on-prem |
| **Monitoring** | • Scales on unschedulable pods<br>• Moderate (~90s) for node scaling<br>• Azure Monitor for node dashboards | • Not metric-driven for scaling metrics<br>• Not supported on-premises for monitoring<br>• Limited metric options compared to HPA |
| **Strategic Fit** | • Optimizes VM costs in AKS<br>• Growing solution for enterprise apps<br>• Best for cloud-based SaaS Angular apps | • Less suited for trading platforms requiring low latency<br>• Preview status limits future-proofing<br>• Not supported for on-prem .NET compliance |

## KEDA-Specific Decision Questions Table

This table lists questions to determine if KEDA is the appropriate scaling solution for our Angular web app and .NET service workloads. Affirmative answers to these questions indicate KEDA should be used.

| **Decision Questions** |
|---|
| • Are our workloads primarily event-driven, requiring scaling based on external triggers?<br>• Do we need scale-to-zero to eliminate costs during periods of no activity?<br>• Are we using or planning to use supported event sources like Azure Service Bus, RabbitMQ, or Kafka?<br>• Do we require fast scaling (within ~10 seconds) for bursty workloads?<br>• Are we comfortable managing additional configuration for event-driven scaling?<br><br>**Examples**:<br>• Scaling a .NET service on Azure Service Bus or RabbitMQ queue backlog for Angular app backend<br>• Serverless-style .NET service idle during off-hours, supporting Angular app<br>• Processing real-time data streams from Kafka for .NET services<br>• Real-time analytics .NET service for Angular app responding to sudden data spikes<br>• Configuring ScaledObjects for a Service Bus trigger in .NET services |

## Using the Tables
- **Team Discussion**: Share to align on client requirements for cloud-only (AKS) or on-premises-only deployments of Angular web apps and .NET services.
- **Workload Mapping**: Use the **KEDA-Specific Decision Questions Table** to determine if KEDA is suitable for .NET services; affirmative answers indicate KEDA is the right choice. Use the **Decision Questions Table** to evaluate HPA, KEDA, and Karpenter for broader Angular/.NET requirements.
- **Evaluate Trade-offs**: Combine with the PoC recommendation matrix to compare pros, cons, and costs for HPA, KEDA, and Karpenter.
- **Validate with Tests**: Test in AKS for cloud clients and on-premises (e.g., Minikube, vSphere) for on-prem clients, using Angular apps (e.g., Nginx serving SPA) and .NET services (e.g., ASP.NET Core APIs).

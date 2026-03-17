Steps to Self-Host KEDA on AKS:

## Step 1: Add the KEDA Helm Repository

First, you need to add the official KEDA Helm chart repository to your Helm client.

```bash
helm repo add kedacore https://kedacore.github.io/charts
```

Update the repository to get the latest chart information:

```bash
helm repo update
```

## Step 2: Create a Namespace for KEDA

It's a best practice to install KEDA in its own namespace.

```bash
kubectl create namespace keda
```

## Step 3: Install KEDA

Install KEDA using Helm. You can use the latest version available.

```bash
helm install keda kedacore/keda --namespace keda
```

### Alternative: Install with Specific Version

If you need to install a specific version of KEDA:

```bash
helm install keda kedacore/keda --namespace keda --version=2.12.0
```

## Step 4: Verify the Installation

Check if KEDA is deployed successfully by verifying the pods:

```bash
kubectl get pods -n keda
```

You should see output similar to:

```
NAME                                      READY   STATUS    RESTARTS   AGE
keda-admission-webhooks-65bf4f7986-xglrr  1/1     Running   0          2m
keda-operator-6988d7c5c5-lvmhs           1/1     Running   0          2m
keda-metrics-apiserver-8679f8f75-pqkdn   1/1     Running   0          2m
```

Verify that KEDA Custom Resource Definitions (CRDs) are installed:

```bash
kubectl get crd | grep keda.sh
```

You should see output similar to:

```
clustertriggerauthentications.keda.sh                  2023-06-15T10:12:45Z
scaledjobs.keda.sh                                     2023-06-15T10:12:45Z
scaledobjects.keda.sh                                  2023-06-15T10:12:45Z
triggerauthentications.keda.sh                         2023-06-15T10:12:45Z
```

### Understanding KEDA CRDs

Each KEDA CRD serves a specific purpose in the event-driven autoscaling ecosystem:

1. **ScaledObjects (scaledobjects.keda.sh)**:
   - Primary resource for scaling long-running applications (deployments, statefulsets)
   - Defines scaling triggers, min/max replica counts, and cooldown periods
   - Links to a target deployment that should be scaled based on events

2. **ScaledJobs (scaledjobs.keda.sh)**:
   - Used for event-driven jobs rather than long-running services
   - Creates Kubernetes Jobs based on defined triggers
   - Useful for batch processing or one-time tasks triggered by events

3. **TriggerAuthentications (triggerauthentications.keda.sh)**:
   - Namespace-scoped resource for storing authentication parameters
   - Defines how to authenticate with external event sources (queues, topics, etc.)
   - Can reference Kubernetes secrets, environment variables, or pod identities
   - Reusable across multiple ScaledObjects/ScaledJobs within the same namespace

4. **ClusterTriggerAuthentications (clustertriggerauthentications.keda.sh)**:
   - Cluster-wide version of TriggerAuthentications
   - Can be referenced by ScaledObjects/ScaledJobs across all namespaces
   - Useful for centralized authentication management

## Step 5: Using KEDA ScaledObjects

After installation, you can create ScaledObjects to define event-driven scaling for your deployments. Here's an example of a ScaledObject for an Azure Service Bus queue:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: azure-servicebus-queue-scaledobject
  namespace: default
spec:
  scaleTargetRef:
    name: your-deployment-name  # Reference to your Kubernetes deployment
  pollingInterval: 30           # How frequently to check metrics (seconds)
  cooldownPeriod: 300          # Period to wait after scale down activity (seconds)
  minReplicaCount: 1           # Minimum replica count
  maxReplicaCount: 10          # Maximum replica count
  triggers:
  - type: azure-servicebus
    metadata:
      queueName: your-queue-name
      connectionFromEnv: SERVICEBUS_CONNECTIONSTRING
      messageCount: '5'        # Target 5 messages per pod
```

## Step 6: Monitoring KEDA

Monitor your ScaledObjects to see if they're working as expected:

```bash
kubectl get scaledobject -A
```

Check the scaling events:

```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

## Step 7: Updating KEDA

To update KEDA to the latest version:

First, update your Helm repository:
```bash
helm repo update
```

Then upgrade KEDA installation:
```bash
helm upgrade keda kedacore/keda --namespace keda
```

## Step 8: Managing KEDA Resources

After installing KEDA, you can manage your resources with these commands:

### Working with ScaledObjects

Get information about all deployed ScaledObjects:

```bash
kubectl get scaledobject --namespace <namespace>
```

Get details about a specific ScaledObject:

```bash
kubectl describe scaledobject <scaled-object-name> --namespace <namespace>
```

### Working with TriggerAuthentications

Get information about all TriggerAuthentications:

```bash
kubectl get triggerauthentication --namespace <namespace>
```

Get details about a specific TriggerAuthentication:

```bash
kubectl describe triggerauthentication <trigger-authentication-name> --namespace <namespace>
```

### View KEDA's Horizontal Pod Autoscalers

KEDA works by creating Horizontal Pod Autoscalers (HPAs) behind the scenes. You can view them with:

```bash
kubectl get hpa --namespace <namespace>
```

View HPAs across all namespaces:

```bash
kubectl get hpa --all-namespaces
```

### Additional Resources

Get started by deploying ScaledObjects to your cluster:
- Information about KEDA concepts: https://keda.sh/docs/latest/concepts/
- Sample implementations: https://github.com/kedacore/samples

## Step 9: KEDA Metrics Server Integration

KEDA ships with its own metrics server that can be queried to see the current metrics values that are driving your autoscaling decisions:

```bash
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1/namespaces/<namespace>/your-metric-name" | jq .
```

Note: This requires `jq` to be installed for formatting the JSON output.

## Step 10: Uninstalling KEDA

If you need to remove KEDA from your cluster:

```bash
helm uninstall keda --namespace keda
```

Optionally, remove the namespace as well:

```bash
kubectl delete namespace keda
```

## Common Troubleshooting

If you encounter issues with KEDA deployment:

1. Check KEDA operator logs:
   ```bash
   kubectl logs -l app=keda-operator -n keda
   ```
   
   Check KEDA metrics API server logs:
   ```bash
   kubectl logs -l app=keda-metrics-apiserver -n keda
   ```

2. Verify Custom Resource Definitions:
   ```bash
   kubectl get crd | grep keda
   ```

3. Check ScaledObject status:
   ```bash
   kubectl describe scaledobject <scaled-object-name> -n <namespace>
   ```

For more detailed information on KEDA configuration and available scalers, refer to the [official KEDA documentation](https://keda.sh/docs/).

## Choosing Between ScaledObject and ScaledJob

KEDA provides two primary resource types for event-driven scaling: `ScaledObject` and `ScaledJob`. Understanding the differences between them is crucial for implementing the right scaling solution for your workloads.

### ScaledObject vs. ScaledJob: A Comparison

| Feature | ScaledObject | ScaledJob |
|---------|-------------|-----------|
| Target Resource | Deployments, StatefulSets, Custom Resources | Kubernetes Jobs |
| Process Type | Long-running services | Batch/one-time tasks |
| Scaling Behavior | Scales pods up and down based on event load | Creates individual Jobs for each batch of events |
| State | Stateful or stateless | Should be stateless |
| Completion | Services continue running | Jobs complete and terminate |
| Execution Model | One deployment with multiple replicas | Multiple independent Jobs |
| Job History | N/A | Configurable history retention for completed Jobs |

### When to Use ScaledObject

Use a **ScaledObject** when:

1. **You have a long-running service** that needs to process events continuously
   ```bash
   # Example: An API service that processes requests
   ```

2. **Your application maintains in-memory state** between event processing
   ```bash
   # Example: A service that caches data for multiple event processing
   ```

3. **Events need to be processed in real-time** with minimal startup delay
   ```bash
   # Example: Real-time analytics processing
   ```

4. **You need consistent scaling behavior** with predictable pod identity
   ```bash
   # Example: Services that need stable network identities
   ```

5. **Your application operates as a listener/consumer** continuously processing a stream
   ```bash
   # Example: Stream processing applications
   ```

Example ScaledObject use case:
```yaml
# A microservice API that scales based on queue length
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: orders-api-scaler
spec:
  scaleTargetRef:
    name: orders-api
    apiVersion: apps/v1
    kind: Deployment
  minReplicaCount: 1
  maxReplicaCount: 20
  triggers:
  - type: rabbitmq
    metadata:
      queueName: orders
      queueLength: "50"
```

### When to Use ScaledJob

Use a **ScaledJob** when:

1. **You have batch processing workloads** that complete a task and terminate
   ```bash
   # Example: Image processing jobs
   ```

2. **Each event requires significant processing time** and independent execution
   ```bash
   # Example: ML model training jobs
   ```

3. **You need isolation between event processing tasks**
   ```bash
   # Example: Jobs with different security contexts
   ```

4. **Your workload has clear start and completion states**
   ```bash
   # Example: Data import jobs
   ```

5. **You need to maintain job history** for audit or tracking purposes
   ```bash
   # Example: Regulatory compliance jobs requiring history
   ```

Example ScaledJob use case:
```yaml
# Image processing job that creates a new job instance for each batch of images
apiVersion: keda.sh/v1alpha1
kind: ScaledJob
metadata:
  name: image-processor
spec:
  jobTargetRef:
    template:
      spec:
        containers:
        - name: image-processor
          image: myregistry/image-processor:v1
          resources:
            requests:
              cpu: 1
              memory: 1Gi
        restartPolicy: Never
  pollingInterval: 30
  successfulJobsHistoryLimit: 5
  failedJobsHistoryLimit: 10
  maxReplicaCount: 100
  triggers:
  - type: azure-blob
    metadata:
      blobContainerName: images-to-process
      blobCount: "5"
```

### Hybrid Approaches

In some cases, you might use both ScaledObject and ScaledJob together:

1. **ScaledObject for the API layer** handling requests
2. **ScaledJob for heavy processing tasks** initiated by the API

```
┌─────────────────┐         ┌─────────────┐
│  External Event │─────────▶│ ScaledObject│─┐
└─────────────────┘         │ (API Layer) │ │
                            └─────────────┘ │
                                            │
                                            ▼
                            ┌─────────────────┐
                            │  Message Queue  │
                            └────────┬────────┘
                                     │
                                     ▼
                            ┌─────────────────┐
                            │   ScaledJob     │
                            │(Heavy Processing)│
                            └─────────────────┘
```

### Decision Framework

To decide which to use, ask yourself:

1. **Is this a continuous service or a discrete task?**
   - Continuous → ScaledObject
   - Discrete → ScaledJob

2. **Do you need to preserve state between event processing?**
   - Yes → ScaledObject
   - No → Either option works

3. **Is processing isolated per event/batch?**
   - Yes → ScaledJob is better suited
   - No → ScaledObject may be more efficient 

4. **Do you need job history?**
   - Yes → ScaledJob
   - No → Either option works

## KEDA vs. Standard Kubernetes HPA: When to Choose Each

Kubernetes provides a built-in Horizontal Pod Autoscaler (HPA), but KEDA extends its capabilities significantly. Understanding when to use KEDA over standard HPA is crucial for effective autoscaling in your cluster.

### Feature Comparison: KEDA vs. Standard HPA

| Feature | Standard Kubernetes HPA | KEDA |
|---------|------------------------|------|
| CPU Scaling | ✓ | ✓ |
| Memory Scaling | ✓ | ✓ |
| Custom Metrics API | ✓ | ✓ |
| External Metrics API | Limited | ✓ (Extended) |
| Event-driven Sources | ✗ | ✓ (40+ scalers) |
| Scale to Zero | ✗ | ✓ |
| Job Scaling | ✗ | ✓ (ScaledJob) |
| Multiple Metrics | ✓ (AND logic) | ✓ (OR logic) |
| Authentication to External Systems | ✗ | ✓ |
| Required Prometheus | Often | Not Required |
| Setup Complexity | Moderate | Simple |

### When to Use Standard Kubernetes HPA

Use the standard Kubernetes HPA when:

1. **You only need CPU and Memory-based scaling**
   ```bash
   # Standard CPU-based HPA is sufficient
   kubectl autoscale deployment my-app --cpu-percent=80 --min=1 --max=10
   ```

2. **Your metrics are already available via the Kubernetes Metrics API**
   ```bash
   # Example: Metrics that Kubernetes already collects
   ```

3. **You have Prometheus metrics and a Prometheus adapter already configured**
   ```bash
   # Example: Using existing Prometheus metrics for scaling
   ```

4. **You prefer using only native Kubernetes resources without additional operators**
   ```bash
   # Example: Environments with strict limitations on custom resources
   ```

5. **You always need at least one pod running (no scale to zero)**
   ```bash
   # Example: Critical services that must always be available
   ```

Example standard HPA:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80
```

### When to Choose KEDA over Standard HPA

Choose KEDA when:

1. **You need to scale based on external event sources**
   ```bash
   # Example: Message queues, databases, or 3rd party APIs
   ```

2. **You want to scale to zero when there are no events to process**
   ```bash
   # Example: Cost optimization for event processors 
   ```

3. **You need to authenticate to external systems to get metrics**
   ```bash
   # Example: Accessing queue depths in authenticated services
   ```

4. **You need batch job scaling based on events (ScaledJob)**
   ```bash
   # Example: Processing jobs that should only run when events arrive
   ```

5. **You want simpler configuration for external metrics**
   ```bash
   # Example: Avoiding complex Prometheus adapter configuration
   ```

6. **You need to scale on multiple metrics with OR logic**
   ```bash
   # Example: Scale when EITHER queue depth OR CPU is high
   ```

7. **You need specialized scaling logic for specific systems**
   ```bash
   # Example: Azure Service Bus, Kafka, RabbitMQ, PostgreSQL, etc.
   ```

8. **You want fine-grained control over scaling behavior**
   ```bash
   # Example: Different cooldown periods, custom polling intervals
   ```

Example KEDA ScaledObject:
```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: my-app-scaler
spec:
  scaleTargetRef:
    name: my-app
  minReplicaCount: 0  # Scale to zero when no events
  maxReplicaCount: 10
  triggers:
  - type: kafka
    metadata:
      bootstrapServers: kafka:9092
      consumerGroup: my-group
      topic: my-topic
      lagThreshold: "10"
  - type: cpu  # Can still use CPU alongside event-based scaling
    metadata:
      type: Utilization
      value: "80"
```

### Decision Framework: Standard HPA or KEDA?

To decide which autoscaling solution to use, consider these questions:

1. **What metrics drive your scaling decisions?**
   - Just CPU/Memory → Standard HPA is sufficient
   - External events/services → KEDA is better suited

2. **Do you need to scale to zero?**
   - Yes → KEDA is required
   - No → Either option works

3. **Are you using cloud services or messaging systems?**
   - Yes → KEDA provides ready-made scalers
   - No → Standard HPA may be sufficient

4. **How complex is your scaling logic?**
   - Simple, resource-based → Standard HPA
   - Complex, event-driven → KEDA

5. **Do you need to scale batch jobs based on events?**
   - Yes → KEDA (ScaledJob) is required
   - No → Standard HPA may be sufficient

## Example Workflow: Autoscaling with Azure Service Bus Queues

This example demonstrates a complete workflow for setting up KEDA autoscaling with Azure Service Bus queues, based on the [official KEDA sample](https://github.com/kedacore/sample-dotnet-worker-servicebus-queue/blob/main/connection-string-scenario.md).

### Step 1: Set Up Azure Service Bus

First, create an Azure Service Bus namespace and queue:

```bash
# Create a resource group
az group create --name rg_karpenter --location westeurope
```

```bash
# Create a Service Bus namespace
az servicebus namespace create \
  --resource-group rg_karpenter \
  --name kedaservicebus \
  --location westeurope \
  --sku Basic
```

```bash
# Create a Service Bus queue
az servicebus queue create \
  --resource-group rg_karpenter \
  --namespace-name kedaservicebus \
  --name orders
```

Create two authorization rules - one for your application to listen to the queue and another for KEDA to monitor the queue:

```bash
# Create a listen-only rule for the consumer application
az servicebus queue authorization-rule create \
  --resource-group rg_karpenter \
  --namespace-name kedaservicebus \
  --queue-name orders \
  --name order-consumer \
  --rights Listen
```

```bash
# Create a management rule for KEDA to monitor the queue
az servicebus queue authorization-rule create \
  --resource-group rg_karpenter \
  --namespace-name kedaservicebus \
  --queue-name orders \
  --name keda-monitor \
  --rights Manage Send Listen
```

Get the consumer connection string that your application will use:

```bash
az servicebus queue authorization-rule keys list \
  --resource-group rg_karpenter \
  --namespace-name kedaservicebus \
  --queue-name orders \
  --name order-consumer \
  --query primaryConnectionString \
  --output tsv
```

Get the management connection string that KEDA will use:

```bash
az servicebus queue authorization-rule keys list \
  --resource-group rg_karpenter \
  --namespace-name kedaservicebus \
  --queue-name orders \
  --name keda-monitor \
  --query primaryConnectionString \
  --output tsv
```

### Step 2: Create a Kubernetes Namespace and Secrets

Create a namespace for your KEDA application:

```bash
kubectl create namespace keda
```

Create secrets for both connection strings:

```bash
# Create secret for the application connection string
kubectl create secret generic secrets-order-consumer \
  --namespace keda \
  --from-literal=servicebus-connection-string="<your-consumer-connection-string>"
```

```bash
# Create secret for the KEDA monitoring connection string
kubectl create secret generic secrets-order-management \
  --namespace keda \
  --from-literal=servicebus-order-management-connectionstring="<your-management-connection-string>"
```

### Step 3: Deploy a Message Consumer Application

Create a deployment for your application that will process messages:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keda-orderprocessor
spec:
  replicas: 1
  selector:
    matchLabels:
      app: keda-orderprocessor
  template:
    metadata:
      labels:
        app: keda-orderprocessor
    spec:
      containers:
      - name: keda-orderprocessor
        image: karpeacr.azurecr.io/keda-orderprocessor:v4
        env:
        - name: KEDA_SERVICEBUS_QUEUE_NAME
          value: orders
        - name: KEDA_SERVICEBUS_AUTH_MODE
          value: ConnectionString
        - name: KEDA_SERVICEBUS_QUEUE_CONNECTIONSTRING
          valueFrom:
            secretKeyRef:
             name: secrets-order-consumer
             key: servicebus-connectionstring
---
apiVersion: v1
kind: Secret
metadata:
  name: secrets-order-consumer
  labels:
    app: keda-orderprocessor
data:
  servicebus-connectionstring: RW5kcG9pbnQ9c2I6Ly9rZWRhc2VydmljZWJ1cy5zZXJ2aWNlYnVzLndpbmRvd3MubmV0LztTaGFyZWRBY2Nlc3NLZXlOYW1lPW9yZGVyLWNvbnN1bWVyO1NoYXJlZEFjY2Vzc0tleT1qbkdNSk03aStvVFdreDlnMWR2THZnTTdzbHRnc0R4OUQrQVNiQ3BEWW9rPTtFbnRpdHlQYXRoPW9yZGVycw==
```

Save this as `deploy-app.yaml` and apply it:

```bash
kubectl apply -f deploy-app.yaml --namespace keda
```

Verify the deployment is running:

```bash
kubectl get deployments --namespace keda
```

You should see one replica running:

```
NAME              DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
order-processor   1         1         1            1           49s
```

### Step 4: Set Up KEDA Autoscaling for Service Bus Queue

Create a file named `deploy-autoscaling.yaml` that includes both the TriggerAuthentication and ScaledObject:

```yaml
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: trigger-auth-service-bus-orders
  namespace: keda
spec:
  secretTargetRef:
    - parameter: connection
      name: secrets-order-consumer
      key: servicebus-connectionstring
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: keda-orderprocessor-scaler
  namespace: keda
  labels:
    app: keda-orderprocessor
    name: keda-orderprocessor
spec:
  scaleTargetRef:
    name: keda-orderprocessor
  minReplicaCount: 0  # Scale to zero when no messages
  maxReplicaCount: 10 # Don't scale beyond 10 replicas
  pollingInterval: 15 # Check for messages every 15 seconds
  cooldownPeriod: 300 # Wait 5 minutes before scaling down
  triggers:
  - type: azure-servicebus
    metadata:
      queueName: orders
      queueLength: '5'  # Target 5 messages per pod
    authenticationRef:
      name: trigger-auth-service-bus-orders
```

Apply the KEDA autoscaling resources:

```bash
kubectl apply -f deploy-autoscaling.yaml --namespace keda
```

After applying, check the deployment again:

```bash
kubectl get deployments --namespace keda -o wide
```

You should see that KEDA scaled the deployment to 0 pods since there are no messages in the queue:

```
NAME              DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
order-processor   0         0         0            0           3m
```

### Step 5: Generate Test Messages for the Queue

To test the autoscaler, create a .NET Core application that can send messages to the Azure Service Bus. You can use the sample from the KEDA repo:

```bash
# Clone the repo
git clone https://github.com/kedacore/sample-dotnet-worker-servicebus-queue
cd sample-dotnet-worker-servicebus-queue
```

Open `src/OrderGenerator/Program.cs` and update the connection string to use a connection string with `Send` permissions:

```bash
# Create a send-only rule for the producer application
az servicebus queue authorization-rule create \
  --resource-group rg_karpenter \
  --namespace-name kedaservicebus \
  --queue-name orders \
  --name order-sender \
  --rights Send

# Get connection string
az servicebus queue authorization-rule keys list \
  --resource-group rg_karpenter \
  --namespace-name kedaservicebus \
  --queue-name orders \
  --name order-sender \
  --query primaryConnectionString \
  --output tsv
```

Run the order generator to send test messages:

```bash
dotnet run --project src/OrderGenerator/OrderGenerator.csproj
```

When prompted, enter the number of messages you want to send (e.g., 300):

```
Let's queue some orders, how many do you want?
300
Queuing order 719a7b19-f1f7-4f46-a543-8da9bfaf843d - A Hat for Reilly Davis
Queuing order 5c3a954c-c356-4cc9-b1d8-e31cd2c04a5a - A Salad for Savanna Rowe
[...]
That's it, see you later!
```

### Step 6: Observe the Autoscaling in Action

Once you've sent messages to the queue, watch KEDA scale up the deployment:

```bash
kubectl get deployments --namespace keda -o wide -w
```

You should see the number of pods increase based on the queue depth:

```
NAME              DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
order-processor   8         8         8            4           1m
```

As more messages get processed, you may see the deployment scale up to the maximum of 10 pods:

```bash
kubectl get pods --namespace keda
```

```
NAME                               READY   STATUS    RESTARTS   AGE
order-processor-65d5dd564-9wbph    1/1     Running   0          54s
order-processor-65d5dd564-czlqb    1/1     Running   0          39s
order-processor-65d5dd564-h2l5l    1/1     Running   0          54s
order-processor-65d5dd564-h6fcl    1/1     Running   0          24s
order-processor-65d5dd564-httnf    1/1     Running   0          1m
order-processor-65d5dd564-j64wq    1/1     Running   0          54s
order-processor-65d5dd564-ncwfd    1/1     Running   0          39s
order-processor-65d5dd564-q7tkt    1/1     Running   0          39s
order-processor-65d5dd564-t2g6x    1/1     Running   0          24s
order-processor-65d5dd564-v79x6    1/1     Running   0          39s
```

You can view the logs of the consumer pods to see messages being processed:

```bash
kubectl logs -f deploy/order-processor --namespace keda
```

Example output:
```
info: OrderProcessor.OrdersQueueProcessor[0]
      Starting message pump at: 06/03/2025 12:32:14 +00:00
info: OrderProcessor.OrdersQueueProcessor[0]
      Message pump started at: 06/03/2025 12:32:14 +00:00
info: OrderProcessor.OrdersQueueProcessor[0]
      Received message 513b896fbe3b4085ad274d9c23e01842 with body {"Id":"7ff54254-a370-4697-8115-134e55ebdc65","Amount":1741776525,"ArticleNumber":"Chicken","Customer":{"FirstName":"Myrtis","LastName":"Balistreri"}}
info: OrderProcessor.OrdersQueueProcessor[0]
      Processing order 7ff54254-a370-4697-8115-134e55ebdc65 for 1741776525 units of Chicken bought by Myrtis Balistreri at: 06/03/2025 12:32:15 +00:00
info: OrderProcessor.OrdersQueueProcessor[0]
      Order 7ff54254-a370-4697-8115-134e55ebdc65 processed at: 06/03/2025 12:32:17 +00:00
```

### Step 7: Understanding the Autoscaling Flow

Let's break down how KEDA manages the autoscaling process:

#### System Architecture

The overall architecture of our KEDA-based Azure Service Bus scaling solution:

```
┌───────────────────────┐     ┌────────────────────┐     ┌──────────────────┐
│                       │     │                    │     │                  │
│  Order Generator App  ├────►│ Azure Service Bus  │◄────┤  KEDA Metrics    │
│  (Message Producer)   │     │  Queue (orders)    │     │    Adapter       │
│                       │     │                    │     │                  │
└───────────────────────┘     └────────────────────┘     └──────┬───────────┘
                                                               │
                                                               │
                                                               ▼
┌───────────────────────┐     ┌────────────────────┐     ┌──────────────────┐
│                       │     │                    │     │                  │
│  Order Processor Pods │◄────┤ Kubernetes HPA    │◄────┤  KEDA Operator   │
│  (Message Consumers)  │     │                    │     │                  │
│                       │     │                    │     │                  │
└───────────────────────┘     └────────────────────┘     └──────────────────┘
```

#### Autoscaling Process

1. **The Order Generator sends messages to the Azure Service Bus queue**
   - Each message represents an order to be processed

2. **KEDA Metrics Adapter monitors the queue length**
   - Polls the Azure Service Bus Queue every 15 seconds (as configured)
   - Authenticates using the management connection string from the secret

3. **KEDA calculates target replica count**
   - Divides the queue length by the `queueLength` parameter (5 in our example)
   - For example, 100 messages would result in 20 target replicas (100 ÷ 5 = 20)
   - Maximum replicas are capped by `maxReplicaCount` (10 in our example)

4. **KEDA updates the Horizontal Pod Autoscaler (HPA)**
   - Creates/updates an HPA resource for the deployment
   - Sets the target metric value based on the queue length

5. **Kubernetes HPA scales the deployment**
   - Increases/decreases the replica count based on KEDA's target
   - Each pod processes messages from the queue in parallel

6. **Consumer Pods process messages**
   - Each Order Processor pod connects to the queue using the consumer connection string
   - Processes messages at the rate specified (2 seconds per message in our example)

7. **Scale to Zero**
   - When queue is empty, KEDA reports zero target replicas
   - After cooldown period (5 minutes in our example), pods are scaled to zero
   - Resources are freed until new messages arrive

### Step 7: Monitoring the Autoscaling

You can monitor the scaling behavior with these commands:

```bash
# Watch the HPA that KEDA created
kubectl get hpa -w
```

```bash
# See the number of pods scaling up/down
kubectl get pods -l app=keda-orderprocessor -w
```

```bash
# Check the KEDA metrics for the queue
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1/namespaces/default/azure-servicebus-myqueue" | jq .
```

```bash
# View the ScaledObject status
kubectl describe scaledobject servicebus-scaledobject
```

Watch the pods scale up in response:

```bash
kubectl get pods -l app=keda-orderprocessor -w
```

### Performance Considerations

1. **Cold Start Latency**: 
   - When scaling from 0, there's a delay while pods start
   - For latency-sensitive workloads, consider setting `minReplicaCount: 1`

2. **Message Backlog Processing**:
   - Adjust the `messageCount` value based on how many messages each pod can process efficiently
   - Lower values create more pods, higher values create fewer pods

3. **Cooldown Period**:
   - The `cooldownPeriod` prevents rapid scale up/down (flapping)
   - Adjust based on your message arrival patterns

4. **Polling Interval**:
   - Lower values (e.g., 5 seconds) provide faster reaction times but increase API calls
   - Higher values reduce API usage but may delay scaling

### Cost Optimization

This setup optimizes costs by:

1. Scaling to zero when no messages need processing
2. Automatically scaling up to handle load spikes
3. Requiring no resources when idle, only paying for actual message processing
4. Avoiding over-provisioning of resources


## References and Additional Resources

For additional information about KEDA and its integration with various event sources, refer to these resources:

1. [KEDA Official Documentation](https://keda.sh/docs/latest/)
2. [KEDA GitHub Repository](https://github.com/kedacore/keda)
3. [KEDA Service Bus Queue Sample](https://github.com/kedacore/sample-dotnet-worker-servicebus-queue)
4. [Azure Service Bus Documentation](https://docs.microsoft.com/en-us/azure/service-bus-messaging/)
5. [KEDA Scalers Documentation](https://keda.sh/docs/latest/scalers/)
6. [KEDA Concepts](https://keda.sh/docs/latest/concepts/)
7. [Microsoft Learn - Autoscale applications with KEDA](https://docs.microsoft.com/en-us/azure/aks/keda-deploy-add-on)
8. [KEDA Sample Applications](https://github.com/kedacore/samples)
9. [Azure Kubernetes Service (AKS) Documentation](https://docs.microsoft.com/en-us/azure/aks/)
10. [Kubernetes Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
# Deploying Self-Hosted Karpenter on Azure Kubernetes Service (AKS)

This guide provides step-by-step instructions for deploying Karpenter as a self-hosted solution on an Azure Kubernetes Service (AKS) cluster. Karpenter is an open-source node provisioning project that enhances the efficiency and cost-effectiveness of Kubernetes clusters by automatically provisioning and scaling nodes based on pod requirements.

## Prerequisites

Before you begin, ensure you have the following:

- **Azure Subscription**: An active Azure subscription with permissions to create or modify resources.
- **Azure CLI**: Installed and configured with `az login`.
- **kubectl**: Installed and configured to interact with your AKS cluster.
- **Helm**: Installed for deploying Karpenter.
- **jq**: Installed for parsing JSON output in scripts.
- **AKS Cluster**: Either a new AKS cluster (created as part of this guide) or an existing one with Virtual Machine Scale Sets (VMSS) enabled for nodes, as Karpenter provisions individual nodes rather than VMSS directly.
- **Workload Identity**: Configured for authentication (recommended for secure access).
- **Environment Variables**:
  - `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID.
  - `CLUSTER_NAME`: Name of your AKS cluster.
  - `RG`: Resource group containing your AKS cluster.
  - `KARPENTER_NAMESPACE`: Namespace for Karpenter (set to `karpenter`).
  - `KARPENTER_VERSION`: Desired Karpenter version (set to `1.4.0`).

## Overview

Karpenter can be deployed in two modes on AKS: Node Auto Provisioning (NAP) mode (managed add-on) or self-hosted mode. This guide focuses on **self-hosted mode**, where Karpenter runs as a standalone deployment, offering flexibility for customization and experimentation.

Karpenter improves cluster efficiency by:
- Watching for unschedulable pods.
- Evaluating scheduling constraints (e.g., resource requests, node selectors).
- Provisioning nodes to meet pod requirements.
- Terminating nodes when no longer needed.

This document is divided into two sections:
1. **Deploying Karpenter on a New AKS Cluster**: Steps for creating a new AKS cluster and setting up Karpenter.
2. **Deploying Karpenter on an Existing AKS Cluster**: Steps for configuring an existing AKS cluster to work with Karpenter.

## Limitations of Karpenter with AKS

Karpenter’s integration with AKS has several limitations, particularly in self-hosted mode. Be aware of the following constraints:

- **Network Configuration**:
  - Karpenter is optimized for Azure CNI Overlay with Cilium dataplane. Using Azure CNI with Kubenet or other network plugins may lead to compatibility issues, such as IP exhaustion or incorrect pod scheduling.
  - Changing the network plugin or mode (e.g., from Kubenet to Overlay) requires creating new node pools or using the Azure Portal’s migration feature, as AKS does not support in-place network configuration changes.
  - Cilium dataplane requires specific taints (e.g., `node.cilium.io/agent-not-ready`) and labels (e.g., `kubernetes.azure.com/ebpf-dataplane: cilium`) for Karpenter to predict overhead accurately.
  - Limited support for advanced network policies or custom CNI plugins outside Cilium.

- **Node Management**:
  - Karpenter provisions individual nodes rather than managing VMSS directly, which may conflict with AKS’s default scaling mechanisms.
  - Does not support Windows nodes in the AKS Karpenter Provider (v1beta1).
  - Node termination and consolidation may disrupt workloads if not configured with appropriate disruption budgets or pod disruption budgets (PDBs).

- **Feature Incompatibilities**:
  - Conflicts with AKS Node Auto Provisioning (NAP) mode, as both manage node provisioning. Self-hosted Karpenter requires disabling NAP.
  - Limited integration with AKS-specific features like cluster autoscaler or managed node pools.
  - The AKS Karpenter Provider is in alpha (v1beta1), with potential for breaking changes or incomplete feature support.

- **Resource Constraints**:
  - Karpenter’s controller pod may require significant CPU/memory resources in large clusters, necessitating careful resource limit configuration.
  - Azure-specific SKUs (e.g., `D` family) must be available in the region, and certain VM sizes may not support all workloads.

- **Operational Overhead**:
  - Self-hosted mode requires manual configuration of workload identity, role assignments, and CRDs, increasing operational complexity compared to NAP.
  - Troubleshooting network or provisioning issues may require deep knowledge of Azure and Kubernetes.

For production environments, consider AKS NAP mode for a managed experience or validate these limitations against your workload requirements.

---

## Section 1: Deploying Karpenter on a New AKS Cluster

This section outlines the steps to create a new AKS cluster and deploy Karpenter in self-hosted mode, including disabling the Cluster Autoscaler and assigning required Azure roles.

### 1. Create a New AKS Cluster

Create an AKS cluster with workload identity, VMSS, and manual node provisioning to support Karpenter:

```bash
export CLUSTER_NAME=karpenter
export RG=karpenter
export LOCATION=southeastasia
export KARPENTER_NAMESPACE=karpenter
export AZURE_SUBSCRIPTION_ID=<your-subscription-id>

az group create --name ${RG} --location ${LOCATION}

az aks create \
  --name ${CLUSTER_NAME} \
  --resource-group ${RG} \
  --location ${LOCATION} \
  --network-plugin azure \
  --network-plugin-mode overlay \
  --network-dataplane cilium \
  --node-provisioning-mode Manual \
  --enable-oidc-issuer \
  --enable-workload-identity
```

> **Note**: Replace `<your-subscription-id>` with your Azure subscription ID. The `--network-plugin-mode overlay` and `--network-dataplane cilium` options are required for Karpenter compatibility. Ensure the `Microsoft.ContainerService` provider is registered (`az provider register --namespace Microsoft.ContainerService`).

Verify the cluster is ready:

```bash
az aks get-credentials --name ${CLUSTER_NAME} --resource-group ${RG}
kubectl get nodes
```

### 2. Disable Cluster Autoscaler

To avoid conflicts with Karpenter, ensure the Cluster Autoscaler is disabled:

```bash
# Check Cluster Autoscaler status
az aks show --resource-group ${RG} --name ${CLUSTER_NAME} --query "agentPoolProfiles[].{Name:name,EnableAutoScaling:enableAutoScaling}" -o table

# Disable Cluster Autoscaler for each node pool (replace <nodepool-name> with actual node pool name, e.g., 'nodepool1')
az aks nodepool update \
  --resource-group ${RG} \
  --cluster-name ${CLUSTER_NAME} \
  --name <nodepool-name> \
  --disable-cluster-autoscaler
```

> **Note**: If `enableAutoScaling` is `false` or not present, the Cluster Autoscaler is already disabled.

### 3. Create Managed Identity and Assign Azure Roles

#### a. Create the Managed Identity

Create a user-assigned managed identity for Karpenter:

```bash
KMSI_JSON=$(az identity create --name karpentermsi --resource-group ${RG})
```

#### b. Assign Azure Roles

Assign the necessary roles (`Virtual Machine Contributor`, `Network Contributor`, `Managed Identity Operator`) to the managed identity:

```bash
# Get the managed identity's principal ID
KARPENTER_USER_ASSIGNED_CLIENT_ID=$(jq -r '.principalId' <<< "$KMSI_JSON")

# Get the node resource group
AKS_JSON=$(az aks show --name ${CLUSTER_NAME} --resource-group ${RG})
RG_MC=$(jq -r ".nodeResourceGroup" <<< "$AKS_JSON")
RG_MC_RES=$(az group show --name "${RG_MC}" --query "id" -otsv)

# Assign roles
for role in "Virtual Machine Contributor" "Network Contributor" "Managed Identity Operator"; do
  az role assignment create --assignee "${KARPENTER_USER_ASSIGNED_CLIENT_ID}" --scope "${RG_MC_RES}" --role "$role"
done
```

> **Note**: The node resource group (`RG_MC`) contains node-related resources. These roles allow Karpenter to manage VMs, networks, and identities.

### 4. Set Up Workload Identity

Configure workload identity for Karpenter:

```bash
# Get the OIDC issuer URL
ISSUER_URL=$(jq -r ".oidcIssuerProfile.issuerUrl" <<< "$AKS_JSON")

# Create federated credential
az identity federated-credential create \
  --name KARPENTER_FID \
  --identity-name karpentermsi \
  --resource-group ${RG} \
  --issuer "${ISSUER_URL}" \
  --subject system:serviceaccount:${KARPENTER_NAMESPACE}:karpenter-sa \
  --audience api://AzureADTokenExchange
```

> **Note**: The service account `karpenter-sa` is created during Helm deployment.

### 5. Install Karpenter

#### a. Set Karpenter Version

```bash
export KARPENTER_VERSION=1.4.0
```

#### b. Download Configuration Template

```bash
curl -sO https://raw.githubusercontent.com/Azure/karpenter-provider-azure/refs/heads/main/karpenter-values-template.yaml
```

#### c. Generate and Verify Configuration

Generate the `karpenter-values.yaml` file:

```bash
curl -sO https://raw.githubusercontent.com/Azure/karpenter-provider-azure/v${KARPENTER_VERSION}/hack/deploy/configure-values.sh
chmod +x ./configure-values.sh
./configure-values.sh ${CLUSTER_NAME} ${RG} karpenter-sa karpentermsi
```

Verify the `karpenter-values.yaml` file:

```bash
cat karpenter-values.yaml
```

Check for:
- `clusterName`: Matches `${CLUSTER_NAME}` (e.g., `karpenter`).
- `resourceGroup`: Matches `${RG}` (e.g., `karpenter`).
- `serviceAccount.name`: `karpenter-sa`.
- `managedIdentity.name`: `karpentermsi`.
- `managedIdentity.resourceGroup`: Matches `${RG}`.

If authentication issues occur, add to `karpenter-values.yaml` under `env`:

```yaml
- name: ARM_USE_CREDENTIAL_FROM_ENVIRONMENT
  value: "true"
- name: ARM_CLIENT_SECRET
  value: "test"
```

Edit using a text editor (e.g., `nano karpenter-values.yaml`).

> **Note**: Ensure the file contains valid YAML. Re-run `configure-values.sh` if issues arise.

#### d. Deploy Karpenter with Helm

Install or upgrade Karpenter:

```bash
helm upgrade --install karpenter oci://mcr.microsoft.com/aks/karpenter/karpenter \
  --version "${KARPENTER_VERSION}" \
  --namespace "${KARPENTER_NAMESPACE}" --create-namespace \
  --values karpenter-values.yaml \
  --set controller.resources.requests.cpu=1 \
  --set controller.resources.requests.memory=1Gi \
  --set controller.resources.limits.cpu=1 \
  --set controller.resources.limits.memory=1Gi \
  --wait
```

Verify the deployment:

```bash
kubectl get pods -n ${KARPENTER_NAMESPACE}
```

Expected output:

```
NAME                        READY   STATUS    RESTARTS   AGE
karpenter-1234567890-abcde  1/1     Running   0          2m
```

Check container status:

```bash
kubectl describe pod -n ${KARPENTER_NAMESPACE} <karpenter-pod-name> | grep -A 5 "Containers:"
```

Look for:
- `State: Running` under `controller`.
- No `Last State: Terminated`.
- `Ready: True`.

View logs:

```bash
kubectl logs -n ${KARPENTER_NAMESPACE} <karpenter-pod-name> -c controller
```

Logs should show normal operations without errors. Refer to troubleshooting if issues arise.

#### e. Verify Installed CRDs

Check CRDs:

```bash
kubectl get crd | grep karpenter
```

Expected output:

```
aksnodeclasses.karpenter.k8s.io     <timestamp>   Cluster
nodeclaims.karpenter.sh             <timestamp>   Cluster
nodepools.karpenter.sh              <timestamp>   Cluster
```

> **Note**: The `aksnodeclasses.karpenter.k8s.io` CRD supports `AKSNodeClass` with `apiVersion: karpenter.azure.com/v1beta1`.

Inspect `aksnodeclasses.karpenter.k8s.io`:

```bash
kubectl describe crd aksnodeclasses.karpenter.k8s.io
```

Look for:
- `Spec.Group`: `karpenter.k8s.io`
- `Spec.Names.Kind`: `AKSNodeClass`
- `Spec.Scope`: `Cluster`
- `Spec.Versions`: Includes `v1beta1`.

Inspect `nodeclaims.karpenter.sh`:

```bash
kubectl describe crd nodeclaims.karpenter.sh
```

Look for:
- `Spec.Group`: `karpenter.sh`
- `Spec.Names.Kind`: `NodeClaim`
- `Spec.Scope`: `Cluster`
- `Spec.Versions`: Includes `v1`.

Repeat for `nodepools.karpenter.sh`:

```bash
kubectl describe crd nodepools.karpenter.sh
```

> **Note**: If CRDs are missing, verify the Helm chart version. See troubleshooting for fixes.

### 6. Create a Default NodePool

Save the following as `default-nodepool.yaml`:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
  annotations:
    kubernetes.io/description: "General purpose NodePool"
spec:
  disruption:
    consolidateAfter: 0s
    budgets:
    - nodes: 30%
  template:
    metadata:
      labels:
        kubernetes.azure.com/ebpf-dataplane: cilium
    spec:
      nodeClassRef:
        group: karpenter.azure.com
        kind: AKSNodeClass
        name: default
      startupTaints:
      - key: node.cilium.io/agent-not-ready
        effect: NoExecute
        value: "true"
      expireAfter: Never
      requirements:
      - key: kubernetes.io/arch
        operator: In
        values: ["amd64"]
      - key: kubernetes.io/os
        operator: In
        values: ["linux"]
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["on-demand"]
      - key: karpenter.azure.com/sku-family
        operator: In
        values: [D]
```

Apply:

```bash
kubectl apply -f default-nodepool.yaml
```

> **Note**: This `NodePool` provisions `on-demand` `amd64` Linux nodes with Azure `D` family SKUs. It includes Cilium-specific taints and labels for compatibility.

### 7. Create a Default AKSNodeClass

Save the following as `default-nodeclass.yaml`:

```yaml
apiVersion: karpenter.azure.com/v1beta1
kind: AKSNodeClass
metadata:
  name: default
  annotations:
    kubernetes.io/description: "General purpose AKSNodeClass for running Ubuntu2204 nodes"
spec:
  imageFamily: Ubuntu2204
```

Apply:

```bash
kubectl apply -f default-nodeclass.yaml
```

> **Note**: Ensure `Ubuntu2204` is available in your Azure region.

### 8. Test Karpenter

Deploy a sample workload:

```bash
kubectl apply -f https://raw.githubusercontent.com/Azure/karpenter-provider-azure/main/examples/v1beta1/inflate.yaml
```

Monitor:

```bash
kubectl logs -f -l app.kubernetes.io/name=karpenter -n ${KARPENTER_NAMESPACE}
kubectl get nodes
```

Scale:

```bash
kubectl scale deployment/inflate --replicas 5
```

### 9. Troubleshooting

- **Authentication Issues**: Verify workload identity and role assignments. Check `karpenter-values.yaml` for `ARM_USE_CREDENTIAL_FROM_ENVIRONMENT` and `ARM_CLIENT_SECRET`.
- **Permission Errors**: Ensure `Virtual Machine Contributor`, `Network Contributor`, and `Managed Identity Operator` roles are assigned.
- **Load Balancer Errors**: Verify VMSS and network configurations.
- **Nodes Not Provisioning**: Check `NodePool` and `AKSNodeClass`. Ensure `kubectl describe nodepool default` shows no errors. Verify `imageFamily: Ubuntu2204` and `karpenter.azure.com/sku-family: D` are valid.
- **Network Migration Issues**:
  - If nodes fail to join due to network misconfiguration, verify `--network-plugin azure`, `--network-plugin-mode overlay`, and `--network-dataplane cilium` on new node pools.
  - Check IP availability in the VNet/subnet to avoid exhaustion.
  - Ensure Cilium is deployed and compatible with Karpenter taints.
- **CRD Issues**: If CRDs (`aksnodeclasses.karpenter.k8s.io`, `nodeclaims.karpenter.sh`, `nodepools.karpenter.sh`) are missing:
  - Verify Helm chart version: `helm list -n ${KARPENTER_NAMESPACE}`.
  - Reinstall: `helm upgrade --install ...`.
  - Apply CRDs manually: `kubectl apply -f https://raw.githubusercontent.com/Azure/karpenter-provider-azure/v${KARPENTER_VERSION}/charts/crds/...`.
- **Controller Pod Issues**:
  - Check events: `kubectl describe pod -n ${KARPENTER_NAMESPACE} <karpenter-pod-name>`.
  - Verify resource limits/requests.
- **Cilium Taint Issues**: Ensure Cilium is deployed and nodes are initialized.

### 10. Cleanup

Remove Karpenter and resources:

```bash
helm uninstall karpenter -n ${KARPENTER_NAMESPACE}
kubectl delete -f default-nodepool.yaml
kubectl delete -f default-nodeclass.yaml
for role in "Virtual Machine Contributor" "Network Contributor" "Managed Identity Operator"; do
  az role assignment delete --assignee "${KARPENTER_USER_ASSIGNED_CLIENT_ID}" --scope "${RG_MC_RES}" --role "$role"
done
az identity delete --name karpentermsi --resource-group ${RG}
az group delete --name ${RG} --yes
```

---

## Section 2: Deploying Karpenter on an Existing AKS Cluster

This section outlines deploying Karpenter on an existing AKS cluster, including migrating network configuration from Azure CNI with Kubenet to Azure CNI Overlay with Cilium.

### 1. Verify AKS Cluster Configuration and Migrate Network

Ensure your AKS cluster meets Karpenter’s requirements:
- **Virtual Machine Scale Sets (VMSS)**: Node pools must use VMSS.
- **Workload Identity**: Enable if not configured.
- **Network Configuration**: Karpenter requires `--network-plugin azure`, `--network-plugin-mode overlay`, and `--network-dataplane cilium`. If your cluster uses Azure CNI with Kubenet (`network-plugin: azure`, `network-plugin-mode: none`, `network-dataplane: none`), you must migrate to the target configuration.

Check cluster details:

```bash
export CLUSTER_NAME=<your-cluster-name>
export RG=<your-resource-group>
export KARPENTER_NAMESPACE=karpenter
export AZURE_SUBSCRIPTION_ID=<your-subscription-id>

az aks show --name ${CLUSTER_NAME} --resource-group ${RG}
```

Verify network configuration:

```bash
az aks show --name ${CLUSTER_NAME} --resource-group ${RG} --query "{networkPlugin:networkProfile.networkPlugin,networkPluginMode:networkProfile.networkPluginMode,networkDataplane:networkProfile.networkDataplane}" -o table
```

If output shows:
```
NetworkPlugin    NetworkPluginMode    NetworkDataplane
-------------    -----------------    ----------------
azure            none                 none
```

Your cluster uses Azure CNI with Kubenet, which is not optimal for Karpenter. You must migrate to Azure CNI Overlay with Cilium dataplane. There are two methods to perform this migration:

#### Option 1: Use the Azure Portal’s "Migrate to Azure CNI Overlay" Feature
The Azure Portal provides a streamlined way to migrate your cluster’s networking to Azure CNI Overlay, which became generally available in mid-2023. This method automates the process of reimaging node pools and updating the network configuration.

1. **Access the AKS Cluster in the Azure Portal**:
   - Navigate to your AKS cluster in the Azure Portal.
   - Go to the **Networking** section or look for a banner/notification with the option "Migrate to Azure CNI Overlay".

2. **Initiate the Migration**:
   - Click the "Migrate to Azure CNI Overlay" link.
   - The Portal will prompt you to specify a pod CIDR (e.g., `192.168.0.0/16`). Ensure this CIDR does not overlap with your VNet or other clusters.
   - Confirm the migration. The Portal will validate prerequisites:
     - Kubernetes version 1.22 or higher.
     - No dynamic pod IP allocation.
     - No network policies (or uninstall Azure NPM/Calico).
     - No Windows node pools with Docker runtime (Windows OS Build must be 20348.1668 or higher).
   - The migration process will reimage node pools to apply the Overlay configuration, which may cause brief workload disruptions.

3. **Enable Cilium Dataplane** (if not part of the migration):
   - After the migration completes, enable Cilium if the Portal didn’t provide the option:
     ```bash
     az aks update --name ${CLUSTER_NAME} --resource-group ${RG} --network-dataplane cilium
     ```
   - Verify:
     ```bash
     az aks show --name ${CLUSTER_NAME} --resource-group ${RG} --query "{networkPlugin:networkProfile.networkPlugin,networkPluginMode:networkProfile.networkPluginMode,networkDataplane:networkProfile.networkDataplane}" -o table
     ```
     Expected output:
     ```
     NetworkPlugin    NetworkPluginMode    NetworkDataplane
     -------------    -----------------    ----------------
     azure            overlay              cilium
     ```

4. **Monitor the Migration**:
   - Monitor the progress in the Azure Portal. Check pod status:
     ```bash
     kubectl get pods -o wide
     ```
   - Ensure all pods are running on the new Overlay network with Cilium.

#### Option 2: Manual Migration by Creating a New Node Pool
If the Azure Portal’s migration feature is unavailable or you prefer CLI control, follow these manual steps to migrate by creating a new node pool, migrating workloads, and deleting the old node pool.

##### a. Enable Workload Identity (if needed)

```bash
az aks update \
  --resource-group ${RG} \
  --name ${CLUSTER_NAME} \
  --enable-oidc-issuer \
  --enable-workload-identity
```

##### b. Create a New Node Pool with Target Network Configuration

```bash
export NEW_NODEPOOL_NAME=karpenter-nodepool
export VNET_NAME=<your-vnet-name>
export SUBNET_NAME=<your-subnet-name>

az aks nodepool add \
  --resource-group ${RG} \
  --cluster-name ${CLUSTER_NAME} \
  --name ${NEW_NODEPOOL_NAME} \
  --node-count 1 \
  --node-vm-size Standard_DS2_v2 \
  --network-plugin azure \
  --network-plugin-mode overlay \
  --network-dataplane cilium \
  --vnet-subnet-id "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${RG}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}/subnets/${SUBNET_NAME}"
```

> **Note**: Replace `<your-vnet-name>` and `<your-subnet-name>` with your VNet and subnet names. Ensure the subnet has sufficient IP addresses for Overlay mode.

Verify the new node pool:

```bash
az aks nodepool list --resource-group ${RG} --cluster-name ${CLUSTER_NAME} --query "[].{Name:name,NetworkPluginMode:networkPluginMode,NetworkDataplane:networkDataplane}" -o table
kubectl get nodes -o wide
```

##### c. Migrate Workloads to the New Node Pool

Label the new node pool for scheduling:

```bash
kubectl label nodes -l "kubernetes.io/hostname=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep ${NEW_NODEPOOL_NAME})" node-role.kubernetes.io/karpenter=true
```

Apply a taint to old nodes to prevent new pods:

```bash
kubectl taint nodes -l "!node-role.kubernetes.io/karpenter" karpenter-migration=true:NoSchedule
```

Cordon old nodes:

```bash
kubectl cordon -l "!node-role.kubernetes.io/karpenter"
```

Migrate workloads by restarting deployments or using pod disruption budgets (PDBs):

```bash
kubectl rollout restart deployment -n <namespace>
```

Monitor pod scheduling:

```bash
kubectl get pods -o wide
```

##### d. Drain and Delete Old Node Pool

Drain old nodes:

```bash
kubectl drain -l "!node-role.kubernetes.io/karpenter" --ignore-daemonsets --delete-emptydir-data
```

Delete the old node pool (replace `<old-nodepool-name>`):

```bash
az aks nodepool delete --resource-group ${RG} --cluster-name ${CLUSTER_NAME} --name <old-nodepool-name>
```

Remove taints and uncordon new nodes if needed:

```bash
kubectl taint nodes -l node-role.kubernetes.io/karpenter karpenter-migration=true:NoSchedule-
kubectl uncordon -l node-role.kubernetes.io/karpenter
```

> **Note**: Ensure all workloads are running on the new node pool before deleting the old one. Back up critical data and validate Cilium compatibility.

### 2. Disable Cluster Autoscaler

Ensure the Cluster Autoscaler is disabled:

```bash
az aks show --resource-group ${RG} --name ${CLUSTER_NAME} --query "agentPoolProfiles[].{Name:name,EnableAutoScaling:enableAutoScaling}" -o table

az aks nodepool update \
  --resource-group ${RG} \
  --cluster-name ${CLUSTER_NAME} \
  --name ${NEW_NODEPOOL_NAME} \
  --disable-cluster-autoscaler
```

Verify:

```bash
kubectl get deployment -n kube-system | grep cluster-autoscaler
```

Delete if present:

```bash
kubectl delete deployment -n kube-system <cluster-autoscaler-deployment-name>
```

### 3. Create Managed Identity and Assign Azure Roles

#### a. Create the Managed Identity

```bash
KMSI_JSON=$(az identity create --name karpentermsi --resource-group ${RG})
```

#### b. Assign Azure Roles

```bash
KARPENTER_USER_ASSIGNED_CLIENT_ID=$(jq -r '.principalId' <<< "$KMSI_JSON")
AKS_JSON=$(az aks show --name ${CLUSTER_NAME} --resource-group ${RG})
RG_MC=$(jq -r ".nodeResourceGroup" <<< "$AKS_JSON")
RG_MC_RES=$(az group show --name "${RG_MC}" --query "id" -otsv)

for role in "Virtual Machine Contributor" "Network Contributor" "Managed Identity Operator"; do
  az role assignment create --assignee "${KARPENTER_USER_ASSIGNED_CLIENT_ID}" --scope "${RG_MC_RES}" --role "$role"
done
```

### 4. Set Up Workload Identity

```bash
ISSUER_URL=$(jq -r ".oidcIssuerProfile.issuerUrl" <<< "$AKS_JSON")

az identity federated-credential create \
  --name KARPENTER_FID \
  --identity-name karpentermsi \
  --resource-group ${RG} \
  --issuer "${ISSUER_URL}" \
  --subject system:serviceaccount:${KARPENTER_NAMESPACE}:karpenter-sa \
  --audience api://AzureADTokenExchange
```

### 5. Install Karpenter

#### a. Set Karpenter Version

```bash
export KARPENTER_VERSION=1.4.0
```

#### b. Download Configuration Template

```bash
curl -sO https://raw.githubusercontent.com/Azure/karpenter-provider-azure/refs/heads/main/karpenter-values-template.yaml
```

#### c. Generate and Verify Configuration

```bash
curl -sO https://raw.githubusercontent.com/Azure/karpenter-provider-azure/v${KARPENTER_VERSION}/hack/deploy/configure-values.sh
chmod +x ./configure-values.sh
./configure-values.sh ${CLUSTER_NAME} ${RG} karpenter-sa karpentermsi
```

Verify:

```bash
cat karpenter-values.yaml
```

Check for:
- `clusterName`: Matches `${CLUSTER_NAME}`.
- `resourceGroup`: Matches `${RG}`.
- `serviceAccount.name`: `karpenter-sa`.
- `managedIdentity.name`: `karpentermsi`.
- `managedIdentity.resourceGroup`: Matches `${RG}`.

Add for authentication issues:

```yaml
- name: ARM_USE_CREDENTIAL_FROM_ENVIRONMENT
  value: "true"
- name: ARM_CLIENT_SECRET
  value: "test"
```

#### d. Deploy Karpenter with Helm

```bash
helm upgrade --install karpenter oci://mcr.microsoft.com/aks/karpenter/karpenter \
  --version "${KARPENTER_VERSION}" \
  --namespace "${KARPENTER_NAMESPACE}" --create-namespace \
  --values karpenter-values.yaml \
  --set controller.resources.requests.cpu=1 \
  --set controller.resources.requests.memory=1Gi \
  --set controller.resources.limits.cpu=1 \
  --set controller.resources.limits.memory=1Gi \
  --wait
```

Verify:

```bash
kubectl get pods -n ${KARPENTER_NAMESPACE}
kubectl describe pod -n ${KARPENTER_NAMESPACE} <karpenter-pod-name> | grep -A 5 "Containers:"
kubectl logs -n ${KARPENTER_NAMESPACE} <karpenter-pod-name> -c controller
```

#### e. Verify Installed CRDs

```bash
kubectl get crd | grep karpenter
```

Expected:

```
aksnodeclasses.karpenter.k8s.io     <timestamp>   Cluster
nodeclaims.karpenter.sh             <timestamp>   Cluster
nodepools.karpenter.sh              <timestamp>   Cluster
```

Inspect:

```bash
kubectl describe crd aksnodeclasses.karpenter.k8s.io
kubectl describe crd nodeclaims.karpenter.sh
kubectl describe crd nodepools.karpenter.sh
```

### 6. Create a Default NodePool

Save as `default-nodepool.yaml`:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
  annotations:
    kubernetes.io/description: "General purpose NodePool"
spec:
  disruption:
    consolidateAfter: 0s
    budgets:
    - nodes: 30%
  template:
    metadata:
      labels:
        kubernetes.azure.com/ebpf-dataplane: cilium
    spec:
      nodeClassRef:
        group: karpenter.azure.com
        kind: AKSNodeClass
        name: default
      startupTaints:
      - key: node.cilium.io/agent-not-ready
        effect: NoExecute
        value: "true"
      expireAfter: Never
      requirements:
      - key: kubernetes.io/arch
        operator: In
        values: ["amd64"]
      - key: kubernetes.io/os
        operator: In
        values: ["linux"]
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["on-demand"]
      - key: karpenter.azure.com/sku-family
        operator: In
        values: [D]
```

Apply:

```bash
kubectl apply -f default-nodepool.yaml
```

### 7. Create a Default AKSNodeClass

Save as `default-nodeclass.yaml`:

```yaml
apiVersion: karpenter.azure.com/v1beta1
kind: AKSNodeClass
metadata:
  name: default
  annotations:
    kubernetes.io/description: "General purpose AKSNodeClass for running Ubuntu2204 nodes"
spec:
  imageFamily: Ubuntu2204
```

Apply:

```bash
kubectl apply -f default-nodeclass.yaml
```

### 8. Test Karpenter

```bash
kubectl apply -f https://raw.githubusercontent.com/Azure/karpenter-provider-azure/main/examples/v1beta1/inflate.yaml
kubectl logs -f -l app.kubernetes.io/name=karpenter -n ${KARPENTER_NAMESPACE}
kubectl get nodes
kubectl scale deployment/inflate --replicas 5
```

### 9. Troubleshooting

- **Authentication Issues**: Check workload identity and `karpenter-values.yaml`.
- **Permission Errors**: Verify role assignments.
- **Load Balancer Errors**: Check VMSS and network settings.
- **Nodes Not Provisioning**: Verify `kubectl describe nodepool default`, `imageFamily: Ubuntu2204`, and `sku-family: D`.
- **Network Migration Issues**:
  - Verify new node pool network settings (if using manual migration).
  - Check subnet IP availability: `az network vnet subnet show --resource-group ${RG} --vnet-name <vnet-name> --name <subnet-name>`.
  - Ensure Cilium is deployed: `kubectl get pods -n kube-system | grep cilium`.
- **CRD Issues**: Verify CRDs and reinstall if needed.
- **Controller Pod Issues**: Check events and resources.
- **Cilium Taint Issues**: Verify Cilium deployment.

### 10. Cleanup

```bash
helm uninstall karpenter -n ${KARPENTER_NAMESPACE}
kubectl delete -f default-nodepool.yaml
kubectl delete -f default-nodeclass.yaml
for role in "Virtual Machine Contributor" "Network Contributor" "Managed Identity Operator"; do
  az role assignment delete --assignee "${KARPENTER_USER_ASSIGNED_CLIENT_ID}" --scope "${RG_MC_RES}" --role "$role"
done
az identity delete --name karpentermsi --resource-group ${RG}
az aks nodepool delete --resource-group ${RG} --cluster-name ${CLUSTER_NAME} --name ${NEW_NODEPOOL_NAME}
```

---

## Additional Resources

- [Karpenter Azure GitHub Repository](https://github.com/Azure/karpenter-provider-azure)
- [Karpenter Documentation](https://karpenter.sh/)
- [AKS Network Configuration](https://learn.microsoft.com/en-us/azure/aks/configure-azure-cni)
- [Azure CNI Overlay Documentation](https://learn.microsoft.com/en-us/azure/aks/azure-cni-overlay)
- [Kubernetes Slack #karpenter Channel](https://kubernetes.slack.com/channels/karpenter)

## Notes

- The AKS Karpenter Provider (v1beta1) is in alpha and may introduce breaking changes.
- For production, consider AKS NAP mode for reduced complexity.
- Report security issues to MSRC: [https://msrc.microsoft.com/create-report](https://msrc.microsoft.com/create-report).
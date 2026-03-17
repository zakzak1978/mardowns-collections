# Helm Guide

Helm is a package manager for Kubernetes that simplifies deploying and managing applications on Kubernetes clusters. This guide covers basic Helm operations, including repository management, chart searching, installation, upgrading, and uninstallation, with examples using the Bitnami MySQL chart.

## Helm Release Workflow

As a Helm expert, think of Helm as your Kubernetes app deployment toolkit. The typical workflow for deploying and managing applications with Helm follows these steps—I'll explain each one so you understand not just what to do, but why and when:

1. **Add and Update Repositories**: Before you can install anything, you need to tell Helm where to find charts. Repositories are like app stores for Kubernetes. Always update after adding to get the latest versions.
2. **Search for Charts**: Don't guess—search for charts that fit your needs. Check versions and descriptions to pick the right one for your scenario, like a database for your app.
3. **Install Charts**: This is where the magic happens. Deploy a chart to create a "release" in your cluster. Customize values for your environment, like setting passwords or resource limits.
4. **Manage Releases**: Once installed, monitor and maintain. Upgrade for new features, rollback if something breaks, or inspect for debugging.
5. **Uninstall Releases**: When you're done, clean up. Sometimes keep history for future reference.

This guide follows this workflow, providing commands, examples, and practical tips for each step. Let's dive in!

## Managing Helm Repositories

Repositories are Helm's way of organizing charts—think of them as curated catalogs of pre-built Kubernetes apps. As a newbie, you'll start with popular ones like Bitnami for ready-to-use software. Managing repos is your first step: add trusted sources, keep them updated, and remove outdated ones. This ensures you have access to the latest, secure charts without surprises.

### List Repositories
To view all added repositories:
```
helm repo list
```

Example output:
```
NAME    	URL                                  
bitnami 	https://charts.bitnami.com/bitnami
stable  	https://charts.helm.sh/stable
```

**When to use:** Before installing anything, check what's available. If you see repos you don't recognize, you might have added them accidentally.

### Add a Repository
Add the Bitnami repository, which provides pre-packaged charts:
```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

Example output for add:
```
"bitnami" has been added to your repositories
```

This updates your local cache to fetch the latest chart information after adding the repository.

**Practical scenario:** You're setting up a new project and need a database. Add Bitnami, update, then search for MySQL. Always update after adding to avoid using stale info.

### Remove a Repository
If you no longer need a repository, remove it:
```
helm repo remove bitnami
```

Example output:
```
"bitnami" has been removed from your repositories
```

**When to use:** If a repo is no longer maintained or you don't trust it. Removing cleans up your local Helm config.

### Update Repositories
After adding repositories, update your local cache to fetch the latest chart information:
```
helm repo update
```

Example output:
```
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "bitnami" chart repository
Update Complete. ⎈Happy Helming!⎈
```

## Searching for Charts

Before installing, search for charts to find the best fit for your needs. Charts are packaged apps, so look for ones that match your requirements—like a web server or database. Check descriptions, versions, and app versions to ensure compatibility. As a beginner, start with well-known charts from trusted repos to avoid issues.

### Search by Name
Search for MySQL-related charts:
```
helm search repo mysql
```

Example output:
```
NAME                   	CHART VERSION	APP VERSION	DESCRIPTION                                       
bitnami/mysql          	9.4.3        	8.0.34     	MySQL is a fast, reliable, scalable, and easy t...
bitnami/mariadb        	11.0.1       	10.6.12    	MariaDB is a community-developed fork of MySQL...
```

**Practical scenario:** You need a database for your app. Search "mysql" to see options, then check versions for the latest stable one.

### Search by Category
Search for database-related charts:
```
helm search repo database
```

Example output:
```
NAME                   	CHART VERSION	APP VERSION	DESCRIPTION                                       
bitnami/mysql          	9.4.3        	8.0.34     	MySQL is a fast, reliable, scalable, and easy t...
bitnami/postgresql     	12.1.1       	14.5       	PostgreSQL is an advanced object-relational da...
bitnami/mongodb        	13.6.1       	5.0.14     	MongoDB is a document database designed for ease...
```

**When to use:** If you know the category (e.g., "web-server" for nginx), search broadly to compare options.

### View Available Versions
To see all versions of a chart:
```
helm search repo mysql --versions
```

Example output (truncated):
```
NAME         	CHART VERSION	APP VERSION	DESCRIPTION                                       
bitnami/mysql	9.4.3        	8.0.34     	MySQL is a fast, reliable, scalable, and easy t...
bitnami/mysql	9.4.2        	8.0.34     	MySQL is a fast, reliable, scalable, and easy t...
bitnami/mysql	9.4.1        	8.0.34     	MySQL is a fast, reliable, scalable, and easy t...
```

**Practical scenario:** Before upgrading, check available versions to see if a newer chart or app version is out. Avoid untested versions in production.

## Installing Charts

Installation is where you deploy a chart to your cluster, creating a "release." Think of it as launching an app with Helm handling the Kubernetes manifests. Customize values for your environment—passwords, resources, etc. Always check for repo changes (like Bitnami's) and use dry-run first to avoid surprises. As a beginner, start simple, then add customizations.

Install a chart to deploy an application on your cluster.

### Common Flags for Operations
- `--wait`: Waits for resources to be ready. **Default:** false.
- `--timeout`: Max time for `--wait` operations. **Default:** 300s.
- `--atomic`: Rolls back automatically on failure. **Default:** false. **Note:** Implies `--wait`, but you can specify both explicitly for clarity.

**Example with flags:**
```
helm install mydb bitnami/mysql --wait --timeout 600s --atomic
```

Or just:
```
helm install mydb bitnami/mysql --atomic --timeout 600s
```

**Practical scenario:** For reliable deploys, use `--atomic` to auto-rollback failures, `--wait` to ensure readiness, and `--timeout` to prevent hangs. Since `--atomic` includes waiting, it's optional but explicit.

### Bitnami Repository Changes

⚠ **WARNING:** Since August 28th, 2025, only a limited subset of images/charts are available for free from the Bitnami repository.

To receive continued support and security updates, subscribe to Bitnami Secure Images. More info at [https://bitnami.com](https://bitnami.com) and [https://github.com/bitnami/containers/issues/83267](https://github.com/bitnami/containers/issues/83267).

**Solution:** For free access to legacy images, append `--set image.repository=bitnamilegacy/<ChartName>` to your `helm install` command.

Alternatively, create a `values.yaml` file with the following content:
```yaml
image:
  repository: bitnamilegacy/mysql
```

Then use `--values` in the install command:
```
helm install mydb bitnami/mysql --values values.yaml
```

**Example using --set:**
```
helm install mydb bitnami/mysql --set image.repository=bitnamilegacy/mysql
```

### Install with Generated Name
To install a chart with a randomly generated release name:
```
helm install --generate-name bitnami/mysql
```

Example output:
```
NAME: mysql-1664800000-random
LAST DEPLOYED: Mon Oct 19 10:00:00 2025
NAMESPACE: default
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
NOTES:
...
```

**Practical scenario:** For quick tests or demos, use `--generate-name` to avoid thinking of a name. For production, specify a name for tracking.

### Install with Name Template
To install a chart with a templated release name:
```
helm install --name-template "mysql-{{randAlpha 5}}" bitnami/mysql
```

This generates a name like `mysql-abcde` using Helm's template functions.

**Practical scenario:** For automated deployments needing predictable prefixes but unique suffixes, use `--name-template` with functions like `{{randAlpha}}` or `{{now | date "20060102"}}`.

**Practical tip:** If you're learning Helm, this is a common gotcha. Always check repo docs for changes before installing.

### Example: Install MySQL
Before installing, ensure your cluster is running:
```
kubectl get pods
```

In a separate terminal, check Docker images (if using Minikube):
```
minikube ssh
docker images
```

Install the MySQL chart:
```
helm install mydb bitnami/mysql --create-namespace --namespace my-namespace
```

Or with `--wait` to ensure readiness:
```
helm install mydb bitnami/mysql --wait --timeout 600s
```

**Practical scenario:** Use `--wait` in scripts to block until the app is fully ready, preventing issues with dependent deployments. Combine with `--timeout` to avoid hanging indefinitely.

After installation, verify the deployment:
```
kubectl get pods
```

Check Docker images again to see the pulled images:
```
minikube ssh
docker images
```

**Practical scenario:** You're deploying a dev database. Install with default values first, then customize in a real project. Always verify with kubectl after install.

### Check Installation Status
Get detailed status of the release:
```
helm status mydb
```

Example output:
```
NAME: mydb
LAST DEPLOYED: Mon Oct 19 10:00:00 2025
NAMESPACE: default
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
NOTES:
...
```

**When to use:** After install or upgrade, check status to ensure it's healthy. Look for "STATUS: deployed" and read NOTES for access info.

### Dry Run Installation
To preview what would be installed without actually deploying to the cluster:
```
helm install mydb bitnami/mysql --dry-run
```

Example output (truncated YAML manifests):
```
---
# Source: mysql/templates/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: mydb-mysql
...
```

This renders the chart templates and shows the resulting Kubernetes manifests, useful for validation and debugging.

**Practical scenario:** Before deploying to production, run dry-run to catch template errors or misconfigurations without affecting the cluster.
To render and view the chart templates without installing:
```
helm template mydb bitnami/mysql
```

Example output (truncated):
```
---
# Source: mysql/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mydb-mysql
...
```

### Lint a Chart
To check a chart for potential issues, such as syntax errors or deprecated Kubernetes APIs:
```
helm lint bitnami/mysql
```

Example output:
```
==> Linting bitnami/mysql
[INFO] Chart.yaml: icon is recommended
[WARNING] templates/deployment.yaml: metadata.name: "mysql" is not a valid DNS subdomain name
[ERROR] templates/service.yaml: apiVersion "v1" is deprecated, use "v1" instead

Error: 1 chart(s) failed linting
```

## Upgrading Charts

Upgrade an existing release to a new version or with updated values. Note that "helm upgrade" upgrades installed releases, whereas "helm repo update" updates the local cache of available charts from repositories.

### Understanding Values in Upgrades
When upgrading a release:
- If you don't specify values (e.g., via `--set` or `--values`), Helm uses the default values from the new chart version. This may reset any custom values you set during installation.
- Use `--reuse-values` to reuse the values from the previous installation or upgrade, preserving your customizations.

### Example: Upgrade MySQL
Retrieve the current root password from the secret:
```
ROOT_PASSWORD=$(kubectl get secret --namespace default mydb-mysql -o jsonpath="{.data.mysql-root-password}" | base64 --decode)
```

Upgrade the release while preserving the password:
```
helm upgrade --namespace default mysql-release bitnami/mysql --set auth.rootPassword=$ROOT_PASSWORD
```

Or with `--wait`:
```
helm upgrade --namespace default mysql-release bitnami/mysql --set auth.rootPassword=$ROOT_PASSWORD --wait --timeout 300s
```

**Practical scenario:** In production, use `--wait` to ensure the upgrade completes before proceeding, avoiding downtime issues. Set `--timeout` to fail fast if it takes too long.

To reuse all previous values without specifying them again:
```
helm upgrade --namespace default mysql-release bitnami/mysql --reuse-values
```

Example output (similar to above upgrade output).

### Upgrade or Install
To upgrade an existing release or install it if it doesn't exist:
```
helm upgrade --install mysql-release bitnami/mysql
```

This is idempotent—run it multiple times safely. If the release exists, it upgrades; if not, it installs.

**Practical scenario:** In CI/CD pipelines, use `--upgrade --install` to ensure the app is deployed regardless of prior state, without failing on "release not found".

### Dry Run Upgrade
To preview an upgrade without applying changes:
```
helm upgrade --namespace default mysql-release bitnami/mysql --dry-run
```

Example output (similar to install dry-run, showing manifests that would be applied).

**Note:** Replace `mysql-release` with your actual release name if different.

### Force Upgrade
To force an upgrade, ignoring certain checks or conflicts:
```
helm upgrade --namespace default mysql-release bitnami/mysql --force
```

This forces the upgrade even if there are immutable field changes or other conflicts. Use with caution as it can lead to data loss or broken deployments.

**Practical scenario:** If an upgrade is stuck due to immutable fields (e.g., changing a PVC storage class), use --force to proceed, but backup data first.

## Managing Releases

Helm stores release records in your Kubernetes cluster as Secrets (in Helm 3), containing metadata like the chart version, values used, and deployment history. This allows tracking and managing releases.

### List Releases
View all installed releases:
```
helm list
```

Example output:
```
NAME    	NAMESPACE	REVISION	UPDATED                 	STATUS  	CHART          	APP VERSION
mydb    	default  	1       	Mon Oct 19 10:00:00 2025	deployed	bitnami/mysql-9.4.3	8.0.34
```

To list releases in all namespaces:
```
helm list --all-namespaces
```

Example output:
```
NAME    	NAMESPACE	REVISION	UPDATED                 	STATUS  	CHART          	APP VERSION
mydb    	default  	1       	Mon Oct 19 10:00:00 2025	deployed	bitnami/mysql-9.4.3	8.0.34
nginx   	kube-system	1       	Mon Oct 19 09:00:00 2025	deployed	bitnami/nginx-13.2.1	1.21.6
```

### Inspect Release Records with kubectl
Since release records are stored as Kubernetes Secrets, you can view them directly:
```
kubectl get secrets
```

Example output:
```
NAME                          TYPE                                  DATA   AGE
default-token-abcde           kubernetes.io/service-account-token   3      1d
sh.helm.release.v1.mydb.v1    helm.sh/release.v1                    1      1h
```

To inspect a specific release record:
```
kubectl get secret sh.helm.release.v1.mysql-release.v1 -o yaml
```

Example output (truncated, base64 encoded data):
```
apiVersion: v1
kind: Secret
metadata:
  name: sh.helm.release.v1.mysql-release.v1
type: helm.sh/release.v1
data:
  release: <base64-encoded-data>
```

### View Release History
Check the history of a specific release, including upgrades and rollbacks:
```
helm history mysql-release
```

Example output:
```
REVISION	UPDATED                 	STATUS    	CHART         	APP VERSION	DESCRIPTION     
1       	Mon Oct 19 10:00:00 2025	superseded	bitnami/mysql-9.4.1	8.0.34     	Install complete
2       	Mon Oct 19 11:00:00 2025	superseded	bitnami/mysql-9.4.2	8.0.34     	Upgrade complete
3       	Mon Oct 19 12:00:00 2025	deployed  	bitnami/mysql-9.4.3	8.0.34     	Upgrade complete
```

This shows each revision with its status, chart version, and description.

### Rollback a Release
Rollback to a previous revision if an upgrade fails or introduces issues. You can rollback to any previous revision in the history (not randomly, but by specifying the exact revision number from `helm history`).

```
helm rollback mysql-release 1
```

Example output:
```
Rollback was a success! Happy Helming!
```

This rolls back to revision 1 (the initial install). For example, if an upgrade to a new chart version breaks your app, rollback to the last working revision.

**Options:**
- `--dry-run`: Preview the rollback without applying changes.
- `--wait`: Wait for resources to be ready after rollback.
- `--timeout`: Set a timeout for the rollback operation (e.g., `--timeout 300s`).

**Example with options:**
```
**Example with options:**
```
helm rollback mysql-release 1 --wait --timeout 300s
```

**Practical scenario:** Use `--wait` with rollback to ensure the old version is fully restored before considering the operation complete. Use `--timeout` to prevent long waits on failures.
```

### Retrieve Release Information
Use `helm get` commands to fetch detailed information about a release:

- **Get all release data** (values, manifests, hooks, notes):
  ```
  helm get all mysql-release
  ```

  Example output (combines values, manifests, etc.):
  ```
  RELEASE: mysql-release
  COMPUTED VALUES:
  image:
    repository: bitnamilegacy/mysql
  ...
  MANIFEST:
  ---
  # Source: mysql/templates/deployment.yaml
  ...
  ```

- **Get the values used**:
  ```
  helm get values mysql-release
  ```

  Example output:
  ```
  USER-SUPPLIED VALUES:
  image:
    repository: bitnamilegacy/mysql
  ```

  To get all values, including computed defaults (from the chart's values.yaml and any merges):
  ```
  helm get values mysql-release --all
  ```

  Example output:
  ```
  COMPUTED VALUES:
  image:
    repository: bitnamilegacy/mysql
    tag: "8.0.34"
    pullPolicy: "IfNotPresent"
  ...
  ```

  **Practical scenario:** Use `--all` to see the full configuration applied to your release, helpful for debugging or understanding what defaults were used.

- **Get the generated manifests**:
  Retrieves the final rendered Kubernetes YAML manifests that Helm generated and applied to the cluster for the release (not the raw chart templates, but the processed output with values substituted). This shows the exact resources deployed, useful for debugging, auditing, or comparing with cluster state.
  ```
  helm get manifest mysql-release
  ```

  Example output (truncated):
  ```
  ---
  # Source: mysql/templates/secret.yaml
  apiVersion: v1
  kind: Secret
  metadata:
    name: mysql-release-mysql
  ...
  ```

- **Get hooks** (pre/post-install/upgrade/delete scripts):
  ```
  helm get hooks mysql-release
  ```

  Example output (if hooks exist):
  ```
  ---
  # Source: mysql/templates/pre-install-hook.yaml
  apiVersion: batch/v1
  kind: Job
  ...
  ```

These commands help inspect and debug releases.

## Creating Custom Charts

While using existing charts is common, creating your own allows you to package and manage custom Kubernetes applications. This section covers the basics of building Helm charts from scratch.

### Chart Structure

A Helm chart is a collection of files organized in a directory. Understanding each component is key to creating effective charts. Here's the significance of each file and folder:

- **Chart.yaml**: The metadata file that defines the chart's identity, version, and dependencies. It's required for every chart and tells Helm about the chart's purpose, version, and what it contains. Without it, Helm won't recognize the directory as a valid chart.

- **values.yaml**: Contains the default configuration values for the chart. These are the "defaults" that users can override during installation via `--set` or `--values`. It acts as the central configuration hub, making charts reusable and customizable.

- **templates/**: The heart of the chart, containing Go template files that generate Kubernetes manifests. When Helm installs the chart, it processes these templates with the values to create actual YAML resources that get deployed to Kubernetes.
  - **deployment.yaml, service.yaml, ingress.yaml, etc.**: Individual template files for different Kubernetes resource types. Each defines how that resource should be created, using templating to inject values dynamically.
  - **_helpers.tpl**: A special file (note the underscore prefix) containing reusable template functions and partials. It defines common snippets like naming conventions or label generators that can be included in other templates, promoting DRY (Don't Repeat Yourself) principles.
  - **NOTES.txt**: A template file that generates post-installation notes displayed to the user after successful installation. It's useful for providing usage instructions, access URLs, or next steps.

- **charts/**: Directory for chart dependencies (subcharts). If your chart depends on other charts, they are placed here. Helm manages these automatically during installation, allowing you to compose complex applications from simpler components.

This structure ensures charts are modular, versionable, and easy to maintain. The `helm create` command generates all these with sensible defaults to get you started quickly.

### Creating a New Chart

Use the `helm create` command to scaffold a basic chart structure:

```
helm create my-chart
```

This generates a complete starter chart with sample templates for a simple web application.

**Example output:**
```
Creating my-chart
```

The command creates the directory structure with default files.

### Chart.yaml

This file contains metadata about the chart:

```yaml
apiVersion: v2
name: my-chart
description: A Helm chart for Kubernetes
type: application
version: 0.1.0
appVersion: "1.16.0"
```

- `apiVersion`: Chart API version (v2 for Helm 3)
- `name`: Chart name
- `description`: Brief description
- `type`: Chart type - "application" (default, creates a release when installed) or "library" (provides shared templates for other charts, doesn't create releases)
- `version`: Chart version (semantic versioning)
- `appVersion`: Version of the application being deployed

### values.yaml

Default values that can be overridden during installation:

```yaml
# Default values for my-chart.
replicaCount: 1

image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "latest"

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts:
    - host: chart-example.local
      paths:
        - path: /
          pathType: Prefix
  tls: []
```

### Deep Dive: Helm Templating with Go

Helm uses Go's text/template package for templating, allowing dynamic generation of Kubernetes manifests. Templates are processed at install/upgrade time, substituting variables and logic to create final YAML.

#### Basic Syntax

Templates use double braces `{{ }}` for expressions. Everything outside is literal text.

```yaml
# Literal YAML
apiVersion: v1
kind: Pod
metadata:
  name: {{ .Values.name }}  # Expression: inserts value from values.yaml
spec:
  containers:
  - name: app
    image: nginx
```

#### Built-in Objects

Helm provides several root objects accessible via `.`:

- **`.Values`**: Values from `values.yaml` (merged with user overrides)
  ```yaml
  replicas: {{ .Values.replicaCount }}
  image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
  ```

- **`.Chart`**: Metadata from `Chart.yaml`
  ```yaml
  appVersion: {{ .Chart.AppVersion }}
  chartName: {{ .Chart.Name }}
  ```

- **`.Release`**: Information about the current release
  ```yaml
  releaseName: {{ .Release.Name }}
  namespace: {{ .Release.Namespace }}
  ```

- **`.Template`**: Current template info (rarely used)
  ```yaml
  templateName: {{ .Template.Name }}
  ```

#### Understanding `.` and `$.` (Context and Scoping)

In Helm templates, `.` (dot) represents the **current context** or scope. The context changes based on where you are in the template.

- **At root level**: `.` refers to the root context containing `.Values`, `.Chart`, `.Release`, etc.
- **Inside `with` blocks**: `.` refers to the scoped value (e.g., inside `{{- with .Values.image }}`, `.` is `.Values.image`)
- **Inside `range` loops**: `.` refers to the current iteration item

**Accessing root context with `$.`:**
When the context changes (in `with`, `range`, etc.), use `$` to access the original root context.

**Examples:**

**Root context:**
```yaml
# Here . is the root
name: {{ .Values.app.name }}
chart: {{ .Chart.Name }}
```

**Inside with:**
```yaml
{{- with .Values.database }}
# Here . is .Values.database
host: {{ .host }}
# Use $ for root access
release: {{ $.Release.Name }}
chart: {{ $.Chart.Name }}
{{- end }}
```

**Inside range:**
```yaml
{{- range .Values.envVars }}
# Here . is the current envVar item
- name: {{ .name }}
  value: {{ .value }}
  # Use $ for root access
  app: {{ $.Chart.Name }}
{{- end }}
```

**Key points:**
- `.` is always the current scope
- `$` always refers to the template's root context
- Context changes in `with`, `range`, and named templates
- Use `$.` when you need root-level data inside scoped blocks

**Practical tip:** If a template fails with "can't evaluate field X in type interface{}", you likely have a scoping issue—check if you need `$` instead of `.`.

#### Template Actions

Template actions are the operations performed inside `{{ }}` delimiters. They execute logic and output results into the final manifest.

**Types of actions:**

- **Value output**: Directly inserts values
  ```yaml
  name: {{ .Values.app.name }}
  replicas: {{ .Values.replicaCount }}
  ```

- **Function calls**: Apply functions to transform data
  ```yaml
  image: {{ .Values.image | default "nginx" | quote }}
  truncatedName: {{ .Values.longName | trunc 63 }}
  ```

- **Variable assignment**: Create local variables for reuse
  ```yaml
  {{- $fullName := include "my-chart.fullname" . }}
  name: {{ $fullName }}
  ```

#### Defining Variables in Templates

Helm templates allow you to define local variables using the `:=` assignment operator within `{{ }}`. Variables are scoped to the template block where they're defined and can help reduce repetition and improve readability.

**Basic variable assignment:**
```yaml
{{- $replicas := .Values.replicaCount | default 1 }}
spec:
  replicas: {{ $replicas }}
```

**Variables with complex expressions:**
```yaml
{{- $imageTag := .Values.image.tag | default .Chart.AppVersion }}
{{- $fullName := include "my-chart.fullname" . }}
metadata:
  name: {{ $fullName }}
spec:
  containers:
  - name: app
    image: "{{ .Values.image.repository }}:{{ $imageTag }}"
```

**Variables in loops:**
Variable assignment within loops allows you to compute values per iteration and reuse them. Variables defined inside loops are scoped to that iteration.

**Basic assignment in loops:**
```yaml
{{- range .Values.services }}
{{- $serviceName := printf "%s-%s" $.Release.Name .name }}
apiVersion: v1
kind: Service
metadata:
  name: {{ $serviceName }}
spec:
  ports:
  - port: {{ .port }}
{{- end }}
```

**Reassignment within loops:**
Variables can be reassigned in each iteration:
```yaml
{{- range .Values.items }}
{{- $processedItem := . }}
{{- if hasPrefix "prefix:" . }}
  {{- $processedItem = trimPrefix "prefix:" . }}
{{- end }}
- name: {{ $processedItem }}
{{- end }}
```

**Loop variables with index:**
```yaml
{{- range $index, $item := .Values.list }}
{{- $uniqueName := printf "%s-%d" $.Chart.Name $index }}
{{- $config := dict "name" $uniqueName "value" $item }}
config{{ $index }}: {{ $config | toJson }}
{{- end }}
```

**Accumulating values in loops:**
```yaml
{{- $allPorts := list }}
{{- range .Values.services }}
  {{- $allPorts = append $allPorts .port }}
{{- end }}
ports: {{ $allPorts | toJson }}
```

**Conditional assignment in loops:**
```yaml
{{- range .Values.databases }}
{{- $connectionString := printf "host=%s port=%d" .host .port }}
{{- if .ssl }}
  {{- $connectionString = printf "%s sslmode=require" $connectionString }}
{{- end }}
- {{ $connectionString | quote }}
{{- end }}
```

**Complex variable computation:**
```yaml
{{- range .Values.nodes }}
{{- $nodeLabels := dict "app" $.Chart.Name }}
{{- $nodeLabels = merge $nodeLabels .labels }}
{{- if .zone }}
  {{- $nodeLabels = set $nodeLabels "zone" .zone }}
{{- end }}
node-{{ .name }}:
  labels: {{ $nodeLabels | toYaml | nindent 4 }}
{{- end }}
```

**Best practices for loop assignment:**
- Use descriptive variable names that indicate their purpose
- Initialize variables at the start of each iteration
- Use `$` to access root context when needed within loops
- Test loops with `helm template --set` to verify variable values
- Keep variable logic simple; complex computations may belong in helpers

**Practical scenario:** Assign `$serviceName` in service loops, or compute `$configMap` per environment in deployment loops, ensuring each resource gets properly configured values.

**Variables with conditional assignment:**
```yaml
{{- $env := "development" }}
{{- if eq .Values.environment "production" }}
  {{- $env = "production" }}
{{- end }}
env: {{ $env }}
```

**Best practices:**
- Use variables to avoid repeating complex expressions
- Variables are scoped to their template block
- Use descriptive names (e.g., `$fullName` instead of `$fn`)
- Variables can be reassigned within the same scope
- Test with `helm template` to ensure variables work as expected

**Practical scenario:** Define `$baseUrl` for API endpoints or `$labels` for consistent metadata across resources, reducing duplication and making templates easier to maintain.

- **Control structures**: Conditional logic and loops
  ```yaml
  {{- if .Values.enabled }}
  enabled: true
  {{- end }}
  {{- range .Values.items }}
  - {{ . }}
  {{- end }}
  ```

- **Includes**: Call named templates
  ```yaml
  labels: {{ include "my-chart.labels" . | indent 2 }}
  ```

Actions can be combined and chained for complex logic.

#### Template Information (.Template Object)

The `.Template` object provides metadata about the currently rendering template file. It's rarely used but helpful for debugging or conditional logic.

**Available fields:**
- `.Template.Name`: Full path of the template file (e.g., "my-chart/templates/deployment.yaml")
- `.Template.BasePath`: Base path of the templates directory (e.g., "my-chart/templates")

**Example usage:**
```yaml
metadata:
  annotations:
    rendered-by: {{ .Template.Name | quote }}
    # Useful for debugging which template generated a resource
```

This information is mainly for advanced templating scenarios or logging/debugging purposes.

#### Template Functions

Helm templates use Go's text/template engine with the Sprig function library, providing a rich set of functions for manipulating data. Functions are called within `{{ }}` and can be chained with pipes `|`.

**String Functions:**
- `upper "text"`: Convert to uppercase
- `lower "TEXT"`: Convert to lowercase
- `title "hello world"`: Capitalize first letter of each word
- `trunc 10 "longstring"`: Truncate to 10 characters
- `substr 1 3 "string"`: Extract substring (start, length)
- `contains "substr" "string"`: Check if substring exists
- `hasPrefix "prefix" "string"`: Check prefix
- `hasSuffix "suffix" "string"`: Check suffix
- `replace "old" "new" "string"`: Replace occurrences
- `trim "  text  "`: Remove leading/trailing whitespace
- `trimPrefix "prefix" "string"`: Remove prefix
- `trimSuffix "string" "suffix"`: Remove suffix
- `quote "text"`: Add double quotes
- `squote "text"`: Add single quotes
- `cat "a" "b" "c"`: Concatenate strings
- `join "-" (list "a" "b" "c")`: Join with separator

**Default and Type Functions:**
- `default "fallback" .Values.key`: Return fallback if value is empty
- `empty .Values.key`: Check if value is empty
- `kindOf .Values.key`: Return type ("map", "slice", "string", etc.)
- `typeOf .Values.key`: Return Go type
- `toString .Values.key`: Convert to string
- `toJson .Values.key`: Convert to JSON string
- `fromJson "jsonstring"`: Parse JSON string
- `toYaml .Values.key`: Convert to YAML string
- `fromYaml "yamlstring"`: Parse YAML string

**Math Functions:**
- `add 1 2`: Addition
- `sub 5 3`: Subtraction
- `mul 2 3`: Multiplication
- `div 10 2`: Division
- `mod 10 3`: Modulo
- `max 1 2 3`: Maximum value
- `min 1 2 3`: Minimum value

**List/Slice Functions:**
- `len .Values.list`: Length of list
- `first .Values.list`: First element
- `last .Values.list`: Last element
- `append .Values.list "newitem"`: Add to end
- `prepend .Values.list "newitem"`: Add to beginning
- `reverse .Values.list`: Reverse order
- `uniq .Values.list`: Remove duplicates
- `has .Values.list "item"`: Check if item exists
- `slice .Values.list 1 3`: Extract subslice

**Dictionary/Map Functions:**
- `keys .Values.dict`: Get all keys
- `values .Values.dict`: Get all values
- `hasKey .Values.dict "key"`: Check if key exists
- `get .Values.dict "key"`: Get value by key
- `set .Values.dict "key" "value"`: Set value (returns new dict)
- `merge .Values.dict1 .Values.dict2`: Merge dictionaries
- `pick .Values.dict "key1" "key2"`: Select specific keys
- `omit .Values.dict "key1"`: Remove keys

**Date/Time Functions:**
- `now`: Current timestamp
- `date "2006-01-02" now`: Format date
- `dateInZone "2006-01-02" now "UTC"`: Format with timezone
- `dateModify "+1h" now`: Modify date

**Crypto Functions:**
- `sha256sum "text"`: SHA256 hash
- `md5sum "text"`: MD5 hash
- `bcrypt "password"`: bcrypt hash
- `randAlpha 10`: Random alphabetic string
- `randNumeric 5`: Random numeric string
- `randAlphaNum 8`: Random alphanumeric string

**Other Utility Functions:**
- `indent 4 "text"`: Indent text by 4 spaces
- `nindent 4 "text"`: Indent with newline
- `repeat 3 "text"`: Repeat string
- `coalesce .Values.a .Values.b "default"`: Return first non-empty value
- `ternary "true" "false" (eq .Values.enabled true)`: Conditional ternary
- `fail "error message"`: Fail template rendering with message

**Examples:**
```yaml
# String manipulation
name: {{ upper .Values.app.name | quote }}
truncated: {{ trunc 20 .Values.description }}

# Defaults and type conversion
replicas: {{ default 1 .Values.replicaCount }}
config: {{ toYaml .Values.config | indent 4 }}

# Lists and loops
firstPort: {{ first .Values.ports }}
portList: {{ join "," .Values.ports }}

# Dictionaries
hasKey: {{ hasKey .Values "optionalKey" }}
merged: {{ merge .Values.defaults .Values.overrides }}

# Math
total: {{ add .Values.baseCount .Values.extraCount }}

# Crypto
password: {{ randAlphaNum 16 | quote }}
```

**Practical scenario:** Use `default` for optional values, `toYaml` for complex configs, and `join`/`split` for list manipulation. Combine functions with pipes for powerful data transformations.

#### Control Structures

**Conditional Blocks (if/else/else if):**
Conditionals allow rendering different content based on values. Use `if` for basic conditions, `else` for alternatives, and `else if` for multiple branches.

**Basic if:**
```yaml
{{- if .Values.enabled }}
enabled: true
{{- end }}
```

**If/else:**
```yaml
serviceType: 
{{- if eq .Values.service.type "LoadBalancer" }}
  {{ .Values.service.type }}
{{- else }}
  ClusterIP
{{- end }}
```

**If/else if/else:**
```yaml
replicas:
{{- if gt .Values.replicaCount 10 }}
  {{ .Values.replicaCount }}
{{- else if gt .Values.replicaCount 5 }}
  5
{{- else }}
  1
{{- end }}
```

**Negation with not:**
```yaml
{{- if not .Values.disabled }}
enabled: true
{{- end }}
```

**Complex conditions:**
```yaml
{{- if and .Values.enabled (gt .Values.replicaCount 1) }}
# Both conditions must be true
{{- end }}

{{- if or .Values.debug .Values.verbose }}
# Either condition can be true
{{- end }}
```

**Common comparison operators:**
- `eq`: Equal (`eq .Values.env "prod"`)
- `ne`: Not equal (`ne .Values.env "dev"`)
- `lt`: Less than (`lt .Values.replicaCount 5`)
- `le`: Less than or equal (`le .Values.replicaCount 5`)
- `gt`: Greater than (`gt .Values.replicaCount 1`)
- `ge`: Greater than or equal (`ge .Values.replicaCount 1`)

**Checking emptiness:**
```yaml
{{- if .Values.optionalField }}
# Only renders if not empty
{{- end }}

{{- if not .Values.optionalField }}
# Renders if empty
{{- end }}
```

**Practical examples:**

**Conditional resource inclusion:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "my-chart.fullname" . }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
{{- if .Values.service.nodePort }}
      nodePort: {{ .Values.service.nodePort }}
{{- end }}
```

**Environment-specific config:**
```yaml
env:
{{- if eq .Values.environment "production" }}
- name: LOG_LEVEL
  value: "ERROR"
{{- else }}
- name: LOG_LEVEL
  value: "DEBUG"
{{- end }}
```

**Conditional volumes:**
```yaml
spec:
  template:
    spec:
      containers:
      - name: app
        volumeMounts:
{{- if .Values.persistence.enabled }}
        - name: data
          mountPath: /data
{{- end }}
      volumes:
{{- if .Values.persistence.enabled }}
      - name: data
        persistentVolumeClaim:
          claimName: {{ .Values.persistence.existingClaim }}
{{- end }}
```

**Best practices for conditionals:**
- Use whitespace control (`{{- -}}`) to avoid unwanted newlines
- Keep conditions simple; complex logic may indicate a need for restructuring
- Test all branches with `helm template --set` to ensure correct rendering
- Use `default` for optional values instead of complex conditionals when possible

**Practical scenario:** Use conditionals to include optional resources like Ingress, persistence, or sidecar containers based on `.Values` settings, making charts highly configurable.

**Loops (range):**
```yaml
ports:
{{- range .Values.service.ports }}
- name: {{ .name }}
  containerPort: {{ .port }}
  protocol: {{ .protocol | default "TCP" }}
{{- end }}
```

**With (scoped variables):**
The `with` action sets a new scope for the template, allowing you to reference a nested value as `.` within the block. This reduces repetition and improves readability.

**Basic usage:**
```yaml
{{- with .Values.image }}
image: {{ .repository }}:{{ .tag }}
pullPolicy: {{ .pullPolicy }}
{{- end }}
```

This is equivalent to:
```yaml
image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
pullPolicy: {{ .Values.image.pullPolicy }}
```

**Accessing parent scope:**
Use `$` to access the root context when inside `with`:
```yaml
{{- with .Values.database }}
db:
  host: {{ .host }}
  port: {{ .port }}
  name: {{ $.Chart.Name }}  # Access root scope
{{- end }}
```

**Conditional with:**
`with` only executes if the scoped value is not empty:
```yaml
{{- with .Values.ingress }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $.Chart.Name }}-ingress
spec:
  rules:
  {{- range .hosts }}
  - host: {{ .host }}
    http:
      paths:
      - path: {{ .path }}
        pathType: Prefix
        backend:
          service:
            name: {{ $.Chart.Name }}-service
            port:
              number: {{ $.Values.service.port }}
  {{- end }}
{{- end }}
```

**Nested with blocks:**
```yaml
{{- with .Values.app }}
{{- with .config }}
appConfig:
  env: {{ .env }}
  debug: {{ .debug }}
  chartVersion: {{ $.Chart.Version }}  # Access root
{{- end }}
{{- end }}
```

**Best practices:**
- Use `with` to avoid repeating long paths like `.Values.some.deep.nested`
- Always use `$` when you need to access the root context
- Combine with conditionals for optional sections
- Test with `helm template` to ensure scoping works as expected

**Practical scenario:** For complex configurations, use `with` to scope into `.Values.database` or `.Values.ingress`, making templates more readable and reducing errors from long paths.

#### Working with Lists and Dictionaries

Helm templates provide powerful tools for iterating over lists and manipulating dictionaries (maps). These are essential for dynamic configurations like environment variables, ports, or config maps.

**Iteration with range:**
The `range` action iterates over lists, arrays, or maps. Within the loop, `.` represents the current item.

**Basic list iteration:**
```yaml
# values.yaml
service:
  ports:
    - name: http
      port: 80
    - name: https
      port: 443

# template
ports:
{{- range .Values.service.ports }}
- name: {{ .name }}
  containerPort: {{ .port }}
{{- end }}
```

**Accessing loop variables:**
In `range`, you can access the index and value:
```yaml
{{- range $index, $port := .Values.service.ports }}
- name: port-{{ $index }}
  containerPort: {{ $port.port }}
{{- end }}
```

**Iterating over maps/dictionaries:**
```yaml
# values.yaml
env:
  DATABASE_URL: "postgres://..."
  REDIS_URL: "redis://..."

# template
env:
{{- range $key, $value := .env }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
```

**Nested iteration:**
```yaml
{{- range .Values.services }}
apiVersion: v1
kind: Service
metadata:
  name: {{ .name }}
spec:
  ports:
  {{- range .ports }}
  - port: {{ .port }}
    targetPort: {{ .targetPort }}
  {{- end }}
  selector:
    app: {{ .name }}
{{- end }}
```

**Dictionary functions:**
Helm provides Sprig functions for dictionary manipulation:

- **`keys`**: Get all keys from a map
- **`values`**: Get all values from a map
- **`hasKey`**: Check if a key exists
- **`get`**: Get a value by key (safe access)
- **`merge`**: Combine dictionaries
- **`dict`**: Create a new dictionary

**Using keys and values:**
```yaml
# Get all keys
configKeys: {{ keys .Values.config | toJson }}

# Get all values
configValues: {{ values .Values.config | toJson }}

# Check if key exists
{{- if hasKey .Values.config "debug" }}
debugEnabled: true
{{- end }}

# Safe key access
debugLevel: {{ get .Values.config "debug" | default "info" }}
```

**Merging dictionaries:**
```yaml
# Merge multiple maps
{{- $defaultConfig := dict "timeout" 30 "retries" 3 }}
{{- $userConfig := .Values.config }}
{{- $finalConfig := merge $defaultConfig $userConfig }}
config: {{ $finalConfig | toYaml | nindent 2 }}
```

**Creating dictionaries:**
```yaml
{{- $labels := dict "app" .Chart.Name "version" .Chart.Version }}
metadata:
  labels: {{ $labels | toYaml | nindent 4 }}
```

**Dictionary iteration with keys:**
```yaml
# Iterate over specific keys
{{- range $key := list "database" "redis" "cache" }}
{{- if hasKey .Values $key }}
{{ $key }}:
  {{- toYaml (get .Values $key) | nindent 2 }}
{{- end }}
{{- end }}
```

**Practical examples:**

**Dynamic environment variables:**
```yaml
env:
{{- range $key, $value := .Values.env }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
{{- if .Values.extraEnv }}
{{- range $key, $value := .Values.extraEnv }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}
```

**ConfigMap from dictionary:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "my-chart.fullname" . }}
data:
{{- range $key, $value := .Values.config }}
  {{ $key }}: {{ $value | quote }}
{{- end }}
```

**Conditional dictionary merging:**
```yaml
{{- $baseLabels := dict "app" .Chart.Name }}
{{- $versionLabels := dict "version" .Chart.Version }}
{{- $labels := merge $baseLabels $versionLabels }}
{{- if .Values.extraLabels }}
{{- $labels = merge $labels .Values.extraLabels }}
{{- end }}
metadata:
  labels: {{ $labels | toYaml | nindent 4 }}
```

**Best practices for lists and dictionaries:**
- Use `range` for dynamic lists like ports, environment variables, or volumes
- Prefer `hasKey` and `get` for safe dictionary access to avoid template errors
- Use `merge` to combine default and user configurations
- Test iterations with `helm template --set` to ensure correct output
- Use `toYaml` for complex nested structures within loops

**Practical scenario:** Use list iteration for service ports or environment variables, and dictionary functions for merging default configs with user overrides, enabling highly flexible and reusable charts.

#### Pipes and Chaining

Functions can be chained with pipes `|`:
```yaml
name: {{ .Values.name | default "app" | upper | trunc 10 }}
```

#### Whitespace Control

The `-` character in template actions (`{{-` and `-}}`) controls whitespace trimming, which is essential for generating clean, valid YAML without unwanted newlines or indentation issues.

- **`{{-`**: Trims whitespace and newlines **before** the action
- **`-}}`**: Trims whitespace and newlines **after** the action
- **Combined `{{- -}}`**: Trims on both sides

**Why it's important:**
Templates can introduce extra whitespace/newlines that break YAML structure. Without control, this could create invalid manifests.

**Examples:**

**Without whitespace control (problematic):**
```yaml
{{- if .Values.enabled }}
enabled: true
{{- end }}
```
Generates:
```yaml
enabled: true
```
But if there's a blank line before, it might break YAML.

**Better with control:**
```yaml
{{- if .Values.enabled -}}
enabled: true
{{- end }}
```

**Common use cases:**

**In conditionals:**
```yaml
spec:
  {{- if .Values.persistence.enabled }}
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: {{ .Values.persistence.existingClaim }}
  {{- end }}
```

**In loops:**
```yaml
env:
{{- range .Values.envVars }}
- name: {{ .name }}
  value: {{ .value | quote }}
{{- end }}
```

**In includes:**
```yaml
metadata:
  labels:
    {{- include "my-chart.labels" . | nindent 4 }}
```

Without `-`, the included template might add unwanted newlines, breaking YAML indentation.

**Best practice:** Use `{{-` and `-}}` liberally in templates to ensure clean output. Test with `helm template` to verify YAML validity.

#### Named Templates and Includes

Define reusable templates in `_helpers.tpl`:

```yaml
{{- define "my-chart.labels" -}}
app.kubernetes.io/name: {{ include "my-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

Include them: `{{ include "my-chart.labels" . | indent 4 }}`

#### Advanced Examples

**Complex deployment with conditionals:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "my-chart.fullname" . }}
  labels:
    {{- include "my-chart.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "my-chart.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "my-chart.selectorLabels" . | nindent 8 }}
    spec:
      {{- if .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- range .Values.imagePullSecrets }}
        - name: {{ . }}
        {{- end }}
      {{- end }}
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            {{- range .Values.service.ports }}
            - name: {{ .name }}
              containerPort: {{ .port }}
              protocol: {{ .protocol | default "TCP" }}
            {{- end }}
          env:
            {{- range .Values.env }}
            - name: {{ .name }}
              value: {{ .value | quote }}
            {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
```

#### Best Practices

- Use `include` for reusable labels/selectors
- Leverage `default` for optional values
- Control whitespace with `{{-` and `-}}`
- Test templates with `helm template`
- Keep logic simple; complex logic belongs in hooks or external tools
- Use `toYaml` for complex nested structures

**Practical scenario:** Templates transform static YAML into dynamic, configurable manifests. For a web app, use `.Values` for image tags, replica counts, and environment variables, allowing the same chart to deploy different configurations.

### Helper Templates (_helpers.tpl)

The `_helpers.tpl` file contains reusable template functions and partials that can be included across multiple templates. This promotes DRY (Don't Repeat Yourself) principles and makes charts more maintainable.

#### Template Definition Syntax

Templates are defined using the `define` action with a unique name:

```yaml
{{/*
Template comment - describes what this template does
*/}}
{{- define "chart-name.template-name" -}}
# Template content here
{{- end -}}
```

**Naming convention:** Use `chart-name.function-name` format for global uniqueness.

#### Common Helper Templates

**Standard naming helpers (auto-generated by `helm create`):**

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "my-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "my-chart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}
```

**Labels and selectors:**

```yaml
{{/*
Common labels
*/}}
{{- define "my-chart.labels" -}}
app.kubernetes.io/name: {{ include "my-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "my-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "my-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

**Custom utility templates:**

```yaml
{{/*
Generate image reference
*/}}
{{- define "my-chart.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) }}
{{- end }}

{{/*
Generate service account name
*/}}
{{- define "my-chart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "my-chart.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate config checksum for rolling updates
*/}}
{{- define "my-chart.configChecksum" -}}
{{- include (print $.Template.BasePath "/configmap.yaml") . | sha256sum | trunc 8 }}
{{- end }}
```

#### Template Parameters

Templates can accept parameters by accessing the root context:

```yaml
{{/*
Create a PVC name with custom suffix
*/}}
{{- define "my-chart.pvcName" -}}
{{- printf "%s-%s" (include "my-chart.fullname" .) .suffix }}
{{- end }}
```

Usage:
```yaml
{{- $pvcName := dict "suffix" "data" | merge . | include "my-chart.pvcName" }}
```

#### Conditional Templates

```yaml
{{/*
Database URL based on configuration
*/}}
{{- define "my-chart.databaseUrl" -}}
{{- if .Values.database.external }}
{{- .Values.database.external.url }}
{{- else }}
{{- printf "postgresql://%s:%s@%s-%s:%s/%s"
    .Values.database.auth.username
    .Values.database.auth.password
    (include "my-chart.fullname" .)
    "postgresql"
    (.Values.database.service.port | toString)
    .Values.database.auth.database }}
{{- end }}
{{- end }}
```

#### Template with Loops

```yaml
{{/*
Generate environment variables from a map
*/}}
{{- define "my-chart.envVars" -}}
{{- range $key, $value := . }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}
```

Usage:
```yaml
env:
{{- include "my-chart.envVars" .Values.env | indent 2 }}
```

#### Nested Template Calls

```yaml
{{/*
Full resource labels including custom ones
*/}}
{{- define "my-chart.resourceLabels" -}}
{{- $labels := include "my-chart.labels" . | fromYaml }}
{{- if .Values.additionalLabels }}
{{- $labels = merge $labels .Values.additionalLabels }}
{{- end }}
{{- $labels | toYaml }}
{{- end }}
```

#### Template Documentation

Always document your templates:

```yaml
{{/*
my-chart.imagePullSecrets: Generate image pull secrets list

This template generates a list of image pull secrets based on global
and chart-specific values.

Usage:
  {{- include "my-chart.imagePullSecrets" . | indent 2 }}

Parameters:
  - .Values.global.imagePullSecrets: Global pull secrets
  - .Values.imagePullSecrets: Chart-specific pull secrets
*/}}
{{- define "my-chart.imagePullSecrets" -}}
{{- $pullSecrets := list }}
{{- if .Values.global.imagePullSecrets }}
{{- $pullSecrets = concat $pullSecrets .Values.global.imagePullSecrets }}
{{- end }}
{{- if .Values.imagePullSecrets }}
{{- $pullSecrets = concat $pullSecrets .Values.imagePullSecrets }}
{{- end }}
{{- if $pullSecrets }}
imagePullSecrets:
{{- range $pullSecrets }}
- name: {{ . }}
{{- end }}
{{- end }}
{{- end }}
```

#### Best Practices

- **Naming:** Use consistent `chart-name.function-name` format
- **Documentation:** Add comments explaining purpose and usage
- **Parameters:** Document expected input parameters
- **Error handling:** Use `default` and `empty` checks
- **Reusability:** Make templates generic enough for multiple use cases
- **Testing:** Test templates individually with `helm template`
- **Performance:** Avoid complex logic in frequently called templates

**Practical scenario:** Create helper templates for common patterns like labels, image references, and configuration generation. For a microservices chart, define templates for service names, database connections, and environment variables to ensure consistency across all deployments.

### Debugging Templates

Debugging Helm templates is crucial for developing reliable charts. Helm provides several tools and techniques to inspect template rendering, identify errors, and understand template behavior.

#### Basic Template Rendering

**Render templates locally:**
```bash
helm template my-release ./my-chart
```
Shows the final rendered Kubernetes manifests without installing. This is the first step in debugging template issues.

**Render with custom values:**
```bash
helm template my-release ./my-chart --values custom-values.yaml
```
Test templates with specific value overrides to reproduce issues.

**Render specific templates:**
```bash
helm template my-release ./my-chart --include-crds
helm template my-release ./my-chart -s templates/deployment.yaml
```
Use `--include-crds` to include CRDs, or `-s` to render only specific template files.

#### Debugging Template Errors

**Enable debug mode:**
```bash
helm template my-release ./my-chart --debug
```
Shows detailed error information and template execution flow.

**Check for syntax errors:**
```bash
helm lint ./my-chart
```
Validates chart structure and catches common template issues.

**Dry-run installation:**
```bash
helm install my-release ./my-chart --dry-run --debug
```
Simulates installation and shows what would be deployed, with debug output.

#### Inspecting Template Context

**View available template objects:**
Add debug output to templates to inspect the context:
```yaml
# In your template
{{ toYaml . | indent 2 }}
```
This will output the entire root context (`.`) as YAML.

**Debug specific values:**
```yaml
# Debug Values object
Values: {{ toYaml .Values | indent 2 }}

# Debug Chart object
Chart: {{ toYaml .Chart | indent 2 }}

# Debug Release object
Release: {{ toYaml .Release | indent 2 }}
```

**Inspect template metadata:**
```yaml
# Show which template file is being rendered
Template: {{ .Template.Name }}

# Show current template base path
BasePath: {{ .Template.BasePath }}
```

#### Common Debugging Techniques

**Debugging loops and conditionals:**
```yaml
{{- range .Values.items }}
# Debug current item
Item: {{ toYaml . | indent 2 }}
{{- end }}
```

**Debugging variable assignment:**
```yaml
{{- $debugVar := .Values.someValue }}
# Output variable value
DebugVar: {{ $debugVar }}
```

**Debugging function results:**
```yaml
# Debug function output
FunctionResult: {{ include "my-chart.fullname" . }}
```

**Conditional debug output:**
```yaml
{{- if .Values.debug }}
DebugInfo:
  Values: {{ toYaml .Values | indent 4 }}
  Chart: {{ toYaml .Chart | indent 4 }}
{{- end }}
```

#### Advanced Debugging

**Debug with custom values file:**
```yaml
# Create debug-values.yaml
debug: true
# ... other values

helm template my-release ./my-chart --values debug-values.yaml
```

**Debug specific template functions:**
```yaml
# Test template functions
{{ printf "Name: %s, Version: %s" .Chart.Name .Chart.Version }}
```

**Debug whitespace issues:**
```yaml
# Add visible markers for whitespace debugging
{{ printf "---START---" }}
content: value
{{ printf "---END---" }}
```

**Debug YAML structure:**
```bash
helm template my-release ./my-chart | kubectl apply --dry-run=client -f -
```
Validate the rendered YAML with kubectl for syntax errors.

#### Debugging Release Issues

**Inspect deployed release:**
```bash
helm get manifest my-release
```
Shows the rendered manifests that were actually deployed.

**Compare with local rendering:**
```bash
# Get deployed manifest
helm get manifest my-release > deployed.yaml

# Get local render
helm template my-release ./my-chart > local.yaml

# Compare
diff deployed.yaml local.yaml
```

**Debug upgrade issues:**
```bash
helm upgrade my-release ./my-chart --dry-run --debug
```
Test upgrades without applying changes.

#### Common Template Errors and Solutions

**"undefined variable" errors:**
- Check variable scope - variables defined in loops are local to that iteration
- Use `$` to access root context when needed

**YAML indentation issues:**
- Use proper whitespace control (`{{- -}}`)
- Test with `helm template | yamllint`

**Function errors:**
- Verify function parameters are correct types
- Use `default` for optional values

**Loop errors:**
- Ensure you're iterating over the correct data structure
- Check for nil values in loops

**Best practices for debugging:**
- Start with `helm template` for basic rendering
- Use `--debug` flag for detailed error information
- Add temporary debug output and remove it when fixed
- Test incrementally - add one feature at a time
- Use `helm lint` regularly during development
- Validate YAML syntax with external tools

**Practical scenario:** When a template fails to render, start with `helm template --debug` to see the error, then add debug output like `{{ toYaml .Values | indent 2 }}` to inspect the data being passed to the template.

### Testing and Validating Charts

- **Render templates locally** (without installing):
  ```
  helm template my-release ./my-chart
  ```
  Shows the generated YAML manifests.

- **Lint the chart** for common issues:
  ```
  helm lint ./my-chart
  ```
  Checks for syntax errors, missing required fields, etc.

- **Dry-run installation**:
  ```
  helm install --dry-run my-release ./my-chart
  ```
  Validates the chart without deploying to the cluster.

### Packaging and Distributing

Packaging turns your chart directory into a distributable archive that can be shared, versioned, and installed from repositories.

- **Package the chart** into a .tgz file:
  ```
  helm package ./my-chart
  ```
  This validates the chart structure, compresses all files into a tarball, and names it based on the chart name and version (e.g., `my-chart-0.1.0.tgz`).

  **Common options:**
  - `--version <version>`: Override the chart version in the package
  - `--app-version <version>`: Override the app version
  - `--destination <dir>`: Specify output directory (default: current directory)
  - `--sign`: Sign the package with GPG (for security)

  **Example with custom version:**
  ```
  helm package ./my-chart --version 1.0.0 --destination ./packages
  ```
  Creates `my-chart-1.0.0.tgz` in the `./packages` directory.

- **Push to a repository**: Upload the package to your Helm repository or OCI registry.
  - For traditional Helm repos: Use your repo's upload mechanism
  - For OCI (e.g., Docker registries): `helm push my-chart-0.1.0.tgz oci://registry.example.com/charts`

**Practical scenario:** After testing your chart locally, package it with `helm package` and upload to a shared repository so your team can install it consistently across environments.

### Advanced Topics

This section covers advanced Helm chart features that enable complex deployments, lifecycle management, and chart composition.

#### Dependencies

Helm charts can depend on other charts (subcharts) to compose complex applications. Dependencies are declared in `Chart.yaml` and managed automatically.

**Adding dependencies in Chart.yaml:**
```yaml
dependencies:
  - name: postgresql
    version: "12.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    alias: db  # Optional: rename for use in templates
  - name: redis
    version: "17.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: redis.enabled  # Conditional inclusion
    tags:  # Tag-based grouping
      - database
```

**Dependency properties:**
- `name`: The chart name
- `version`: Version constraint (supports semver ranges)
- `repository`: URL of the chart repository
- `alias`: Optional alias to avoid naming conflicts
- `condition`: Conditional inclusion based on values (e.g., `postgresql.enabled`)
- `tags`: Tag-based grouping for selective installation
- `import-values`: Import specific values from subcharts

#### Version Ranges and Constraints

Helm supports semantic versioning (semver) ranges for dependency version constraints, allowing flexible yet controlled dependency management.

**Basic version constraints:**

**Exact version:**
```yaml
dependencies:
  - name: postgresql
    version: "12.1.0"  # Exact version match only
```

**Caret ranges (^):**
Allows compatible updates within the same major version:
```yaml
dependencies:
  - name: postgresql
    version: "^12.1.0"  # >=12.1.0, <13.0.0
  - name: redis
    version: "^2.0.0"   # >=2.0.0, <3.0.0
```

**Tilde ranges (~):**
Allows patch-level updates within the same minor version:
```yaml
dependencies:
  - name: postgresql
    version: "~12.1.0"  # >=12.1.0, <12.2.0
  - name: redis
    version: "~2.1.0"   # >=2.1.0, <2.2.0
```

**Wildcard ranges (x):**
```yaml
dependencies:
  - name: postgresql
    version: "12.x.x"   # >=12.0.0, <13.0.0
  - name: redis
    version: "2.1.x"    # >=2.1.0, <2.2.0
```

**Comparison operators:**
```yaml
dependencies:
  - name: postgresql
    version: ">=12.0.0"    # Any version >= 12.0.0
  - name: redis
    version: "<3.0.0"      # Any version < 3.0.0
  - name: nginx
    version: ">=1.0.0 <2.0.0"  # Range between versions
```

**Logical AND (spaces):**
```yaml
dependencies:
  - name: postgresql
    version: ">=12.0.0 <13.0.0"  # Equivalent to ^12.0.0
```

**Logical OR (||):**
```yaml
dependencies:
  - name: postgresql
    version: "^12.0.0 || ^13.0.0"  # Either 12.x or 13.x versions
```

**Pre-release versions:**
```yaml
dependencies:
  - name: my-app
    version: "1.0.0-rc.1"  # Exact pre-release
  - name: my-app
    version: "1.0.0-*"     # Any 1.0.0 pre-release
```

**Version range examples:**

**Development environments:**
```yaml
# Allow latest patch versions for stability
dependencies:
  - name: postgresql
    version: "~12.1.0"  # 12.1.x versions only
  - name: redis
    version: "~6.2.0"   # 6.2.x versions only
```

**Production environments:**
```yaml
# Pin to specific versions for reproducibility
dependencies:
  - name: postgresql
    version: "12.1.4"   # Exact version
  - name: redis
    version: "6.2.1"    # Exact version
```

**Flexible updates:**
```yaml
# Allow minor version updates
dependencies:
  - name: postgresql
    version: "^12.1.0"  # 12.x versions
  - name: redis
    version: "^6.0.0"   # 6.x versions
```

**Multiple version support:**
```yaml
# Support both major versions
dependencies:
  - name: postgresql
    version: "^12.0.0 || ^13.0.0"
  - name: redis
    version: "^6.0.0 || ^7.0.0"
```

**Version constraint best practices:**

**For development:**
- Use caret ranges (`^`) for flexibility
- Allow minor version updates automatically
- Test regularly with `helm dependency update`

**For production:**
- Pin to specific versions for stability
- Use exact versions (`"1.2.3"`) for critical dependencies
- Update versions explicitly after testing

**For libraries:**
- Use tilde ranges (`~`) for patch-level updates
- Allow bug fixes but prevent breaking changes
- Consider compatibility carefully

**Version resolution:**
```bash
# Check which versions will be selected
helm dependency list ./my-chart

# Update to latest compatible versions
helm dependency update ./my-chart

# Lock specific versions
helm dependency build ./my-chart
```

**Troubleshooting version conflicts:**
```bash
# See detailed dependency resolution
helm dependency update ./my-chart --debug

# Check Chart.lock for locked versions
cat charts/*/Chart.lock
```

**Common version range patterns:**

| Pattern | Example | Meaning |
|---------|---------|---------|
| Exact | `"1.2.3"` | Only version 1.2.3 |
| Caret | `"^1.2.3"` | >=1.2.3, <2.0.0 |
| Tilde | `"~1.2.3"` | >=1.2.3, <1.3.0 |
| Wildcard | `"1.2.x"` | >=1.2.0, <1.3.0 |
| Range | `">=1.0.0 <2.0.0"` | Between 1.0.0 and 2.0.0 |
| OR | `"^1.0.0 || ^2.0.0"` | Either 1.x or 2.x |

**Practical scenarios:**

**Microservices architecture:**
```yaml
# Allow compatible updates for services
dependencies:
  - name: api-gateway
    version: "^2.1.0"
  - name: auth-service
    version: "^1.5.0"
  - name: user-service
    version: "^3.0.0"
```

**Database dependencies:**
```yaml
# Pin database versions for data compatibility
dependencies:
  - name: postgresql
    version: "12.1.4"    # Exact version for production
  - name: redis
    version: "~6.2.0"    # Allow patch updates
```

**Infrastructure components:**
```yaml
# Allow broader ranges for infra tools
dependencies:
  - name: ingress-nginx
    version: "^4.0.0"
  - name: cert-manager
    version: "^1.0.0"
```

**Managing dependencies:**
- **Update dependencies**: `helm dependency update ./my-chart`
  Downloads and locks subcharts to `charts/` directory, creating `Chart.lock` file.

- **Build dependencies**: `helm dependency build ./my-chart`
  Uses the locked versions from `Chart.lock` to ensure reproducible builds.

- **List dependencies**: `helm dependency list ./my-chart`
  Shows all dependencies and their status.

**Conditional dependencies:**
```yaml
# Chart.yaml
dependencies:
  - name: redis
    version: "17.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: redis.enabled

# values.yaml
redis:
  enabled: true  # Set to false to disable Redis dependency
```

**Tag-based dependencies:**
```yaml
# Chart.yaml
dependencies:
  - name: postgresql
    tags:
      - database
  - name: redis
    tags:
      - cache

# Install with specific tags
helm install my-release ./my-chart --set tags.database=true
```

**Using subchart values in templates:**
Access subchart values with the alias (or name):
```yaml
# In your template
{{ .Values.db.postgresql.auth.username }}  # If alias is 'db'
{{ .Values.postgresql.auth.database }}     # If no alias
```

**Importing values from subcharts:**
```yaml
# Chart.yaml
dependencies:
  - name: postgresql
    import-values:
      - child: service
        parent: database.service

# This imports postgresql.service values to database.service
```

**Dependency best practices:**
- Use aliases to avoid naming conflicts
- Pin versions for production stability
- Use conditions for optional dependencies
- Test dependency combinations thoroughly
- Keep dependency trees shallow

**Practical scenario:** For a web app chart, depend on PostgreSQL and Redis charts. During install, Helm fetches and installs all dependencies automatically, creating a complete stack.

#### Hooks

Lifecycle hooks allow running jobs at specific points during install/upgrade/delete operations, enabling complex deployment workflows.

**Hook types:**
- `pre-install`: Runs before resources are installed
- `post-install`: Runs after resources are installed
- `pre-upgrade`, `post-upgrade`: Before/after upgrades
- `pre-delete`, `post-delete`: Before/after deletion
- `pre-rollback`, `post-rollback`: Before/after rollbacks
- `test`: Runs when `helm test` is executed

**Hook annotations:**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ .Chart.Name }}-pre-install
  annotations:
    "helm.sh/hook": pre-install
    "helm.sh/hook-weight": "0"  # Execution order (lower numbers first)
    "helm.sh/hook-delete-policy": hook-succeeded  # When to delete hook
spec:
  template:
    spec:
      containers:
      - name: pre-install
        image: busybox
        command: ['sh', '-c', 'echo "Running pre-install hook"']
      restartPolicy: Never
```

**Hook delete policies:**
- `hook-succeeded`: Delete after successful execution
- `hook-failed`: Delete after failed execution
- `before-hook-creation`: Delete before creating new hook

**Detailed Hook Delete Policy Guide:**

**Understanding Hook Delete Policies:**

Hook delete policies control when Helm removes hook resources after execution. This is crucial for managing cluster resources and ensuring proper cleanup.

**Available Delete Policies:**

**1. `hook-succeeded` (Most Common):**
- **When it deletes:** After the hook completes successfully (exit code 0)
- **Use case:** Jobs that perform setup tasks, migrations, or validations
- **Behavior:** Hook resource remains until the operation succeeds, then gets cleaned up
- **Example:** Database initialization, certificate setup, cache warming

```yaml
annotations:
  "helm.sh/hook": pre-install
  "helm.sh/hook-delete-policy": hook-succeeded
```

**2. `hook-failed`:**
- **When it deletes:** After the hook fails (non-zero exit code)
- **Use case:** Cleanup operations that should run even if the main operation fails
- **Behavior:** Hook resource remains until failure, then gets cleaned up
- **Example:** Rollback scripts, error reporting, cleanup on failure

```yaml
annotations:
  "helm.sh/hook": post-upgrade
  "helm.sh/hook-delete-policy": hook-failed
```

**3. `before-hook-creation`:**
- **When it deletes:** Before creating a new hook with the same name
- **Use case:** Idempotent operations that can be safely rerun
- **Behavior:** Old hook gets deleted before new one is created
- **Example:** Configuration updates, service mesh injection

```yaml
annotations:
  "helm.sh/hook": pre-upgrade
  "helm.sh/hook-delete-policy": before-hook-creation
```

**Multiple Delete Policies:**

You can specify multiple policies separated by commas:

```yaml
annotations:
  "helm.sh/hook-delete-policy": hook-succeeded,hook-failed
```

**Common Policy Combinations:**

| Scenario | Recommended Policy | Reason |
|----------|-------------------|---------|
| Database migration | `hook-succeeded` | Keep migration job for debugging if it fails |
| Certificate setup | `hook-succeeded` | Certificate should persist until setup completes |
| Cleanup on failure | `hook-failed` | Ensure cleanup runs even if main operation fails |
| Idempotent setup | `before-hook-creation` | Safe to rerun without conflicts |
| Monitoring setup | `hook-succeeded,before-hook-creation` | Clean up old monitors, keep until success |

**Delete Policy Best Practices:**

**For `hook-succeeded`:**
- Use for jobs that perform critical setup
- Ensure hooks have proper error handling
- Consider using timeouts to prevent hanging resources
- Good for: DB migrations, cert generation, service configuration

**For `hook-failed`:**
- Use for cleanup operations
- Ensure cleanup logic is robust
- Consider resource constraints during cleanup
- Good for: Rollback operations, error reporting, emergency cleanup

**For `before-hook-creation`:**
- Use for idempotent operations
- Ensure operations can be safely interrupted and restarted
- Good for: Configuration updates, label modifications, non-destructive changes

**Advanced Delete Policy Patterns:**

**Conditional Cleanup:**
```yaml
{{- $deletePolicy := "hook-succeeded" }}
{{- if .Values.keepFailedHooks }}
{{- $deletePolicy = "hook-succeeded,hook-failed" }}
{{- end }}
annotations:
  "helm.sh/hook-delete-policy": {{ $deletePolicy }}
```

**Environment-Specific Policies:**
```yaml
{{- $deletePolicy := "hook-succeeded" }}
{{- if eq .Values.environment "development" }}
{{- $deletePolicy = "before-hook-creation" }}
{{- end }}
annotations:
  "helm.sh/hook-delete-policy": {{ $deletePolicy }}
```

**Debugging Hook Deletion:**

Check hook status:
```bash
# List all hooks for a release
kubectl get jobs -l app.kubernetes.io/managed-by=Helm

# Check hook logs
kubectl logs job/my-hook-job

# View hook annotations
kubectl describe job/my-hook-job
```

**Hook Deletion Troubleshooting:**

**Problem:** Hooks not deleting after completion
**Solution:** Check if the job actually succeeded (exit code 0)

**Problem:** Hooks accumulating in cluster
**Solution:** Review delete policies and ensure proper job completion

**Problem:** Hook conflicts on upgrade
**Solution:** Use `before-hook-creation` for idempotent operations

**Resource Management with Delete Policies:**

**Memory Considerations:**
- Failed hooks with `hook-failed` policy consume resources until cleanup
- Use resource limits on hook containers
- Monitor cluster resource usage

**Storage Considerations:**
- Hooks with persistent volumes need careful cleanup planning
- Use `pre-delete` hooks with `hook-succeeded` for backup operations

**Security Considerations:**
- Hook resources may contain sensitive data
- Ensure proper cleanup to prevent data leakage
- Use RBAC to limit hook access to necessary resources

**Complex hook example - Database migration:**
```yaml
# templates/hooks/pre-upgrade-migration.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "my-chart.fullname" . }}-migration
  annotations:
    "helm.sh/hook": pre-upgrade
    "helm.sh/hook-weight": "-5"  # Run before other pre-upgrade hooks
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      containers:
      - name: migration
        image: {{ include "my-chart.image" . }}
        command:
        - /app/migrate
        - --from-version={{ .Release.Revision }}
        env:
        - name: DATABASE_URL
          value: {{ include "my-chart.databaseUrl" . | quote }}
      restartPolicy: OnFailure
```

**Hook ordering:**
Use `helm.sh/hook-weight` to control execution order:
- Negative weights run first
- Zero is default
- Positive weights run later

**Conditional hooks:**
```yaml
{{- if .Values.migration.enabled }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "my-chart.fullname" . }}-migration
  annotations:
    "helm.sh/hook": pre-upgrade
spec:
  # ... hook definition
{{- end }}
```

**Hook best practices:**
- Keep hooks lightweight and fast
- Use appropriate delete policies
- Test hooks in isolation
- Handle hook failures gracefully
- Use weights for complex ordering

**Practical scenario:** Use pre-install hooks for database initialization, post-install hooks for health checks, and pre-upgrade hooks for data migrations.

**Detailed Hook Use Cases and Scenarios:**

**1. Database Initialization (pre-install):**
```yaml
# templates/hooks/pre-install-db-init.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "my-chart.fullname" . }}-db-init
  annotations:
    "helm.sh/hook": pre-install
    "helm.sh/hook-weight": "-10"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      containers:
      - name: db-init
        image: postgres:13
        command:
        - psql
        - -h
        - {{ .Values.postgresql.host }}
        - -U
        - {{ .Values.postgresql.auth.username }}
        - -c
        - |
          CREATE DATABASE IF NOT EXISTS {{ .Values.app.database }};
          CREATE USER IF NOT EXISTS {{ .Values.app.dbUser }} WITH PASSWORD '{{ .Values.app.dbPassword }}';
          GRANT ALL PRIVILEGES ON DATABASE {{ .Values.app.database }} TO {{ .Values.app.dbUser }};
        env:
        - name: PGPASSWORD
          value: {{ .Values.postgresql.auth.password }}
      restartPolicy: OnFailure
```

**2. Service Mesh Integration (post-install):**
```yaml
# templates/hooks/post-install-istio.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "my-chart.fullname" . }}-istio-inject
  annotations:
    "helm.sh/hook": post-install
    "helm.sh/hook-weight": "5"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      containers:
      - name: istio-inject
        image: istio/kubectl:1.17
        command:
        - kubectl
        - label
        - namespace
        - {{ .Release.Namespace }}
        - istio-injection=enabled
        - --overwrite
      serviceAccountName: {{ include "my-chart.serviceAccountName" . }}
      restartPolicy: OnFailure
```

**3. Certificate Management (pre-install):**
```yaml
# templates/hooks/pre-install-cert.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {{ include "my-chart.fullname" . }}-tls
  annotations:
    "helm.sh/hook": pre-install
    "helm.sh/hook-weight": "-5"
spec:
  secretName: {{ include "my-chart.fullname" . }}-tls-secret
  issuerRef:
    name: {{ .Values.certIssuer.name }}
    kind: {{ .Values.certIssuer.kind }}
  dnsNames:
  - {{ .Values.ingress.host }}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "my-chart.fullname" . }}-cert-wait
  annotations:
    "helm.sh/hook": pre-install
    "helm.sh/hook-weight": "-3"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      containers:
      - name: cert-wait
        image: bitnami/kubectl
        command:
        - sh
        - -c
        - |
          echo "Waiting for certificate..."
          kubectl wait --for=condition=Ready certificate/{{ include "my-chart.fullname" . }}-tls --timeout=300s
      serviceAccountName: {{ include "my-chart.serviceAccountName" . }}
      restartPolicy: OnFailure
```

**4. Cache Warming (post-install):**
```yaml
# templates/hooks/post-install-cache-warm.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "my-chart.fullname" . }}-cache-warm
  annotations:
    "helm.sh/hook": post-install
    "helm.sh/hook-weight": "10"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      containers:
      - name: cache-warm
        image: curlimages/curl
        command:
        - sh
        - -c
        - |
          # Warm up common endpoints
          curl -f {{ include "my-chart.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local/health || exit 1
          curl -f {{ include "my-chart.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local/api/v1/status || exit 1
      restartPolicy: OnFailure
```

**5. Monitoring Setup (post-install):**
```yaml
# templates/hooks/post-install-monitoring.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "my-chart.fullname" . }}-monitoring-setup
  annotations:
    "helm.sh/hook": post-install
    "helm.sh/hook-weight": "15"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      containers:
      - name: monitoring-setup
        image: bitnami/kubectl
        command:
        - sh
        - -c
        - |
          # Create Prometheus service monitor
          cat <<EOF | kubectl apply -f -
          apiVersion: monitoring.coreos.com/v1
          kind: ServiceMonitor
          metadata:
            name: {{ include "my-chart.fullname" . }}
            namespace: {{ .Release.Namespace }}
          spec:
            selector:
              matchLabels:
                app.kubernetes.io/name: {{ include "my-chart.name" . }}
            endpoints:
            - port: http
              path: /metrics
          EOF
      serviceAccountName: {{ include "my-chart.serviceAccountName" . }}
      restartPolicy: OnFailure
```

**6. Backup and Cleanup (pre-delete):**
```yaml
# templates/hooks/pre-delete-backup.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "my-chart.fullname" . }}-backup
  annotations:
    "helm.sh/hook": pre-delete
    "helm.sh/hook-weight": "-10"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      containers:
      - name: backup
        image: postgres:13
        command:
        - pg_dump
        - -h
        - {{ .Values.postgresql.host }}
        - -U
        - {{ .Values.postgresql.auth.username }}
        - {{ .Values.app.database }}
        - -f
        - /backup/{{ .Values.app.database }}-backup-$(date +%Y%m%d-%H%M%S).sql
        env:
        - name: PGPASSWORD
          value: {{ .Values.postgresql.auth.password }}
        volumeMounts:
        - name: backup-volume
          mountPath: /backup
      volumes:
      - name: backup-volume
        persistentVolumeClaim:
          claimName: {{ include "my-chart.fullname" . }}-backup-pvc
      restartPolicy: OnFailure
```

**7. Integration Testing (post-upgrade):**
```yaml
# templates/hooks/post-upgrade-integration-test.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "my-chart.fullname" . }}-integration-test
  annotations:
    "helm.sh/hook": post-upgrade
    "helm.sh/hook-weight": "20"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      containers:
      - name: integration-test
        image: {{ include "my-chart.image" . }}
        command:
        - npm
        - test
        - --integration
        env:
        - name: APP_URL
          value: http://{{ include "my-chart.fullname" . }}:{{ .Values.service.port }}
        - name: DB_HOST
          value: {{ .Values.postgresql.host }}
        - name: DB_USER
          value: {{ .Values.app.dbUser }}
        - name: DB_PASSWORD
          value: {{ .Values.app.dbPassword }}
      restartPolicy: OnFailure
```

**Common Hook Patterns Reference:**

| Hook Type | Weight Range | Purpose | Delete Policy |
|-----------|-------------|---------|---------------|
| pre-install | -10 to -1 | Setup prerequisites | hook-succeeded |
| post-install | 1 to 10 | Post-deployment tasks | hook-succeeded |
| pre-upgrade | -10 to -1 | Pre-upgrade preparation | hook-succeeded |
| post-upgrade | 1 to 10 | Post-upgrade validation | hook-succeeded |
| pre-delete | -10 to -1 | Cleanup/backup | hook-succeeded |
| post-delete | 1 to 10 | Final cleanup | hook-succeeded |
| test | 0 to 5 | Validation testing | hook-succeeded |

#### Tests

Add test manifests to validate your chart after installation using Helm's testing framework.

**Test structure in templates/tests/:**
```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "my-chart.fullname" . }}-test-connection"
  annotations:
    "helm.sh/hook": test
spec:
  containers:
  - name: wget
    image: busybox
    command: ['wget']
    args: ['{{ include "my-chart.fullname" . }}:{{ .Values.service.port }}']
  restartPolicy: Never
```

**Running tests:**
```bash
helm test my-release
```

**Test with cleanup:**
```bash
helm test my-release --cleanup
# Automatically removes test pods after completion
```

**Test timeout:**
```bash
helm test my-release --timeout 300s
```

**Advanced test example:**
```yaml
# templates/tests/test-database.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "my-chart.fullname" . }}-test-db"
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-weight": "1"
spec:
  containers:
  - name: test-db
    image: postgres:13
    command: ['psql']
    args:
    - -h
    - {{ include "my-chart.fullname" . }}-postgresql
    - -U
    - {{ .Values.postgresql.auth.username }}
    - -c
    - "SELECT 1;"
    env:
    - name: PGPASSWORD
      value: {{ .Values.postgresql.auth.password }}
  restartPolicy: Never
```

**Test best practices:**
- Test actual connectivity, not just pod creation
- Use appropriate timeouts
- Clean up test resources
- Test both positive and negative scenarios
- Include database and service connectivity tests

**Practical scenario:** Create tests that verify your application starts correctly, connects to databases, and responds to HTTP requests.

#### Library Charts

Library charts provide reusable templates and helpers without generating Kubernetes resources directly.

**Creating a library chart:**
```yaml
# Chart.yaml
apiVersion: v2
name: my-library
description: A Helm library chart
type: library  # This marks it as a library chart
version: 1.0.0
```

**Library chart structure:**
```
my-library/
├── Chart.yaml
├── templates/
│   └── _helpers.tpl  # Contains reusable templates
└── values.yaml       # Default values for helpers
```

**Using library charts as dependencies:**
```yaml
# Parent Chart.yaml
dependencies:
  - name: my-library
    version: "1.0.0"
    repository: "https://my-repo.com"
```

**Library template example:**
```yaml
# my-library/templates/_helpers.tpl
{{/*
my-library.labels: Common labels for all resources
*/}}
{{- define "my-library.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
my-library.image: Generate full image reference
*/}}
{{- define "my-library.image" -}}
{{- $registry := .Values.image.registry | default "" }}
{{- $repository := .Values.image.repository }}
{{- $tag := .Values.image.tag | default .Chart.AppVersion }}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- else }}
{{- printf "%s:%s" $repository $tag }}
{{- end }}
{{- end }}
```

**Practical scenario:** Create a company-wide library chart with standard labels, image handling, and common resource templates that all team charts can depend on.

#### Custom Resource Definitions (CRDs)

Helm can manage CRDs for custom Kubernetes resources.

**CRD installation:**
```yaml
# templates/crds/mycrd.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: myresources.example.com
spec:
  group: example.com
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
  scope: Namespaced
  names:
    plural: myresources
    singular: myresource
    kind: MyResource
```

**CRD management best practices:**
- Use `apiextensions.k8s.io/v1` (v1 CRDs)
- Include CRDs in separate templates/crds/ directory
- Use `helm.sh/resource-policy: keep` for CRDs that shouldn't be deleted
- Test CRD installation order

**CRD upgrades:**
```yaml
metadata:
  annotations:
    "helm.sh/resource-policy": keep  # Don't delete on uninstall
```

#### Chart Security

Security considerations for Helm chart development and deployment.

**Image security:**
```yaml
# values.yaml
image:
  registry: my-registry.com
  repository: my-app
  tag: "1.2.3"
  pullPolicy: Always
  pullSecrets:
  - name: registry-secret
```

**RBAC considerations:**
```yaml
# templates/rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ include "my-chart.fullname" . }}
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

**Secret management:**
```yaml
# Avoid hardcoding secrets in values.yaml
# Use external secret management or sealed secrets
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "my-chart.fullname" . }}
type: Opaque
data:
  # Use base64 encoded values or external secret references
  password: {{ .Values.secret.password | b64enc }}
```

**Network policies:**
```yaml
# templates/network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "my-chart.fullname" . }}
spec:
  podSelector:
    matchLabels:
      {{- include "my-chart.selectorLabels" . | nindent 6 }}
  policyTypes:
  - Ingress
  - Egress
```

**Security best practices:**
- Use minimal RBAC permissions
- Scan images for vulnerabilities
- Avoid privileged containers
- Use network policies
- Implement resource limits
- Regular security audits

#### Chart Signing and Verification

Secure your Helm charts by signing them with GPG keys to ensure authenticity and integrity.

**Installing GPG (Key Generator):**

**On Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install gnupg
```

**On CentOS/RHEL:**
```bash
sudo yum install gnupg2
```

**On macOS:**
```bash
brew install gnupg
```

**On Windows:**
```bash
# Using Chocolatey
choco install gnupg

# Or download from https://gnupg.org/download/
```

**Verify GPG installation:**
```bash
gpg --version
```

**Generating GPG Keys:**

**1. Generate a new key pair:**
```bash
gpg --gen-key
```

**Interactive prompts:**
- Key type: RSA and RSA (default)
- Key size: 4096 bits
- Expiration: 0 (never expires) or set expiration
- Name, email, comment
- Passphrase: Choose a strong passphrase

**2. Alternative: Generate key with specific parameters:**
```bash
gpg --batch --gen-key <<EOF
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: Your Name
Name-Email: your.email@example.com
Expire-Date: 0
Passphrase: your-strong-passphrase
EOF
```

**3. List your keys:**
```bash
# List public keys
gpg --list-keys

# List secret keys
gpg --list-secret-keys
```

**Understanding Public/Private Key Cryptography:**

**How Public/Private Keys Work:**

- **Private Key**: Used to sign charts. Keep this secret and secure.
- **Public Key**: Used to verify signatures. Can be shared publicly.
- **Signing Process**: Private key creates a digital signature proving authenticity.
- **Verification Process**: Public key verifies the signature matches the chart content.

**Key Management Best Practices:**
- Store private keys securely (hardware security modules, encrypted storage)
- Use strong passphrases
- Regularly rotate keys
- Backup keys safely
- Never share private keys

**Signing Helm Charts:**

**1. Sign a chart package:**
```bash
# Sign the chart
helm package my-chart/
gpg --detach-sign my-chart-1.0.0.tgz

# This creates my-chart-1.0.0.tgz.asc (detached signature)
```

**2. Sign with specific key:**
```bash
# Use specific key ID
gpg --detach-sign --local-user KEY_ID my-chart-1.0.0.tgz
```

**3. Verify your signature:**
```bash
gpg --verify my-chart-1.0.0.tgz.asc my-chart-1.0.0.tgz
```

**4. Export public key for sharing:**
```bash
# Export public key
gpg --export --armor your.email@example.com > public-key.asc

# Export with specific key ID
gpg --export --armor KEY_ID > public-key.asc
```

**Verifying Charts During Installation:**

**1. Import the publisher's public key:**
```bash
# Import public key
gpg --import public-key.asc

# Verify import
gpg --list-keys
```

**2. Install chart with verification:**
```bash
# Install with signature verification
helm install my-release my-chart-1.0.0.tgz --verify

# Install from repository with verification
helm install my-release my-repo/my-chart --verify
```

**3. Verify chart before installation:**
```bash
# Download and verify chart
helm pull my-repo/my-chart --verify
```

**4. Enable verification globally:**
```bash
# Set global verification
helm plugin install https://github.com/helm/helm-sigstore
helm sigstore verify my-chart-1.0.0.tgz
```

**Repository Configuration for Signed Charts:**

**Configure repository with public key:**
```bash
# Add repository
helm repo add my-repo https://my-charts.example.com

# Import repository's public key
curl https://my-charts.example.com/public-key.asc | gpg --import

# Enable verification for repository
helm repo add my-repo https://my-charts.example.com --verify
```

**Chart.yaml Configuration for Signing:**

**Add provenance information:**
```yaml
# Chart.yaml
apiVersion: v2
name: my-chart
description: A signed Helm chart
version: 1.0.0
keywords:
- signed
- secure
home: https://example.com
sources:
- https://github.com/example/my-chart
```

**Advanced Signing Scenarios:**

**Multiple Signers (Threshold Signing):**
```bash
# Sign with multiple keys
gpg --detach-sign --local-user key1@example.com my-chart-1.0.0.tgz
gpg --detach-sign --local-user key2@example.com my-chart-1.0.0.tgz

# Verify multiple signatures
gpg --verify my-chart-1.0.0.tgz.asc my-chart-1.0.0.tgz
```

**CI/CD Pipeline Integration:**

**GitHub Actions example:**
```yaml
name: Sign and Publish Chart
on:
  push:
    tags:
      - 'v*'

jobs:
  sign-and-publish:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Install Helm
      run: |
        curl https://get.helm.sh/helm-v3.9.0-linux-amd64.tar.gz -o helm.tar.gz
        tar -zxvf helm.tar.gz
        sudo mv linux-amd64/helm /usr/local/bin/helm
    
    - name: Install GPG
      run: sudo apt-get install -y gnupg
    
    - name: Import GPG key
      run: |
        echo "${{ secrets.GPG_PRIVATE_KEY }}" | gpg --import --batch
    
    - name: Package and sign chart
      run: |
        helm package my-chart/
        gpg --detach-sign --pinentry-mode loopback --passphrase "${{ secrets.GPG_PASSPHRASE }}" --local-user ${{ secrets.GPG_KEY_ID }} my-chart-*.tgz
    
    - name: Publish to repository
      run: |
        # Upload chart and signature to repository
```

**Troubleshooting Chart Verification:**

**Common Issues:**

**1. "gpg: Can't check signature: No public key"**
```bash
# Import the correct public key
gpg --import publisher-public-key.asc
```

**2. "gpg: BAD signature"**
- Chart may be tampered with
- Check file integrity
- Contact publisher for new signature

**3. "helm: signature verification failed"**
```bash
# Check GPG version compatibility
gpg --version

# Re-import keys
gpg --import --refresh-keys
```

**4. Key expiration issues:**
```bash
# Check key expiration
gpg --list-keys --with-colons | grep ^pub

# Extend key expiration
gpg --edit-key KEY_ID
gpg> expire
# Follow prompts to set new expiration
```

**Security Considerations for Signed Charts:**

**Key Security:**
- Store private keys in HSMs or secure vaults
- Use key rotation policies
- Implement multi-signature requirements for critical charts

**Verification Policies:**
- Always verify charts in production
- Maintain allowlists of trusted publishers
- Regular key rotation and revocation

**Supply Chain Security:**
- Sign charts at build time
- Store signatures alongside charts
- Implement automated verification in CI/CD

**Practical scenario:** Implement chart signing in your organization to ensure that only authorized, unmodified charts are deployed to production environments, preventing supply chain attacks and ensuring chart integrity.

#### Chart Development Workflow

Advanced development practices for complex Helm charts.

**Chart versioning strategy:**
```yaml
# Chart.yaml
apiVersion: v2
name: my-chart
version: 1.2.3        # Chart version (semver)
appVersion: "2.1.0"   # Application version
```

**Development workflow:**
1. Use `helm create` for initial structure
2. Develop with `helm template --debug`
3. Test with `helm install --dry-run`
4. Lint with `helm lint`
5. Package with `helm package`
6. Publish to repository

**CI/CD integration:**
```yaml
# Example GitHub Actions
- name: Lint Helm charts
  run: |
    helm lint ./charts/*

- name: Test Helm charts
  run: |
    helm template test-release ./charts/my-chart > /dev/null

- name: Package charts
  run: |
    helm package ./charts/*
```

**Chart testing frameworks:**
- **helm-unittest**: Unit testing for Helm templates
- **helm-ct**: Chart testing with Kubernetes cluster
- **terratest**: End-to-end testing with Go

**Practical scenario:** Implement a comprehensive CI/CD pipeline that lints, tests, and packages charts automatically on commits, ensuring quality and reliability.

## Uninstalling Charts

Remove a release and its associated resources.

### Example: Uninstall MySQL
Uninstall the release:
```
helm uninstall mysql-release
```

Example output:
```
release "mysql-release" uninstalled
```

### Uninstall with History Preservation
To uninstall a release but keep its history for potential future reference or reinstallation:
```
helm uninstall mydb --keep-history
```

Example output:
```
release "mydb" uninstalled
```

This removes the deployed resources but retains the release records as Secrets in the cluster, allowing you to view history or rollback if needed.
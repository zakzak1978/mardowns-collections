# Dialogue: Configuring Azure Application Gateway
**Context:** A conversation between a tailored **Software Developer (Dev)** and a **DevOps/Infrastructure Engineer (Ops)**. The developer has a .NET application ready but has never configured an Application Gateway.

---

## 1. The "Why" and The Basics

**Developer:** Hey, I have my .NET Core application running on a few Virtual Machines, and I need to expose it to the internet securely. Can I just open Port 80 and 443 on the VMs directly?

**Infrastructure Engineer:** You *technically* could, but please don't. That exposes your servers directly to the wild. The standard pattern here is to use an **Azure Application Gateway**.

**Developer:** I've heard of that. Is that just a fancy Load Balancer?

**Infrastructure Engineer:** It is, but with a specific distinction. A standard Load Balancer works at Layer 4 (IPs and Ports). The Application Gateway is a **Layer 7 Load Balancer**.

**Developer:** Layer 7... so it sees the actual data?

**Infrastructure Engineer:** Exactly. It can read the URL path (like `/api/users`), the Host Headers (like `external.com`), and even the Cookies. This lets us do things like:
*   **SSL Termination:** Decrypt traffic at the gate so your servers don't have to burn CPU doing it.
*   **Path-Based Routing:** Send `/api/*` to one set of servers and `/images/*` to another.
*   **Web Application Firewall (WAF):** Block SQL Injection attacks before they even touch your code.

![Azure Application Gateway Architecture](images/azure/Azure_Application_Gateway_Architecture.png)

---

## 2. Paving the Road (Prerequisites)

**Developer:** Okay, I'm sold. I'm opening the Azure Portal creates wizard right now. It’s asking for a **Virtual Network**. Can I just pick the one my VMs are in?

**Infrastructure Engineer:** **Stop!** Do not pick the exact subnet where your VMs live.

**Developer:** Why?

**Infrastructure Engineer:** The Application Gateway needs its own **dedicated, empty subnet**. It scales horizontally by creating instances of itself, and it demands exclusive rights to that subnet.
1.  Go to your VNet.
2.  Create a new subnet named something like `snet-appgw-prod-001`.
3.  Put *nothing* else in there. Just the Gateway.

**Developer:** Got it. Created `snet-appgw`. What about the Tier? Standard V1 or V2?

**Infrastructure Engineer:** Always pick **Standard V2** or **WAF V2**. V1 is basically retired. V2 gives you autoscaling and much faster deployment times. Enable Autoscaling and set the instances from 0 to 10 for now.

---

## 2.1 Sidebar: Generating Certificates for Development

**Developer:** Wait, I don't actually have a certificate yet. I'm just testing. How do I create one?

**Infrastructure Engineer:** For production, you buy one from a CA...

**Developer:** "CA"?

**Infrastructure Engineer:** **Certificate Authority**. Companies like DigiCert, GoDaddy, or Let's Encrypt. They are "trusted third parties" that browsers automatically trust.

**Developer:** What if I just use this Self-Signed one in Production?

**Infrastructure Engineer:** **Don't.**
1.  **User Experience:** Every user will see a big red **"Your connection is not private"** warning. They won't proceed.
2.  **Trust:** It looks unprofessional and suspicious (like a phishing site).
3.  **Automation:** Many machines/APIs will flat-out refuse to connect.

For *local dev*, however, we just click "Proceed anyway" or install the cert into our local Trusted Root store. So for now:
You need two types of files:
1.  **.pfx (Private Key):** For the Gateway Listener.
2.  **.cer (Public Key):** For the Backend Settings (if doing End-to-End SSL).

Here is the cheat sheet to generate them:

### Option A: Using PowerShell (easiest for Windows)
Run this in an Admin PowerShell console:

```powershell
# 1. Create a Self-Signed Certificate
$cert = New-SelfSignedCertificate `
    -CertStoreLocation Cert:\CurrentUser\My `
    -DnsName "www.external.local" `
    -KeyExportPolicy Exportable

# 2. Export the PFX (For Config Step C - Listener)
# You MUST set a password
$password = ConvertTo-SecureString -String "P@ssword123!" -Force -AsPlainText
Export-PfxCertificate `
    -Cert $cert `
    -FilePath "c:\temp\external.pfx" `
    -Password $password

# 3. Export the CER (The Public Key - optional for Backend Settings)
Export-Certificate `
    -Cert $cert `
    -FilePath "c:\temp\external.cer"
```

### Option B: Using OpenSSL (Cross-platform)
If you are on Linux or Mac:

```bash
# 1. Generate the Private Key and CSR
openssl req -newkey rsa:2048 -nodes -keyout external.key -x509 -days 365 -out external.crt

# 2. Convert to PFX (For Gateway Listener)
openssl pkcs12 -export -out external.pfx -inkey external.key -in external.crt
```

**Developer:** I generated them, but how do I verify what's inside? Is there a command line for that?

**Infrastructure Engineer:** Yes, checking the "Subject" and "Issuer" is a good habit. Use `openssl`:

```bash
# View contents of a .cer / .crt (Public Key)
openssl x509 -in external.crt -text -noout

# View contents of a .pfx (Private Key container)
# You will be asked for the password
openssl pkcs12 -info -in external.pfx
```

**Infrastructure Engineer:** Save that `.pfx` file securely. You will need the password when we upload it to Key Vault later.

---

## 2.2 Two Critical Certificate Gotchas

**Developer:** Before we move on, is there anything else about certificates that usually trips people up?

**Infrastructure Engineer:** Yes, these two issues cause 90% of the support tickets I see:

### 1. The Missing Chain (Intermediate Certificates)
When you export your PFX, it **MUST** contain the full chain: `Root CA -> Intermediate CA -> Your Cert`.
*   **Symptom:** The site works fine on Chrome (Desktop) but fails on Android or iOS.
*   **Reason:** Desktop operating systems often cache Intermediate CAs. specific Mobile devices rely strictly on the server (Gateway) to verify the full chain.
*   **Fix:** Ensure your PFX export includes "All certificates in the certification path".

#### **Deep Dive: What is a "Full Chain" and how do I create it?**
**Developer:** How is it different from a normal cert?

**Infrastructure Engineer:** A "normal" file usually just has your Leaf certificate (your domain). A "Full Chain" is a bundle.

#### **Deep Dive: The Hierarchy of Trust (Root vs Intermediate)**

**Developer:** Can you explain the roles again? Why do we need the middleman? And can I create them myself?

**Infrastructure Engineer:**
1.  **Root CA ("The King"):**
    *   **Role:** The ultimate source of trust. This certificate is hard-coded into Windows, macOS, Android, etc.
    *   **Security:** The private key for a Public Root CA is literally kept in a bunker, offline, under armed guard. If this leaks, the entire internet stops trusting DigiCert/Microsoft. It is *almost never* used to sign actual websites.
2.  **Intermediate CA ("The Governor"):**
    *   **Role:** The King delegates authority to the Governor. The Root signs the Intermediate.
    *   **Security:** This key is online and used to sign your website certificates day-to-day. If this is compromised, the Root just revokes this one Intermediate, saving the Kingdom.
3.  **Leaf Cert ("The Citizen"):**
    *   **Role:** Your specific website. Signed by the Intermediate.

**Developer:** Can I create my own Root and Intermediate CA?

**Infrastructure Engineer:** Yes, you can (using OpenSSL). This is called a **Private PKI**.
*   **The Catch:** Your laptop trusts "DigiCert Root" by default. It does **not** trust "Developer's Custom Root".
*   **Usage:** Companies do this for internal intranet sites. IT pushes the "Company Root" to all employee laptops via Group Policy. Without that, your "Custom Root" is worthless to the outside world.

**Why the "Full Chain" matters:**
If you only send the Leaf to a mobile phone, it says: *"I trust the King (Root), but I don't know who this Governor (Intermediate) is who signed your Leaf. Denied."* You must send the Intermediate *with* the Leaf.

**How to create a Full Chain PFX (OpenSSL):**
You usually get three files from your provider: `domain.crt`, `intermediate.crt`, and `root.crt`.

1.  **Concatenate them (Order Matters!):**
    `Leaf` -> `Intermediate` -> `Root`
    ```bash
    cat domain.crt intermediate.crt root.crt > full-chain.pem
    ```
    *(Or just paste them one after another in Notepad if you are on Windows)*

2.  **Pack it into PFX:**
    ```bash
    openssl pkcs12 -export -out full-chain.pfx -inkey private.key -in full-chain.pem
    ```
    Now this `full-chain.pfx` is ready for the Gateway.

### 2. Key Vault Permissions
If you choose the Key Vault route (recommended):
*   **The Trap:** You create the Gateway and the Key Vault, but the Gateway stays in a "Failed" or "Updating" state.
*   **Reason:** The Application Gateway resource needs a **User Assigned Managed Identity**.
*   **Fix:** You must go to the Key Vault -> Access Policies (or RBAC) and grant that Identity **"Get"** and **"List"** permissions for **Secrets** (and Certificates). Without this, the Gateway is blind.

---

## 2.3 Sidebar: The Network Landscape (DNS & Load Balancers)

**Developer:** While we are on "Prerequisites", I see terms like DNS Zones, Private Zones, and "Load Balancer" (without Gateway) in the portal. Can we clarify those?

**Infrastructure Engineer:** Absolutely. The glossary matters.

### 1. Azure Load Balancer (Layer 4) vs App Gateway (Layer 7)
*   **App Gateway (L7):** Understands HTTP. Use this for Web Apps/APIs. It handles SSL, Paths, and WAF.
*   **Azure Load Balancer (L4):** Dumb pipe. It just flings TCP/UDP packets.
    *   *When to use L4:* SQL Server Clusters, TCP protocols, or non-HTTP traffic.

### 2. DNS Zones vs. Private DNS Zones
*   **DNS Zone (Public):** This is for the internet. If you own `external.com`, you manage it here. It resolves to your **Public IP**.
*   **Private DNS Zone:** This is for your internal Virtual Network.
    *   *Scenario:* Your App Gateway needs to talk to a backend VM named `db-primary`.
    *   *Usage:* You create a Private Zone `internal.no`. You add an A Record `db-primary -> 10.0.0.4`. Now your App can just call `db-primary` instead of the IP.

### 3. DNS Record Types (The Variables of the Web)
*   **A Record:** Maps a Name to an **IP Address**.
    *   *Ex:* `api.external.com -> 203.0.113.5`
*   **CNAME Record:** Maps a Name to **Another Name**.
    *   *Ex:* `www.external.com -> external-gw.eastus.cloudapp.azure.com`
    *   *Tip:* **Always use CNAMEs** for Application Gateway Frontend. If Azure changes the underlying Public IP hardware (rare but possible in some SKUs), the DNS name remains valid.
*   **TXT Record:** Used for verification (proving you own the domain) or email security (SPF).
*   **MX Record:** Mail Exchange. Where to send emails.

---

## 2.4 Sidebar: The Kubernetes Edition (AKS & AGIC)

**Developer:** What if I decide to ditch VMs and use **Kubernetes (AKS)**? How do these "DNS Zones" and "Gateways" fit together then?

**Infrastructure Engineer:** The components are the same, but the *wiring* changes. In Kubernetes, we use the **Application Gateway Ingress Controller (AGIC)**.

### The New Architecture:
Instead of you clicking buttons in the Portal to add "Backend Pools", the AKS Cluster talks to the Gateway for you.

1.  **Public DNS Zone:**
    *   You create a record `k8s.external.com` pointing to the **App Gateway's Public IP**.
2.  **The App Gateway (Ingress):**
    *   It sits *outside* the cluster.
    *   It terminates SSL.
3.  **The AKS Cluster (Backend):**
    *   You install the **AGIC Pod** inside your cluster.
    *   You write a generic Kubernetes YAML file (`Ingress` resource).
    *   **Magic:** AGIC reads your YAML and *automatically* configures the Azure Application Gateway via Azure APIs. It adds the listeners, rules, and backend pools for you.
4.  **Internal DNS (CoreDNS):**
    *   Inside the cluster, services talk to each other using internal names (e.g., `user-service.default.svc`). The App Gateway doesn't care about this; it just dumps traffic onto the Pod IPs directly (if using Azure CNI).

**Summary:** In the AKS world, you manage the Gateway via YAML files in your code repo, not the Azure Portal.

#### **Scenario: "We have an Internal Domain"**
**Developer:** One catch—we use an **internal domain** (`www.internal.no`) inside the cluster. We don't want this exposed to the public internet.

**Infrastructure Engineer:** Then you need a **Private Ingress** setup.
1.  **Frontend:** Configure the Application Gateway with a **Private IP Frontend** (e.g., `10.0.1.50`) from its own subnet.
2.  **DNS:** Create an **A Record** in your **Private DNS Zone**: `www.internal.no -> 10.0.1.50`.
3.  **AGIC Annotation:** In your Ingress YAML, you must explicitly tell AGIC to use the private IP:
    ```yaml
    annotations:
      appgw.ingress.kubernetes.io/use-private-ip: "true"
    ```
    Now, only users on your VPN or VNet can reach `www.internal.no`.

#### **Scenario: "We use Nginx Ingress (No AGIC)"**
**Developer:** Actually, we don't want AGIC. We love our standard Nginx Ingress Controller. We just want the Gateway for WAF security.

**Infrastructure Engineer:** Ah, the "Double Hop" architecture. This is very common.
1.  **Topology:**
    *   **App Gateway (Outer Gate):** Handles WAF and Public SSL.
    *   **Nginx Ingress (Inner Gate):** Handles complex routing rules inside the cluster.
2.  **Configuration:**
    *   **Backend Pool:** You point the Gateway to the **Internal Load Balancer IP** of your Nginx Service (e.g., `10.0.5.100`).
    *   **Traffic Flow:** User -> App Gateway -> Nginx Ingress -> Your Pod.
3.  **The "Host" Header Catch:**
    *   The Gateway MUST preserve the Host Header (`external.com`). If it changes it to the IP address, Nginx won't know which site to serve. Ensure **"Override with new host name"** is **Disabled** in Backend Settings.

#### **Scenario: "We have multiple Ingress files (Microservices)"**
**Developer:** We have 50 services (API, Web, Auth), each with its own `ingress.yaml` file. Does the App Gateway need to know about all 50?

**Infrastructure Engineer:**
*   **With Nginx (Your setup):** **NO.**
    *   **App Gateway:** Has ONE wildcard listener (`*.external.com`) sending traffic to Nginx. It is "dumb" regarding the routes.
    *   **Nginx:** Nginx reads all 50 Ingress files and routes `/api` to OrderService and `/web` to UI.
    *   *Benefit:* You can add 100 new services without ever touching the App Gateway (or Terraform) again.
*   **With AGIC:** **YES.**
    *   AGIC would read all 50 files and constantly update the Azure Gateway rules. This can hit Azure API limits if you scale too big.

#### **Scenario: "The Hostname Mismatch (Public vs Internal)"**
**Developer:** One complication: Our Ingress explicitly looks for `www.internal.no`, but users hit `www.external.com`.

**Infrastructure Engineer:**
*   **The Problem:** The request hits Nginx with `Host: www.external.com`. Nginx checks its list, sees only `www.internal.no`, and returns **404 Not Found**.
*   **The Fix:** You must enable **"Override with specific domain name"** in the App Gateway **Backend Settings** and set it to `www.internal.no`.
*   **Warning:** This breaks the "Generic/Dumb Gateway" model. You can no longer use a single Wildcard rule. You now need a specific App Gateway Rule for *every* service that needs a name rewrite. **Recommendation:** Update your Ingress to listen on `www.external.com` instead.

---

## 3. Connecting the Dots (The Configuration Flow)

**Developer:** Okay, resources are created. Now the wizard is asking for "Frontends", "Backends", and "Routing Rules". It feels a bit disjointed.

**Infrastructure Engineer:** It is a bit modular. Think of it as a chain. I'll walk you through the chain from the outside world into your app.

### Step A: The Frontend (The Door)

**Developer:** I assume **Frontend IP** is just the public IP users hit?

**Infrastructure Engineer:** Correct. Just create a new Public IP. This is what your DNS (like `www.external.com`) will point to eventually.

### Step B: The Backend Pool (The Destination)

**Developer:** Now for the **Backend Pool**. This is where I list my VMs?

**Infrastructure Engineer:** Yes. Name it `pool-dotnet-app`.
*   Since you are using VMs, select **IP address or FQDN** and type in the *private* IPs of your VMs.
*   *Note:* If you were using App Services, you'd pick "App Services" here instead.

![Backend Pool Example](https://raw.githubusercontent.com/MicrosoftDocs/azure-docs/main/articles/application-gateway/media/application-gateway-components/application-gateway-components.png)

### Step C: The Listener (The Doorman)

**Developer:** Okay, I have an IP and I have servers. How do I bridge them?

**Infrastructure Engineer:** You need a **Routing Rule**. But first, the rule needs a **Listener**.
The Listener stands at the door (Frontend IP) and listens for specific traffic, usually on Port 443 (HTTPS).

**Developer:** HTTPS means I need a certificate. Should I manually upload my `.pfx` file here?

**Infrastructure Engineer:** You *can*, but it's not the best practice.
1.  **Manual Upload:** You upload the `.pfx` directly to the Gateway.
    *   *Problem:* When it expires, you have to manually upload the new one. If you forget, your site goes down.
2.  **Key Vault Integration (Recommended):** You store the certificate in **Azure Key Vault**.
    *   *Benefit:* The Gateway acts as a "User Assigned Identity" and reads the cert from the Vault.
    *   *Auto-Rotation:* If you update the cert in Key Vault, the Gateway automatically picks up the new version within 4 hours. No downtime.

**Developer:** Key Vault sounds safer. I'll use that.

**Infrastructure Engineer:** Good choice. In the Listener config:
*   **Protocol:** HTTPS.
*   **Certificate Source:** Select "Key Vault".
*   **Listener Type:** 
    *   **Basic:** If this Gateway hosts only ONE domain (e.g., `external.com`).
    *   **Multi-site:** If you plan to host multiple domains (e.g., `api.external.com` AND `store.external.com`) on this single IP. You'll need wildcards or multiple listeners for this.

### Step C.1: Deep Dive - Wildcards & SNI

**Developer:** Hold on, can we pause on "Multi-site"? I have `api.external.com` and `admin.external.com`. Do I need two listeners?

**Infrastructure Engineer:** You have two options, and this is where **Wildcards** and **SNI** come in.

#### Option 1: Wildcard Certificate
You buy ONE certificate for `*.external.com`.
*   **How it works:** This single certificate is valid for `api.external.com`, `admin.external.com`, `blog.external.com`, etc.
*   **Config:** You create **one** "Basic" Listener with this wildcard cert.
*   **Pros:** Simple management. One cert to renew.
*   **Cons:** If the private key leaks, *all* your subdomains are compromised.

#### Option 2: Server Name Indication (SNI)
You have `external.com` and `totally-different-site.com`. A wildcard won't work here because the domains don't match.
*   **The Problem:** In the old days, one IP address = one Certificate.
*   **The Solution (SNI):** SNI acts like an apartment number for your IP address. When the client (Browser) connects, it "shouts" the hostname it wants (`"Hey, I'm looking for external.com!"`) *during* the handshake.
*   **Application Gateway:** Because of SNI, the Gateway knows:
    *   "Oh, he wants `external.com`, let me present the `external.com` certificate."
    *   "Oh, she wants `other.com`, let me present the `other.com` certificate."
*   **Config:** You create **Multiple Listeners** (Multi-site) on the same Port 443, each with a different Hostname and a different Certificate.

**Developer:** Got it. Since I own `external.com` and all its subdomains, I'll stick with a Wildcard for simplicity.

### Step D: Backend Settings (The Translator)

**Developer:** The wizard is asking for **Backend Settings** (used to be called HTTP Settings). This part confuses me. I already defined the Backend Pool.

**Infrastructure Engineer:** The Pool is *who* to talk to. The Settings are *how* to talk to them. This is critical for .NET apps.
You have a choice here:

1.  **Offloading (HTTP):** The Gateway decrypts the SSL, and talks to your backend VM over port 80 (Unencrypted).
    *   *Pro:* Faster application performance.
    *   *Con:* Traffic between Gateway and VM is clear text (though usually safe inside the VNet).
2.  **End-to-End SSL (HTTPS):** The Gateway talks to your VM over port 443 (Re-encrypted).
    *   *Pro:* Zero Trust security model.
    *   *Con:* Your VM needs a certificate too, and you must configure the Gateway to **trust** that certificate.

**Developer:** What do you mean "trust"?

**Infrastructure Engineer:** Even if your backend has a cert, the Application Gateway is strict.
*   **Public CA:** If your backend uses a standard GoDaddy/DigiCert cert, the Gateway trusts it automatically ("Well-Known CA").
*   **Self-Signed/Private CA:** If you used a self-signed cert on the VM for internal testing, you MUST export the public key (`.cer` file) and upload it here in the Backend Settings as a "Trusted Root Certificate". Otherwise, the Gateway will reject the connection with a 502 error.

**Developer:** Let's go with **Offloading (HTTP)** for now to keep it simple. My VNet is locked down anyway.

**Infrastructure Engineer:** Okay, set Protocol to **HTTP** and Port **80**.
But wait—**Critical Setting**: Look for **"Cookie-based affinity"**.
*   Does your app store session data in-memory (In-Process)?

**Developer:** Yes, we use standard ASP.NET Session.

**Infrastructure Engineer:** Then enable **Cookie-based affinity**. This ensures that User A is always routed to Server 1. If you don't do this, their session will vanish if the Gateway routes their next request to Server 2.

**Developer:** Good catch. What about "Pick host name from backend target"?

**Infrastructure Engineer:**
*   **For VMs:** Usually leave it "No", unless your IIS bindings require a specific hostname.
*   **For App Service:** You **MUST** set this to "Yes". App Service ignores requests that don't have the correct Host header.

---

## 4. The Health Probe (The Pulse Check)

**Developer:** Usually, setup ends here, but you mentioned Health Probes?

**Infrastructure Engineer:** If you don't configure this, you will see a **502 Bad Gateway**.
By default, the Gateway checks `http://<vm-ip>/`. If your app acts weird on the root path, the Gateway thinks it's dead.

**Developer:** My app responds at `/api/health`.

**Infrastructure Engineer:** Perfect. Create a **Custom Health Probe**:
1.  **Path:** `/api/health`
2.  **Protocol:** HTTP
3.  **Host:** Check "Pick host name from backend settings".
4.  **Match:** 200-399.

This tells the Gateway: "Poll this URL every 30 seconds. If it doesn't return 200 OK, take that specific VM out of rotation."

![Health Probe Diagram](https://raw.githubusercontent.com/MicrosoftDocs/azure-docs/main/articles/application-gateway/media/application-gateway-probe-overview/appgatewayprobe.png)

---

## 5. Troubleshooting Common Developer Issues

**Developer:** Done! Converting... Deploying... Okay, it's running.
I'm testing it, but I have a few concerns.

### Scenario 1: The Infinite Loop
**Developer:** My code has a distinct redirect: `app.UseHttpsRedirection()`. But now that I'm behind the Gateway, my browser just says "Too many redirects".

**Infrastructure Engineer:** standard issue.
1.  User starts with **HTTPS** -> Hits Gateway.
2.  Gateway decrypts and sends **HTTP** -> Hits App.
3.  App sees **HTTP**, trigger `UseHttpsRedirection` -> Sends user back to **HTTPS**.
4.  User hits Gateway **HTTPS**...
5.  Gateway sends **HTTP**... Loop.

**Fix:** You need to tell your .NET app to trust the `X-Forwarded-Proto` header. The Gateway adds this header to say "Hey, the original request was HTTPS". In your `Startup.cs` or `Program.cs`, ensure `ForwardedHeadersOptions` is configured to read that header.

### Scenario 2: The 502
**Developer:** I just deployed a bug, and now the site says **502 Bad Gateway**.

**Infrastructure Engineer:** That means all your backend nodes are failing the **Health Probe**.
*   Did you crash the app?
*   Did the Probe path change?
*   Check "Backend Health" in the portal. It will tell you exactly why it marked the servers as "Unhealthy".

---

## 6. Summary Checklist

**Developer:** Use dedicated subnet `snet-appgw`.
**Developer:** Use Listeners for the public face (443).
**Developer:** Use Backend Settings to define the internal connection (80/443).
**Developer:** Always set up a custom Health Probe.
**Developer:** Handle `X-Forwarded-Proto` in code.

**Infrastructure Engineer:** You got it. Once everything is green in "Backend Health", go to your DNS provider and create a CNAME pointing `www` to the Application Gateway's public DNS name. You're live!

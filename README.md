# Registry Provisioner

**Automated Harbor provisioning on Mgmt KaaS using Envoy Gateway and self-signed TLS for multi-cluster environments.**

This repository provides a streamlined, template-driven toolkit to provision [Harbor](https://goharbor.io/) on a Management Kubernetes cluster (Mgmt KaaS) using **Envoy Gateway (Gateway API)**. It features an automated self-signed certificate generator, strict input validation, and a zero-touch configuration DaemonSet for Workload KaaS clusters to securely access the registry.

## 📂 Project Structure

```text
registry-provisioner/
├── Makefile                   # Central command interface
├── config.env                 # Global configuration variables
├── cert-generator.sh          # Generates Root CA and Server certificates
├── manifest-generator.sh      # Renders K8s YAMLs based on cluster mode
├── clean.sh                   # Workspace cleanup utility
├── templates/                 # Base templates for all configurations
│   ├── harbor-gateway.yaml.tmpl
│   ├── harbor-values.yaml.tmpl
│   ├── mgmt-secret.yaml.tmpl
│   └── workload-setup.yaml.tmpl
├── harbor-cert/               # (Auto-generated) Contains certificates
└── manifests/                 # (Auto-generated) Outputs
    ├── management/            # Manifests for Mgmt KaaS
    └── workload/              # Manifests for Workload KaaS

```

## 📋 Prerequisites

* **Kubernetes Cluster** up and running (Management and Workload).
* **Helm v3** installed.
* **Envoy Gateway** installed on the Mgmt KaaS (with a `GatewayClass` named `eg`).
* **PureLB** configured to assign external IPs to the Envoy Gateway.

---

## ⚙️ Configuration

Update the `config.env` file to set your environment variables (e.g., Domain Name, Namespace) before running any commands.

---

## 🚀 Deployment Workflow

The installation requires a two-phase logical approach:

1. Deploy Harbor to the Management Cluster to trigger Gateway IP allocation.
2. Generate and apply the routing configuration to the Workload Clusters using the newly assigned IP.

### Phase 1: Management Cluster Deployment

⚠️ **Ensure your `kubectl` context is set to your Management Cluster.**

**Step 1.1: Generate Certificates**

```bash
make cert-gen

```

**Step 1.2: Generate Management Manifests**
Generate the YAML files required for the Management cluster. (Optionally provide an admin password).

```bash
make manifest-mgmt PASS="MySecurePassword123!"

```

**Step 1.3: Deploy Harbor & Gateway API**
Deploy the generated manifests from the `manifests/management/` directory.

```bash
helm repo add harbor https://helm.goharbor.io
helm repo update
kubectl create namespace harbor

kubectl apply -f manifests/management/mgmt-secret.yaml
helm upgrade --install harbor harbor/harbor -n harbor -f manifests/management/harbor-values.yaml
kubectl apply -f manifests/management/harbor-gateway.yaml

```

**Step 1.4: Retrieve the Allocated Gateway IP**
Verify that the Gateway is `PROGRAMMED` and note the `ADDRESS` assigned by PureLB.

```bash
kubectl get gateways.gateway.networking.k8s.io harbor-gateway -n harbor

```

*Expected Output:*

```text
NAME             CLASS   ADDRESS          PROGRAMMED   AGE
harbor-gateway   eg      192.168.100.10   True         1m

```

*(In this example, the actual assigned IP is `192.168.100.10`)*

---

### Phase 2: Workload Cluster Setup (Zero-Touch)

**Step 2.1: Generate Workload Manifests**
Using the IP retrieved in Step 1.4, generate the Workload configuration.

```bash
make manifest-workload IP=192.168.100.10

```

**Step 2.2: Apply to Workload Clusters**
⚠️ **Switch your `kubectl` context to your Workload KaaS.**

Apply the setup manifest from the `manifests/workload/` directory. This will automatically configure all current and future nodes.

```bash
kubectl apply -f manifests/workload/workload-setup.yaml

```

---

## 🧹 Workspace Cleanup

To reset your workspace and securely remove all auto-generated directories (`harbor-cert/` and `manifests/`), run:

```bash
make clean

```

---

## ✅ Verification


Once both phases are complete, verify the end-to-end functionality.

### 1. Management Cluster Checks
Switch to your **Mgmt KaaS context** and verify the core components.

**Check Harbor Pods:**
```bash
kubectl get pods -n harbor

```

*Expected Output:*

```text
NAME                                 READY   STATUS    RESTARTS      AGE
harbor-core-7c5cd65c79-8j79v         1/1     Running   0             1m
harbor-database-0                    1/1     Running   0             1m
harbor-jobservice-857c64bb8d-tlbfq   1/1     Running   0             1m
harbor-nginx-74fdd4ff86-pvfq7        1/1     Running   0             1m
harbor-portal-787564b9b9-rjkx4       1/1     Running   0             1m
harbor-redis-0                       1/1     Running   0             1m
harbor-registry-78dcb9d6dc-zcrlp     2/2     Running   0             1m
harbor-trivy-0                       1/1     Running   0             1m
```


**Check HTTPRoute:**

```bash
kubectl get httproute harbor-route -n harbor

```

*Expected Output:*

```text
NAME           HOSTNAMES               AGE
harbor-route   ["harbor.petasus.io"]   74s

```

### 2. Workload Cluster Checks (Containerd & Nerdctl Test)

Connect to a worker node in your **Workload KaaS** to perform a real-world image push/pull test using `nerdctl`. Since we are using `containerd` natively, we will bypass strict TLS token matching bugs by directly configuring the OCI auth file.

**Step 1: Manually Configure Registry Authentication**
*Note: Even though we use `containerd`, `nerdctl` uses the `~/.docker/config.json` path for backward compatibility with credential helpers.*

```bash
# Encode Harbor admin credentials
AUTH=$(echo -n "admin:MySecurePassword123!" | base64)

# Create the auth configuration for nerdctl
sudo mkdir -p /root/.docker
sudo tee /root/.docker/config.json > /dev/null <<EOF
{
  "auths": {
    "harbor.petasus.io": {
      "auth": "$AUTH"
    }
  }
}
EOF

```

**Step 2: Pull a sample image (e.g., from Docker Hub)**

```bash
sudo nerdctl pull alpine:latest

```

**Step 3: Tag the image for the new Harbor Registry**
Format: `<REGISTRY_DOMAIN>/<PROJECT_NAME>/<IMAGE_NAME>:<TAG>`

```bash
sudo nerdctl tag alpine:latest harbor.petasus.io/library/alpine:test

```

**Step 4: Push the image to Harbor**
Use the `--insecure-registry` flag to bypass OS-level TLS checks for this self-signed environment.

```bash
sudo nerdctl push harbor.petasus.io/library/alpine:test --insecure-registry

```

*Expected Output:*

```text
harbor.petasus.io/library/alpine:test: resolving      |--------------------------------------| 
elapsed: 0.1 s                                        total:   0.0 B (0.0 B/s)                                         
layer-sha256:d4fc045c9e3a8480...: done                |++++++++++++++++++++++++++++++++++++++| 
config-sha256:b1d833fb357bf64e...: done               |++++++++++++++++++++++++++++++++++++++| 

```

### 3. Kubernetes Pod Image Pull Test

To verify that Kubernetes can natively pull from the registry using `containerd`, create an image pull secret.
*Note: The type is historically named `docker-registry` in K8s, but it natively supports standard OCI registries on containerd.*

```bash
kubectl create secret docker-registry harbor-login \
  --docker-server=harbor.petasus.io \
  --docker-username=admin \
  --docker-password=MySecurePassword123!

```


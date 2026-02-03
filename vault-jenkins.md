# Target Architecture (what we're building)

- **Vault VM** (separate)
    - Stores secrets securely
- **Jenkins VM**
    - Authenticates to Vault
    - Fetches secrets at runtime
- **Terraform**
    - Uses injected secrets

## Tools involved

- HashiCorp Vault
- Jenkins
- Terraform

## PART 1 — Run Vault Server on a Separate VM (FREE, SIMPLE)

### 1️⃣ Install Vault on Vault VM (Ubuntu example)

```bash
sudo apt-get update
sudo apt-get install -y gnupg curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
| sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update
sudo apt-get install -y vault
```

**Verify:**

```bash
vault version
```

### 2️⃣ Start Vault in DEV mode (demo-safe)

```bash
vault server -dev -dev-listen-address=0.0.0.0:8200
```

Vault will print:
- Vault address
- Root token (copy it)

> ⚠️ This is demo-only, but perfect for learning.

### 3️⃣ Open network access

Allow Jenkins VM → Vault VM on port 8200.

## PART 2 — Create Secrets in Vault

### 4️⃣ Configure Vault CLI

On Vault VM:

```bash
export VAULT_ADDR=http://<VAULT_VM_IP>:8200
export VAULT_TOKEN=<ROOT_TOKEN>
```

**Verify:**

```bash
vault status
```

### 5️⃣ Enable KV secrets engine (v2)

```bash
vault secrets enable -path=secret kv-v2
```

### 6️⃣ Create a secret (example DB credentials)

```bash
vault kv put secret/terraform/db \
    username="dbadmin" \
    password="SuperSecret123"
```

**Verify:**

```bash
vault kv get secret/terraform/db
```

- ✔ Secret stored
- ✔ No Git
- ✔ No Terraform state yet

## PART 3 — Jenkins Reads Secrets from Vault

### 7️⃣ Install Vault CLI on Jenkins VM

(You already asked this earlier; repeat same install steps.)

**Verify:**

```bash
vault version
```

### 8️⃣ Jenkins authenticates to Vault (DEMO TOKEN METHOD)

For demo simplicity (later we'll replace with AppRole):

On Jenkins VM:

```bash
export VAULT_ADDR=http://<VAULT_VM_IP>:8200
export VAULT_TOKEN=<ROOT_TOKEN>
```

> ⚠️ For demo only. Enterprise → AppRole (next step).

### 9️⃣ Test secret access from Jenkins VM

```bash
vault kv get secret/terraform/db
```

If this works → Jenkins can read Vault secrets.

## PART 4 — Jenkins Pipeline → Terraform (END-TO-END)

### 1️⃣0️⃣ Terraform code (NO secrets hardcoded)

**variables.tf**

```hcl
variable "db_username" {
    type = string
}

variable "db_password" {
    type      = string
    sensitive = true
}
```

**Example usage:**

```hcl
output "db_user" {
    value = var.db_username
}
```

### 1️⃣1️⃣ Jenkinsfile (KEY PART)

```groovy
pipeline {
    agent any

    environment {
        VAULT_ADDR = "http://<VAULT_VM_IP>:8200"
        VAULT_TOKEN = credentials('vault-root-token')   // stored securely in Jenkins
    }

    stages {
        stage('Read Secrets from Vault') {
            steps {
                script {
                    env.TF_VAR_db_username = sh(
                        script: "vault kv get -field=username secret/terraform/db",
                        returnStdout: true
                    ).trim()

                    env.TF_VAR_db_password = sh(
                        script: "vault kv get -field=password secret/terraform/db",
                        returnStdout: true
                    ).trim()
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                sh '''
                    terraform init
                    terraform apply -auto-approve
                '''
            }
        }
    }
}
```

### What happens here (VERY IMPORTANT)

1. Jenkins authenticates to Vault
2. Vault returns secrets
3. Jenkins injects them as:
     - `TF_VAR_db_username`
     - `TF_VAR_db_password`
4. Terraform automatically consumes them
5. Secrets never appear in Git
6. Jenkins masks secrets in logs
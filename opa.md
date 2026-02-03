# Policy-as-Code (PaC) – Implementation Overview

## 1️⃣ What is Policy-as-Code (PaC)?

Policy-as-Code means:

- Governance rules are written as code
- Stored in Git
- Automatically enforced before deployment
- Versioned, reviewed, and auditable

Instead of humans checking:
- "Did you enable encryption?"
- "Did you deploy in approved region?"

👉 Automation enforces it

## 2️⃣ Where PaC fits in Terraform lifecycle

```
terraform fmt
terraform init
terraform validate
tflint
checkov
OPA / Sentinel   <-- GOVERNANCE GATE
terraform plan
terraform apply
```

👉 PaC = last line of defense before deployment

## 3️⃣ Two Major PaC Tools in Terraform World

### 🔹 Open Policy Agent (OPA)

- Open-source
- Uses Rego language
- Works with:
    - Terraform
    - Kubernetes
    - CI/CD
- Terraform integration via Conftest

### 🔹 HashiCorp Sentinel

- Enterprise-only
- Built into:
    - Terraform Cloud
    - Terraform Enterprise
- Uses Sentinel language
- Tight integration with Terraform plan

## 4️⃣ OPA vs Sentinel (Conceptual Difference)

| Aspect | OPA | Sentinel |
|--------|-----|----------|
| License | Open-source | Commercial |
| Language | Rego | Sentinel |
| Terraform Plan Access | JSON output | Native |
| CI/CD Friendly | Very high | Limited |
| Terraform Cloud | Optional | Native |

## 5️⃣ Governance Rules We'll Enforce (Demo Scope)

We will enforce:

- Mandatory encryption
- Mandatory tags
- Region restriction

## PART A — OPA (Open Policy Agent) DEMO

## 6️⃣ OPA Architecture (Terraform)

```
Terraform → terraform plan -out
→ convert to JSON
→ OPA evaluates plan
→ Allow / Deny
```

## 7️⃣ Demo Setup

📁 Directory structure

```
opa-demo/
├── main.tf
├── policy/
│   └── terraform.rego
```

## 8️⃣ Insecure Terraform Code (main.tf)

```hcl
provider "aws" {
    region = "us-east-1"
}

resource "aws_s3_bucket" "demo" {
    bucket = "opa-demo-bucket"
}
```

❌ No encryption
❌ No tags

## 9️⃣ Generate Terraform Plan JSON

```bash
terraform init
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json
```

OPA evaluates tfplan.json

## 🔟 OPA Policy (terraform.rego)

Enforce S3 Encryption + Mandatory Tags

```rego
package terraform.security

deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    not resource.change.after.server_side_encryption_configuration
    msg := "S3 bucket must have encryption enabled"
}

deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    not resource.change.after.tags.Environment
    msg := "Missing mandatory tag: Environment"
}
```

## 1️⃣1️⃣ Run OPA Policy Check

```bash
opa eval --data policy/terraform.rego \
                 --input tfplan.json \
                 "data.terraform.security.deny"
```

Output:

```json
[
    "S3 bucket must have encryption enabled",
    "Missing mandatory tag: Environment"
]
```

❌ Deployment blocked

## 1️⃣2️⃣ Fix Terraform Code (Secure)

```hcl
resource "aws_s3_bucket" "demo" {
    bucket = "opa-demo-bucket"

    tags = {
        Environment = "dev"
    }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "enc" {
    bucket = aws_s3_bucket.demo.id

    rule {
        apply_server_side_encryption_by_default {
            sse_algorithm = "AES256"
        }
    }
}
```

Re-run plan + OPA → ✅ Allowed

## 1️⃣3️⃣ OPA Key Talking Point

> "OPA evaluates Terraform plans as data and enforces governance rules consistently across CI/CD pipelines, independent of cloud provider."

## PART B — Sentinel (Terraform Cloud / Enterprise)

## 1️⃣4️⃣ Sentinel Architecture

Terraform Cloud:

- Generates plan
- Sentinel automatically evaluates it
- Policy violations block apply
- No JSON conversion needed

## 1️⃣5️⃣ Sentinel Policy Example (sentinel.hcl)

Enforce Region Restriction

```sentinel
import "tfplan/v2" as tfplan

allowed_regions = ["us-east-1", "us-west-2"]

main = rule {
    all tfplan.resources.aws_instance as _, instances {
        all instances as _, instance {
            instance.applied.provider_config.region in allowed_regions
        }
    }
}
```

❌ Deploying to eu-central-1 → Blocked
✔ Allowed regions → Proceed

## 1️⃣6️⃣ Sentinel Policy – Mandatory Tags

```sentinel
main = rule {
    all tfplan.resources.aws_instance as _, instances {
        all instances as _, instance {
            instance.applied.tags.Environment is not null
        }
    }
}
```

## 1️⃣7️⃣ Sentinel Enforcement Levels

| Level | Meaning |
|-------|---------|
| advisory | Warning only |
| soft-mandatory | Override allowed |
| hard-mandatory | Block apply |

Enterprise governance = hard-mandatory

## 1️⃣8️⃣ OPA vs Sentinel – When to Use What

**Use OPA when:**

- Open-source stack
- CI/CD pipelines
- Multi-tool governance
- Kubernetes + Terraform together

**Use Sentinel when:**

- Terraform Cloud / Enterprise
- Centralized governance
- Strong audit & compliance needs
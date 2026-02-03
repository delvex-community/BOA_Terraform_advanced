# Terraform State Recovery (Enterprise / BOA Level)

## First, what "state recovery" really means

Terraform state recovery answers one question:

"If my terraform.tfstate is lost, corrupted, or out of sync — how do I safely recover control of my infrastructure?"

This is not optional knowledge in regulated environments.

## Why state loss is dangerous

Terraform state contains:

- Resource IDs (EC2 ID, ALB ARN, RDS ID)
- Dependencies
- Metadata Terraform needs to avoid re-creating infra

If state is lost:

- Terraform thinks nothing exists
- terraform apply may try to recreate prod
- Leads to outage or duplicate resources

➡️ This is why state recovery procedures must exist

## Common real-world failure scenarios

**Scenario A – Local state deleted**

Engineer deletes .terraform/ or terraform.tfstate. Infra still exists in AWS.

**Scenario B – State corruption**

Interrupted apply or partial write to state file.

**Scenario C – Wrong state applied**

Dev state used against prod or human error in CI/CD.

**Scenario D – Backend unavailable**

S3 issue or DynamoDB lock stuck.

## Prevention FIRST (BOA best practice)

Before recovery, banks design to avoid it:

**Mandatory controls**

- Remote backend (S3)
- Versioning enabled on state bucket
- DynamoDB state locking
- Restricted IAM access

This gives multiple recovery paths.

## State Recovery Techniques (Most Important Section)

### Technique 1: Recover from S3 Versioning (BEST & SAFEST)

**Why this is gold standard**

- Every state change = new version
- Recovery is instant and safe

**What BOA requires**

S3 bucket with:

- Versioning = ENABLED
- Encryption = ENABLED

**Recovery Steps**

1. Open S3 bucket
2. Enable "Show versions"
3. Identify last known good terraform.tfstate
4. Restore previous version

➡️ Terraform resumes normally
➡️ No infra change

### Technique 2: terraform init -reconfigure

**Used when:**

- Backend config changed
- State exists but Terraform can't read it

```bash
terraform init -reconfigure
```

**What it does:**

- Reconnects Terraform to backend
- Re-downloads state
- No modification
- Safe for prod when used carefully

### Technique 3: terraform state pull (Read-only recovery)

**Use case:**

State exists and you want a backup or inspection.

```bash
terraform state pull > backup.tfstate
```

Good for:

- Forensics
- Manual inspection
- Pre-recovery validation

### Technique 4: Re-import infrastructure (terraform import)

This is last-resort recovery.

**When needed**

- State is completely lost
- No S3 version
- Infra exists in AWS

**Example**

```bash
terraform import aws_instance.app i-0abc123456
```

**Reality check**

- Manual
- Time-consuming
- Error-prone
- Banks avoid reaching this stage by design

### Technique 5: Fix drift using terraform refresh

**Used when:**

- Infra modified manually
- State exists but values differ

```bash
terraform refresh
```

Terraform:

- Re-reads real infra
- Updates state
- No changes applied
- Safe but should not replace governance

## What NOT to do (Critical)

- ❌ Never manually edit state in prod
- ❌ Never run apply when state is uncertain
- ❌ Never share state bucket access widely
- ❌ Never mix envs in same state

## State Recovery Decision Matrix (Very Useful)

| Situation | Action |
|-----------|--------|
| State deleted | Restore S3 version |
| Backend changed | init -reconfigure |
| State drift | refresh |
| State lost completely | import |
| Lock stuck | Force-unlock (with approval) |

## Force Unlock (Danger Zone)

```bash
terraform force-unlock LOCK_ID
```

**Used when:**

- CI crashed
- Lock not released

**Rules:**

- Only one operator
- Change window
- Approval required

## How to explain this to BOA (one-liner)

Use this:

"Our Terraform state is versioned, encrypted, locked, and fully recoverable — ensuring we never lose control of production infrastructure."

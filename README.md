# Terraform Local Document Decryptor

This repository contains a Terraform configuration (split by concern across multiple `.tf` files) that decrypts a base64 payload into a local text file and exposes the decrypted text as a Terraform output.

It is designed for local/offline-style workflows where you already have:
- an AES-GCM ciphertext (base64, without `b64:` prefix),
- a 32-byte AES key (base64),
- a target document name (for example `resume`).

## What This Configuration Does

The configuration (mainly in `main.tf`) performs these steps:
1. Creates `decrypt.py` (AES-GCM decryption script).
2. Creates `requirements.txt` with `cryptography==46.0.7`.
3. Runs a pinned `python:3.12-slim` Docker image via `local-exec`.
4. Decrypts ciphertext into `${document_type}.txt`.
5. Reads that file with `data.local_file`.
6. Exposes plaintext through output `document`.

Terraform re-runs decryption when relevant inputs change:
- decryption script content,
- requirements content,
- ciphertext hash,
- key hash,
- existing target file content hash (or missing-file marker).

## File Layout

- Previous monolithic file `application.tf` has been replaced by `main.tf` and supporting files.
- `terraform.tf`: Terraform version and provider requirements
- `backend.tf`: Backend configuration
- `variables.tf`: Input variable declarations and validation rules
- `main.tf`: Resources, local execution, and data source
- `outputs.tf`: Output declarations

## Requirements

- Terraform `~> 1.14`
- Docker (required by `local-exec`)
- Bash (`/bin/bash`)
- Local filesystem write permissions in module directory

## Inputs

| Name | Type | Default | Sensitive | Description |
|---|---|---|---|---|
| `ciphertext_b64_no_prefix` | `string` | `""` | `true` | Base64 ciphertext without `b64:` prefix. Must be valid base64. |
| `document_type` | `string` | `"resume"` | `false` | Output filename stem (allowed: letters, numbers, `_`, `-`). |
| `key_b64` | `string` | `""` | `true` | Base64-encoded 32-byte key (44 chars, including padding). |

### Ciphertext format expectation

The decryption script expects decoded ciphertext bytes in this layout:
- first 12 bytes: AES-GCM nonce (IV),
- remaining bytes: encrypted payload + GCM tag.

In other words, this configuration expects a payload shaped like:
`base64( nonce || ciphertext_and_tag )`

## Output

| Name | Description |
|---|---|
| `document` | Content of `${document_type}.txt` after decryption. |

## Quick Start

1. Initialize:

```bash
terraform init
```

2. Provide values (recommended via environment variables):

```bash
export TF_VAR_ciphertext_b64_no_prefix='<BASE64_CIPHERTEXT_NO_PREFIX>'
export TF_VAR_key_b64='<BASE64_32_BYTE_KEY>'
export TF_VAR_document_type='resume'
```

3. Plan and apply:

```bash
terraform plan -out tfplan
terraform apply tfplan
```

4. Read output:

```bash
terraform output -raw document
```

The decrypted file is also written to:
- `./resume.txt` (or `./${document_type}.txt`)

## Example `terraform.tfvars` (alternative input method)

Avoid committing this file if it contains real secrets.

```hcl
ciphertext_b64_no_prefix = "BASE64_PAYLOAD"
key_b64                  = "BASE64_32_BYTE_KEY"
document_type            = "resume"
```

## Security Notes

- `sensitive = true` only masks values in CLI output. Sensitive values can still end up in Terraform state.
- This config uses the `local` backend. State is stored locally unless you change backend configuration.
- Plaintext is written to `${document_type}.txt` on disk.
- Output `document` is not marked `sensitive` in current code, so plaintext may be shown in CLI output.
- Docker image is pinned by digest for reproducibility.

If this is used with real secrets, consider:
- remote encrypted backend with access controls,
- marking output as sensitive,
- secure cleanup for plaintext files and state artifacts.

## Troubleshooting

- `docker: command not found`
  - Install Docker and ensure daemon is running.
- `test -s <file> failed`
  - Decryption produced empty file; verify ciphertext/key pair.
- `key_b64 must be a valid base64-encoded 32-byte key`
  - Ensure decoded key is exactly 32 bytes (base64 length 44).
- `ciphertext_b64_no_prefix must be valid base64`
  - Remove non-base64 characters and strip any `b64:` prefix.

## Cleanup

To remove created artifacts from state-managed resources:

```bash
terraform destroy
```

Additional local files may remain depending on execution context (for example generated text files). Remove them manually if needed.

resource "local_file" "decrypt_py" {
  filename             = "${path.module}/decrypt.py"
  directory_permission = "0755"
  file_permission      = "0700"

  content = <<-EOT
    import base64
    import sys
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM

    if len(sys.argv) < 3:
        print(f'usage: {sys.argv[0]} <ciphertext_b64_no_prefix> <key_b64>')
        sys.exit(1)

    ct = base64.b64decode(sys.argv[1])
    key_b64 = sys.argv[2]
    key = base64.b64decode(key_b64)

    iv = ct[:12]  # 96-bit nonce
    actual_ct = ct[12:]

    plaintext = AESGCM(key).decrypt(iv, actual_ct, None).decode('utf-8')
    sys.stdout.write(plaintext.rstrip("\n"))
  EOT
}

resource "local_file" "requirements_txt" {
  filename = "${path.module}/requirements.txt"

  content = <<-EOT
    cryptography==46.0.7
  EOT
}

resource "terraform_data" "document" {
  triggers_replace = [
    local_file.decrypt_py.content_sha256,
    local_file.requirements_txt.content_sha256,
    sha256(var.ciphertext_b64_no_prefix),
    sha256(var.key_b64),
    fileexists("${path.module}/${var.document_type}.txt") ? filemd5("${path.module}/${var.document_type}.txt") : "${var.document_type} text file does not exist.",
  ]

  provisioner "local-exec" {
    working_dir = path.module
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-SCRIPT
      set -euo pipefail

      docker run --rm \
        -v "$PWD":/work \
        -w /work \
        python:3.12-slim@sha256:804ddf3251a60bbf9c92e73b7566c40428d54d0e79d3428194edf40da6521286 \
        bash -lc "\
          python -m venv .venv \
          && source .venv/bin/activate \
          && PIP_DISABLE_PIP_VERSION_CHECK=1 pip install \
              -q \
              -r requirements.txt \
            >/dev/null \
            2>&1 \
          && python decrypt.py '${var.ciphertext_b64_no_prefix}' '${var.key_b64}'\
        " \
        > ${var.document_type}.txt

      test -s ${var.document_type}.txt
    SCRIPT
  }

  depends_on = [
    local_file.decrypt_py,
    local_file.requirements_txt,
  ]
}

data "local_file" "document" {
  filename = "${path.module}/${var.document_type}.txt"

  depends_on = [terraform_data.document]
}

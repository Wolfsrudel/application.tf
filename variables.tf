variable "ciphertext_b64_no_prefix" {
  description = "Base64-encoded ciphertext without the 'b64:' prefix."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9+/]+={0,2}$", var.ciphertext_b64_no_prefix))
    error_message = "ciphertext_b64_no_prefix must be valid base64."
  }
}

variable "document_type" {
  description = "Type of document to decrypt (e.g., 'resume')."
  type        = string
  default     = "resume"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.document_type))
    error_message = "document_type must be a non-empty string containing only letters, numbers, underscores, or hyphens."
  }
}

variable "key_b64" {
  description = "Base64-encoded key for decryption."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9+/]+={0,2}$", var.key_b64)) && length(var.key_b64) == 44
    error_message = "key_b64 must be a valid base64-encoded 32-byte key."
  }
}

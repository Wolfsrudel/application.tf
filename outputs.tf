output "document" {
  description = "Content of the document text file."
  value       = data.local_file.document.content
}

output "tfstate_bucket" {
  description = "Bucket del estado remoto. Copiarlo en envs/dev/backend.hcl."
  value       = aws_s3_bucket.tfstate.bucket
}

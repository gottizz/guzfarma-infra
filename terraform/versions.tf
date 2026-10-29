# Laboratorio 09 · Despliegue con GitHub Actions + OIDC
# Stack mínimo de Guzfarma: Cognito, API Gateway HTTP, Lambda y CloudWatch Logs.

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # Los datos del bucket van en backend.hcl (no se sube) o en -backend-config.
  # La clave del estado es fija: lab09/dev/terraform.tfstate
  backend "s3" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "lab09"
      Application = "guzfarma"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

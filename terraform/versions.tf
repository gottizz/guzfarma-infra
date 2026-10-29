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

  # El bucket va en backend.hcl (no se sube) o en -backend-config.
  # La región queda fija aquí: si se toma la región por defecto del perfil
  # (us-east-1), S3 responde 301 / AccessDenied al leer el estado.
  backend "s3" {
    key          = "lab09/dev/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
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

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

# CloudFront, su WAF y su certificado ACM siempre van en us-east-1.
# La región principal ya es us-east-1, pero el alias deja explícito ese requisito.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.common_tags
  }
}

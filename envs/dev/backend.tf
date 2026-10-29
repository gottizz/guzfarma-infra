# Estado remoto en S3 (creado por bootstrap/). Los datos del bucket van en
# backend.hcl, que NO se sube al repo. Ver backend.hcl.example.
#
#   terraform init -backend-config=backend.hcl
#
# Para trabajar sin AWS (solo validar sintaxis):
#   terraform init -backend=false
terraform {
  backend "s3" {}
}

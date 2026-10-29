# Flujo de trabajo con Git

## Primera vez

```bash
git clone https://github.com/<usuario>/guzfarma-infra.git
cd guzfarma-infra
git checkout -b feat/<tu-modulo>      # p. ej. feat/security
```

## Día a día

```bash
git pull origin main                  # traer lo último antes de empezar
# ...editar modules/<tu-modulo>/main.tf y outputs.tf...
terraform fmt -recursive
cd envs/dev && terraform init -backend=false && terraform validate && cd ../..
git add modules/<tu-modulo>
git commit -m "feat(security): security groups de ALB, app y db"
git push origin feat/<tu-modulo>
```

Luego abrir un **Pull Request** hacia `main` en GitHub. El Integrante 1 lo revisa y lo fusiona.

## Reglas

- Nadie hace push directo a `main`.
- Cada quien toca solo los archivos de su módulo. Si necesitas un output nuevo de otro
  módulo, pídeselo al responsable o coméntalo en el PR.
- Nunca subir `terraform.tfvars`, `backend.hcl`, `*.tfstate` ni credenciales de AWS
  (el `.gitignore` ya los excluye).
- Mensajes de commit: `feat(modulo): ...`, `fix(modulo): ...`, `docs: ...`.

## Probar en AWS

Solo una persona aplica a la vez (el estado tiene bloqueo, pero igual coordinen por el grupo):

```bash
cd envs/dev
cp backend.hcl.example backend.hcl          # completar el bucket
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
terraform destroy                           # al terminar
```

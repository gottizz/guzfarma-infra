# Módulo `database`

**Responsable:** Integrante 3

**Qué crea:** RDS Oracle SE2 (Multi-AZ opcional) con contraseña gestionada por RDS en Secrets Manager, y bucket S3 para respaldos RMAN.

**Depende de:** network, security

## Recursos

- `aws_db_subnet_group`, `aws_db_parameter_group` (`oracle-se2-19`) y `aws_db_option_group` con la opción `S3_INTEGRATION`.
- `aws_db_instance` con licencia incluida, cifrado KMS, `publicly_accessible = false`, Performance Insights y contraseña administrada por RDS (`manage_master_user_password`).
- Rol IAM `rds_s3` asociado a la instancia (`aws_db_instance_role_association`) para que RDS escriba y lea en el bucket de respaldos.
- Bucket S3 `rman` con versionado, cifrado KMS, bloqueo de acceso público y ciclo de vida (`rman_retention_days`).

## Outputs

`db_address`, `db_port`, `db_name`, `db_instance_id`, `db_secret_arn`, `rman_bucket_name`.

## Cómo se lanza RMAN

Terraform solo crea la infraestructura. Los respaldos RMAN se ejecutan **desde dentro de la base** con los paquetes `rdsadmin.rdsadmin_rman_util` y `rdsadmin.rdsadmin_s3_tasks` (RDS no da acceso al SO, por eso no se usa el binario `rman`).

1. Obtén la contraseña del usuario maestro (`db_username`, por defecto `guzadmin`) desde Secrets Manager con el ARN de `db_secret_arn`.
2. Conéctate a la base con SQL*Plus o SQL Developer desde un host dentro de la VPC (la base no es pública), usando el endpoint `db_address` y el puerto `db_port`.
3. Lanza un respaldo completo de la base hacia el directorio `DATA_PUMP_DIR`:

```sql
BEGIN
  rdsadmin.rdsadmin_rman_util.backup_database_full(
    p_owner               => 'SYS',
    p_directory_name      => 'DATA_PUMP_DIR',
    p_compress            => TRUE,
    p_parallel            => 4,
    p_section_size_mb     => 10,
    p_rman_to_dbms_output => FALSE);
END;
/
```

4. Sube los archivos generados al bucket `rman_bucket_name` (la opción `S3_INTEGRATION` y el rol `rds_s3` lo permiten):

```sql
SELECT rdsadmin.rdsadmin_s3_tasks.upload_to_s3(
         p_bucket_name    => '<rman_bucket_name>',
         p_prefix         => '',
         p_s3_prefix      => 'rman/',
         p_directory_name => 'DATA_PUMP_DIR') AS task_id
FROM dual;
```

5. Revisa el avance en el log de la tarea:

```sql
SELECT text FROM TABLE(rdsadmin.rds_file_util.read_text_file('BDUMP', 'dbtask-<task_id>.log'));
```

Los objetos del bucket expiran a los `rman_retention_days` días (RNF-17: 3 meses). Además, RDS conserva backups automáticos `backup_retention_days` días con recuperación a un punto en el tiempo.

## Costos

Oracle Multi-AZ es lo más caro del proyecto. Aplica, prueba, saca capturas y ejecuta `terraform destroy`.

## Antes de abrir el Pull Request

```bash
terraform fmt -recursive
cd envs/dev
terraform init -backend=false
terraform validate
```

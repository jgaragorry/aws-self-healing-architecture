terraform {
  backend "s3" {
    # Reemplaza con el output del script 00_init_backend.sh
    bucket = "ws-ha-ansible-state-TU_ACCOUNT_ID" 
    key    = "terraform/state/terraform.tfstate"
    region = "us-east-1"
    
    # S3 Native Locking (Terraform v1.10+)
    # Ya no necesitamos dynamodb_table. 
    # S3 usa consistencia fuerte y escrituras condicionales.
    encrypt        = true
    
    # Opcional: chequea si tu versión específica requiere 'use_lockfile = true'
    # use_lockfile = true 
  }
}

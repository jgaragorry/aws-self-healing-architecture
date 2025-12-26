#!/bin/bash

# Nombre del Proyecto
PROJECT_NAME="WS-HA-AutoScaling-Ansible"

echo "🚀 Iniciando configuración del proyecto: $PROJECT_NAME"

# Crear directorios principales
mkdir -p .github/workflows
mkdir -p ansible/roles/webserver/{tasks,templates,vars}
mkdir -p scripts
mkdir -p terraform/modules
mkdir -p docs

# Crear archivos de documentación raíz
touch README.md
touch AUTHORS.md
touch CHANGELOG.md

# Crear archivos de GitHub Actions
touch .github/workflows/deploy.yml
touch .github/workflows/destroy.yml

# Crear archivos de Scripts de Backend y Utilidades
touch scripts/00_init_backend.sh
touch scripts/99_destroy_backend.sh
touch scripts/bootstrap_oidc.sh

# Crear archivos de Ansible
touch ansible/playbook.yml
touch ansible/ansible.cfg
touch ansible/roles/webserver/tasks/main.yml
touch ansible/roles/webserver/vars/main.yml

# Crear archivos de Terraform
touch terraform/main.tf
touch terraform/variables.tf
touch terraform/outputs.tf
touch terraform/providers.tf
touch terraform/backend.tf
touch terraform/user_data.sh

# Crear .gitignore optimizado para Terraform, Python y Ansible
cat <<EOF > .gitignore
# Terraform
.terraform/
*.tfstate
*.tfstate.backup
*.tfvars
.terraform.lock.hcl

# Ansible
*.retry

# Python
__pycache__/
*.pyc

# IDEs
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Secrets (Seguridad)
secrets.tfvars
EOF

# Dar permisos de ejecución a los scripts futuros
chmod +x scripts/*.sh

echo "✅ Estructura creada exitosamente."
echo "📂 Ingresa al directorio con: cd ."

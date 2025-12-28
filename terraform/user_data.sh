#!/bin/bash
set -e

# 1. Logs de depuración (Para que sepamos qué pasa si falla)
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "🚀 Iniciando User Data..."

# 2. Actualizar sistema e instalar dependencias
echo "📦 Instalando dependencias..."
yum update -y
amazon-linux-extras install epel -y
yum install -y ansible git htop

# 3. Clonar el repositorio
echo "QC Clonando repositorio..."
mkdir -p /opt/ws-ansible
# NOTA: Usamos tu repo público
git clone  https://github.com/jgaragorry/aws-self-healing-architecture.git /opt/ws-ansible

# 4. Ejecutar Ansible Playbook
echo "🎭 Ejecutando Ansible..."
cd /opt/ws-ansible/ansible
ansible-playbook playbook.yml --connection=local

# 5. Señal de vida
echo "✅ Provisioning completado exitosamente en $(date)"

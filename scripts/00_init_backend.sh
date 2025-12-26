#!/bin/bash
set -e

# --- CONFIGURACIÓN ---
PROJECT_NAME="ws-ha-ansible"
REGION="us-east-1"
# Obtenemos el ID de la cuenta dinámicamente
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="${PROJECT_NAME}-state-${ACCOUNT_ID}"

echo "🏗️  Iniciando configuración del Backend Remoto (S3 Native Locking)..."
echo "---------------------------------------------"
echo "🌍 Región: $REGION"
echo "📦 Bucket S3: $BUCKET_NAME"
echo "✅ Locking: Nativo S3 (Sin DynamoDB)"
echo "---------------------------------------------"

# 1. Crear Bucket S3 (Idempotente: verifica si existe antes)
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "✅ El Bucket S3 '$BUCKET_NAME' ya existe. Omitiendo creación."
else
    echo "⏳ Creando Bucket S3..."
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
    
    # 2. Bloquear acceso público (Best Practice Security)
    echo "🔒 Bloqueando acceso público al bucket..."
    aws s3api put-public-access-block \
        --bucket "$BUCKET_NAME" \
        --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    
    # 3. Habilitar Versionado (Best Practice Recovery)
    echo "🔄 Habilitando versionado (Vital para rollback)..."
    aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled

    # 4. Etiquetado para FinOps (OBLIGATORIO)
    echo "🏷️  Aplicando etiquetas de FinOps..."
    aws s3api put-bucket-tagging --bucket "$BUCKET_NAME" --tagging 'TagSet=[{Key=Project,Value=WS-HA-AutoScaling-Ansible},{Key=Environment,Value=Management},{Key=Owner,Value=DevOps-Team},{Key=ManagedBy,Value=Script}]'
    
    echo "✅ Bucket creado y configurado exitosamente."
fi

echo "---------------------------------------------"
echo "🎉 Backend configurado."
echo "⚠️  IMPORTANTE: Copia el siguiente nombre y pégalo en 'terraform/backend.tf':"
echo ""
echo "bucket = \"$BUCKET_NAME\""
echo ""
echo "---------------------------------------------"

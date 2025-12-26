#!/bin/bash
# ⚠️ ADVERTENCIA: ESTE SCRIPT DESTRUYE EL ESTADO. SOLO PARA USO EN LABORATORIOS.

PROJECT_NAME="ws-ha-ansible"
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="${PROJECT_NAME}-state-${ACCOUNT_ID}"

echo "💣 INICIANDO DESTRUCCIÓN DEL BACKEND (Solo S3)"
echo "⚠️  ADVERTENCIA: Esto borrará el historial de Terraform. ¿Estás seguro? (y/n)"
read confirmation

if [ "$confirmation" != "y" ]; then
    echo "❌ Cancelado."
    exit 1
fi

# Borrar contenido del bucket
echo "🗑️  Vaciando bucket S3..."
aws s3 rm "s3://${BUCKET_NAME}" --recursive

# Borrar bucket
echo "🔥 Borrando bucket S3..."
aws s3api delete-bucket --bucket "$BUCKET_NAME" --region "$REGION" || echo "⚠️ El bucket no existía o ya fue borrado."

echo "💀 Backend destruido."

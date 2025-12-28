#!/bin/bash
set -e

# --- CONFIGURACIÓN ---
PROJECT_TAG="WS-HA-AutoScaling-Ansible"
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="ws-ha-ansible-state-${ACCOUNT_ID}"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔍 INICIANDO AUDITORÍA FINOPS (Modo Nativo AWS CLI)${NC}"
echo "----------------------------------------------------------------"
echo "Target Project Tag: $PROJECT_TAG"
echo "Target Region:      $REGION"
echo "----------------------------------------------------------------"

# FUNCIÓN DE CHECK (Usa query nativo de AWS CLI)
check_resource() {
    SERVICE=$1
    COMMAND=$2
    
    echo -n "Auditando $SERVICE... "
    RESULT=$(eval "$COMMAND")
    
    if [ -z "$RESULT" ] || [ "$RESULT" == "None" ]; then
        echo -e "${GREEN}LIMPIO (0 recursos)${NC}"
    else
        echo -e "${RED}⚠️  ALERTA: RECURSOS ENCONTRADOS${NC}"
        echo "$RESULT"
    fi
}

# 1. EC2 INSTANCES
# Usamos --query nativo para filtrar ID y Estado
check_resource "EC2 Instances" \
    "aws ec2 describe-instances --filters \"Name=tag:Project,Values=$PROJECT_TAG\" --region $REGION --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name}' --output text"

# 2. NAT GATEWAYS
check_resource "NAT Gateways" \
    "aws ec2 describe-nat-gateways --filter \"Name=tag:Project,Values=$PROJECT_TAG\" --region $REGION --query 'NatGateways[].{ID:NatGatewayId,State:State}' --output text"

# 3. LOAD BALANCERS (ALB)
ALB_ARN=$(aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[?contains(LoadBalancerName, 'ws-ha-alb')].LoadBalancerArn" --output text 2>/dev/null)
if [ -z "$ALB_ARN" ]; then
     echo -e "Auditando Load Balancers... ${GREEN}LIMPIO${NC}"
else
     echo -e "Auditando Load Balancers... ${RED}⚠️  ALERTA: $ALB_ARN encontrado${NC}"
fi

# 4. RDS INSTANCES
check_resource "RDS Instances" \
    "aws rds describe-db-instances --region $REGION --query \"DBInstances[?contains(DBInstanceIdentifier, 'terraform')].DBInstanceIdentifier\" --output text"

# 5. ELASTIC IPs
check_resource "Elastic IPs" \
    "aws ec2 describe-addresses --filters \"Name=tag:Project,Values=$PROJECT_TAG\" --region $REGION --query 'Addresses[].PublicIp' --output text"

# 6. EBS VOLUMES
check_resource "EBS Volumes" \
    "aws ec2 describe-volumes --filters \"Name=tag:Project,Values=$PROJECT_TAG\" --region $REGION --query 'Volumes[].{ID:VolumeId,State:State}' --output text"

echo "----------------------------------------------------------------"
echo -e "${YELLOW}🗑️  VERIFICACIÓN DEL BACKEND S3 (LIMPIEZA PROFUNDA)${NC}"

# Verificar si el bucket existe
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo -e "${RED}❌ EL BUCKET '$BUCKET_NAME' AÚN EXISTE.${NC}"
    echo "Procediendo a limpieza de versiones (Modo Texto)..."
    
    # 1. Borrar Versiones de Objetos (Usando output text para loop simple)
    # Formato output: KEY  VERSION_ID
    aws s3api list-object-versions --bucket "$BUCKET_NAME" --region "$REGION" \
        --query 'Versions[].{Key:Key,VersionId:VersionId}' --output text | \
    while read -r KEY VERSION_ID; do
        if [ "$KEY" != "None" ] && [ -n "$KEY" ]; then
            echo "   -> Borrando versión: $KEY"
            aws s3api delete-object --bucket "$BUCKET_NAME" --key "$KEY" --version-id "$VERSION_ID" --region "$REGION" >/dev/null
        fi
    done

    # 2. Borrar Delete Markers
    echo "⏳ Borrando marcadores de borrado..."
    aws s3api list-object-versions --bucket "$BUCKET_NAME" --region "$REGION" \
        --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output text | \
    while read -r KEY VERSION_ID; do
        if [ "$KEY" != "None" ] && [ -n "$KEY" ]; then
            echo "   -> Borrando marker: $KEY"
            aws s3api delete-object --bucket "$BUCKET_NAME" --key "$KEY" --version-id "$VERSION_ID" --region "$REGION" >/dev/null
        fi
    done

    # 3. Borrar Bucket
    echo "🔥 Intentando borrar el bucket vacío..."
    if aws s3api delete-bucket --bucket "$BUCKET_NAME" --region "$REGION"; then
        echo -e "${GREEN}✅ BUCKET ELIMINADO EXITOSAMENTE.${NC}"
    else
        echo -e "${RED}❌ FALLÓ EL BORRADO DEL BUCKET.${NC}"
    fi

else
    echo -e "${GREEN}✅ EL BUCKET S3 YA NO EXISTE.${NC}"
fi

echo "----------------------------------------------------------------"
echo "🏁 Auditoría finalizada."

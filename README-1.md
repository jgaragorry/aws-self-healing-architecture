# 🚀 WS-HA-AutoScaling-Ansible: Enterprise High Availability & Self-Healing Architecture

![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=for-the-badge&logo=ansible&logoColor=white)
![Bash](https://img.shields.io/badge/Shell_Script-121011?style=for-the-badge&logo=gnu-bash&logoColor=white)
![FinOps](https://img.shields.io/badge/FinOps-Cost_Optimization-success?style=for-the-badge)

---

## 📋 Objetivo del Workshop
Este proyecto despliega una **Arquitectura de Referencia Empresarial (3-Tier Architecture)** en AWS. El objetivo es demostrar cómo desplegar una aplicación web altamente disponible, escalable y autocurativa (Self-Healing) utilizando **Infraestructura como Código (IaC)** y **Gestión de Configuración**.

**¿Por qué este workshop?** Simula un escenario real donde una empresa necesita:
1.  Soportar picos de tráfico sin intervención humana (**Auto Scaling**).
2.  Garantizar que si un servidor falla, sea reemplazado automáticamente (**High Availability**).
3.  Configurar servidores de forma dinámica y no manual (**Ansible Pull Pattern**).
4.  Mantener la base de datos en una red privada aislada (**Security**).

---

## 🏗️ Diagrama de Arquitectura

```mermaid
graph TD
    User((🌐 Internet User)) --> ALB[Application Load Balancer]
    
    subgraph VPC [AWS Cloud (us-east-1)]
        subgraph Public_Subnets [Public Zone]
            ALB
            NAT[NAT Gateway]
        end
        
        subgraph Private_Subnets [Private Zone (Secure)]
            ASG[Auto Scaling Group]
            EC2_1[EC2 Instance A]
            EC2_2[EC2 Instance B]
            RDS[(RDS MySQL Database)]
        end
    end
    
    ALB -->|Traffic Dist| ASG
    ASG --> EC2_1
    ASG --> EC2_2
    EC2_1 & EC2_2 -->|Pull Config| GitHub[GitHub Repo (Ansible)]
    EC2_1 & EC2_2 -->|SQL| RDS
    EC2_1 & EC2_2 -->|Outbound Updates| NAT
```

---

## 💡 Ventajas y Valor Agregado
Este laboratorio mejora los despliegues tradicionales al aportar:

1.  **Inmutabilidad & Config Management:** Usamos el patrón **"Ansible Pull"**. Las instancias nacen "limpias" y se autoconfiguran descargando este repositorio.
2.  **Resiliencia (Chaos Engineering):** Puedes terminar (matar) una instancia manualmente y el servicio **NO** se detiene. El sistema se repara solo.
3.  **Seguridad (DevSecOps):**
    * Backend de Terraform encriptado en S3.
    * Instancias y Base de Datos en **Subredes Privadas** (Sin acceso directo desde internet).
    * Uso de **Security Groups** con principio de "Least Privilege".
4.  **FinOps & Auditoría:** Scripts personalizados para garantizar que no queden recursos "zombis" generando costos (NAT Gateways, Volúmenes EBS huérfanos, etc.).

---

## 🛠️ Tecnologías Utilizadas

| Tecnología | Propósito |
|------------|-----------|
| **Terraform v1.10+** | Infraestructura como Código (IaC). |
| **AWS Provider v6.x** | Proveedor de nube actualizado a la última versión estable. |
| **Ansible** | Gestión de configuración (Instalación de Nginx, HTML dinámico). |
| **AWS EC2 & ASG** | Cómputo elástico y auto-escalable. |
| **AWS ALB** | Balanceo de carga de Aplicación (L7). |
| **AWS S3** | Backend remoto para el estado de Terraform (con Native Locking). |
| **Bash Scripting** | Automatización de tareas de auditoría y limpieza (`audit_and_nuke`). |

---

## 💰 Estimación de Costos (FinOps)
Este laboratorio utiliza recursos que **NO** son siempre gratuitos.
* **NAT Gateway:** ~$0.045 USD/hora (El componente más caro).
* **ALB:** ~$0.0225 USD/hora.
* **EC2 (t3.micro):** Free Tier eligible (o ~$0.0104 USD/hora).
* **RDS (db.t3.micro):** Free Tier eligible.

**Costo estimado por ejecución del lab (2 horas):** < $0.50 USD.
*Nota: Es vital ejecutar el script de destrucción al finalizar.*

---

## 🚀 Guía de Despliegue (Paso a Paso)

### 1. Prerrequisitos
* AWS CLI configurado con credenciales de `AdministratorAccess`.
* Terraform instalado.
* Git instalado.
* **IMPORTANTE:** Este repositorio debe ser **PÚBLICO** en GitHub para que las instancias puedan descargar los Playbooks de Ansible.

### 2. Inicialización del Backend (Idempotente)
Configuramos el bucket S3 para guardar el estado de Terraform de forma segura y remota.
```bash
chmod +x scripts/*.sh
./scripts/00_init_backend.sh
# Copia el nombre del bucket que te arroje el script y actualiza terraform/backend.tf
```

### 3. Despliegue de Infraestructura
```bash
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
```
*Tiempo estimado: 5-7 minutos.*

### 4. Validación (Smoke Test)
1.  Obtén la URL del Load Balancer desde el `output` de Terraform.
2.  Abre la URL en tu navegador. Deberías ver la página de bienvenida con el ID de la instancia.
3.  **Prueba de Caos:** Ve a la consola de AWS, termina una instancia `ws-ha-instance`. Refresca la web. ¡Sigue funcionando!

---

## 🛡️ Mejores Prácticas Aplicadas

### Arquitectura & DevSecOps
* **Separación del Backend:** El estado (`terraform.tfstate`) no vive en tu PC, vive en S3 encriptado, permitiendo trabajo en equipo.
* **S3 Native Locking:** Usamos las características modernas de S3 para evitar corrupción del estado sin pagar por DynamoDB.
* **Idempotencia:** Los scripts bash (`00_init`, `audit_and_nuke`) verifican el estado antes de actuar, evitando errores por duplicidad.
* **Nomenclatura:** Uso consistente de prefijos `ws-ha-*` y tags para fácil identificación.

### FinOps (Control de Costos)
* **Etiquetado (Tagging):** Todos los recursos se crean con tags `Project`, `Owner` y `Environment`.
* **Auditoría Forense:** Incluimos el script `audit_and_nuke.sh` que escanea la cuenta buscando recursos olvidados (NAT Gateways, EIPs, Volúmenes) que Terraform podría haber pasado por alto si hubo errores manuales.

---

## 🧹 Destrucción y Auditoría (IMPORTANTE)
Para evitar cobros sorpresa, sigue este orden estricto:

1.  **Destruir Infraestructura:**
    ```bash
    cd terraform
    terraform destroy -auto-approve
    ```

2.  **Auditoría y Limpieza Nuclear:**
    Este script busca recursos remanentes y elimina el bucket S3 (incluso si tiene versiones).
    ```bash
    cd ..
    ./scripts/audit_and_nuke.sh
    ```
    *Si el script devuelve "LIMPIO" en verde en todas las secciones, tu facturación está a salvo.*

---

## 📞 Contacto

¿Te interesa implementar esta arquitectura en tu empresa o aprender más sobre DevOps y Cloud?

* **Instructor:** Jorge Garagorry
* **Rol:** Cloud Engineer | DevOps & SRE | Instructor Linux/AWS/Azure
* **💼 LinkedIn:** [José Julio Garagorry Arias](https://www.linkedin.com/in/jgaragorry/)
* **🚀 GitHub:** [@jgaragorry](https://github.com/jgaragorry)
* **📱 TikTok (Tips Diarios):** [@softtraincorp](https://www.tiktok.com/@softtraincorp)
* **📧 Negocios:** +56 956744034

---
*Developed with ❤️ and Automation by SoftTrain Corp.*

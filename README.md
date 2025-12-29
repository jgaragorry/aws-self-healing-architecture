# 🚀 HA-AutoScaling-Ansible: Enterprise High Availability on AWS

![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=for-the-badge&logo=ansible&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)
![Status](https://img.shields.io/badge/Status-Active-success?style=for-the-badge)

## 📋 Objetivo del Workshop
Este proyecto implementa una arquitectura de referencia **Enterprise Grade** en AWS. El objetivo es demostrar cómo desplegar una aplicación web altamente disponible, escalable y autocurativa (Self-Healing) utilizando **Infraestructura como Código (IaC)** y **Gestión de Configuración**.

**¿Por qué este workshop?**
Simula un escenario real donde una empresa necesita:
1.  Soportar picos de tráfico (Black Friday, Cyber Monday) sin intervención humana (**Auto Scaling**).
2.  Garantizar que si un servidor falla, sea reemplazado automáticamente (**High Availability**).
3.  Configurar servidores de forma dinámica y no manual (**Ansible**).
4.  Mantener la base de datos en una red privada aislada (**Security**).

---

## 🏗️ Arquitectura Técnica

La solución despliega los siguientes recursos en la región `us-east-1`:

* **Red (VPC):** * 2 Subredes Públicas (Para Load Balancer y NAT Gateway).
    * 2 Subredes Privadas (Para Aplicación y Base de Datos).
    * **NAT Gateway:** Para permitir salida a internet segura desde las instancias privadas.
* **Cómputo:**
    * **Auto Scaling Group (ASG):** Gestiona instancias EC2 (t3.micro). Escalado basado en uso de CPU.
    * **Launch Template:** Define la configuración de las instancias.
* **Configuración (Ansible):**
    * Se ejecuta vía `User Data` al inicio de cada instancia para instalar Nginx/Apache y configurar la aplicación.
* **Base de Datos:**
    * **RDS MySQL:** Instancia gestionada en subred privada.
* **Balanceo:**
    * **Application Load Balancer (ALB):** Expone la aplicación a internet y distribuye tráfico.

---

## 🛡️ Mejores Prácticas Implementadas (DevSecOps & FinOps)

### Security & DevSecOps
* **OIDC (OpenID Connect):** Autenticación sin llaves permanentes entre GitHub y AWS.
* **Least Privilege:** Security Groups estrictos. La App solo acepta tráfico del ALB. La BD solo acepta tráfico de la App.
* **Private Subnets:** Los servidores de aplicación y base de datos NO tienen IP pública.
* **State Locking:** Terraform State almacenado en S3 con bloqueo en DynamoDB para evitar corrupción en equipos distribuidos.

### FinOps (Control de Costos)
* **Spot Instances (Opcional):** Configuración preparada para usar instancias Spot y ahorrar hasta un 90%.
* **Auto-Destroy:** Pipeline de GitHub Actions configurado para destrucción manual fácil.
* **Estimación de Costos:**
    * NAT Gateway: ~$0.045/hora (Componente más caro).
    * ALB: ~$0.0225/hora.
    * EC2/RDS: Elegibles para Free Tier (si aplica).
    * **Costo total estimado:** ~$0.15 USD / hora de laboratorio.

---

## 🚀 Automatización CI/CD (GitHub Actions)

Este repositorio cuenta con flujos de trabajo automatizados (`.github/workflows/`):

1.  **Deploy Infrastructure:**
    * Disparador: `workflow_dispatch` (Botón manual) o Push a `main`.
    * Acciones: `terraform init`, `plan`, `apply`.
    
2.  **Destroy Infrastructure:**
    * Disparador: `workflow_dispatch` (Botón manual).
    * Acciones: `terraform destroy`.

---

## 🛠️ Requisitos Previos

* Cuenta AWS activa.
* Terraform instalado (`v1.0+`).
* AWS CLI configurado.
* Git instalado.

---

## 📞 Contacto y Recursos

¿Dudas sobre la implementación? ¿Te interesa llevar esto a tu empresa?

* **Instructor:** Jorge Garagorry
* **Rol:** Cloud Engineer | DevOps & SRE | Instructor Linux/AWS/Azure
* **💼 LinkedIn:** [José Julio Garagorry Arias](https://www.linkedin.com/in/jgaragorry/)
* **🚀 GitHub:** [@jgaragorry](https://github.com/jgaragorry)
* **📱 TikTok (Tips Diarios):** [@softtraincorp](https://www.tiktok.com/@softtraincorp)
* **👥 Comunidad WhatsApp (DevOps Elite):** [Únete aquí](https://chat.whatsapp.com/ENuRMnZ38fv1pk0mHlSixa)
* **📧 Negocios:** +56 956744034

---
*Developed with ❤️ by SoftTrain Corp.*

# 📘 GUÍA MAESTRA: Reproducción del Laboratorio WS-HA-AutoScaling-Ansible

**Autor:** Jorge Garagorry  
**Versión:** 1.0 (Enterprise Standard)  
**Objetivo:** Guía paso a paso "A prueba de fallos" para desplegar, auditar y destruir el laboratorio completo.

---

## 🚦 Fase 0: Prerrequisitos Críticos

Antes de tocar una sola línea de código, asegúrate de cumplir con esto. Si falla algo aquí, fallará todo.

1.  **Credenciales de AWS:** Debes tener configurado `aws configure` con un usuario que tenga permisos de Administrador.
2.  **Herramientas Instaladas:** Terraform, AWS CLI, Git y `jq` (para el script de auditoría).
3.  **Repositorio PÚBLICO:** Este repositorio en GitHub debe estar **Público**.
    * *¿Por qué?* Porque usamos el patrón "Ansible Pull". Las instancias EC2 descargarán este repo al nacer. Si es privado, fallarán al intentar clonarlo sin password.

---

## 🏗️ Fase 1: Preparación del Backend (El Cimiento)

Terraform necesita un lugar donde guardar la "foto" de tu infraestructura (el archivo `terraform.tfstate`). No lo guardaremos en tu PC, sino en un Bucket S3 seguro.

### Paso 1.1: Dar permisos de ejecución
Los scripts de automatización vienen "apagados" por seguridad.
```bash
chmod +x scripts/*.sh
```
> **🔍 ¿Qué hace esto?** Le dice a Linux que los archivos `.sh` son programas ejecutables, no solo texto.

### Paso 1.2: Crear el Backend S3
Ejecuta el script de inicialización. Este script es **idempotente** (verifica antes de crear).
```bash
./scripts/00_init_backend.sh
```
> **🔍 ¿Qué hace esto?**
> 1.  Calcula tu ID de cuenta AWS.
> 2.  Crea un nombre único (ej: `ws-ha-ansible-state-123456789`).
> 3.  Crea un Bucket S3 con **Encriptación activada** (seguridad) y **Versionado activado** (backup automático del estado).

### Paso 1.3: Conectar Terraform al Backend (Manual Crítico)
El script anterior te arrojó un nombre de bucket al final (ej: `ws-ha-ansible-state-533267117128`).
1.  Abre el archivo `terraform/backend.tf`.
2.  Busca la línea `bucket = "..."`.
3.  Pega el nombre exacto de tu bucket ahí.
4.  Guarda el archivo.

---

## 🚀 Fase 2: Despliegue de Infraestructura (Terraform)

Aquí es donde ocurre la magia. Vamos a crear redes, servidores, bases de datos y balanceadores.

### Paso 2.1: Inicializar Terraform
```bash
cd terraform
terraform init
```
> **🔍 ¿Qué hace esto?**
> * Descarga el "Driver" de AWS (AWS Provider v6).
> * Se conecta al Bucket S3 que configuraste en el paso anterior para leer el estado.

### Paso 2.2: Planificar (Dry Run)
```bash
terraform plan
```
> **🔍 ¿Qué hace esto?**
> * Compara tu código con la realidad en AWS.
> * Te dice: "Voy a crear 24 recursos". Es tu última oportunidad de revisar antes de gastar dinero.

### Paso 2.3: Aplicar (Creación Real)
```bash
terraform apply -auto-approve
```
> **🔍 ¿Qué hace esto?**
> 1.  **Red:** Crea VPC, Subnets Públicas (Internet) y Privadas (Seguras).
> 2.  **Seguridad:** Crea Security Groups (Firewalls).
> 3.  **Base de Datos:** Crea un RDS MySQL.
> 4.  **Launch Template:** Define cómo son tus servidores. Aquí inyecta el script `user_data.sh`.
>     * *Detalle Clave:* El script `user_data.sh` instala Ansible, clona este repo y ejecuta el playbook localmente.
> 5.  **Auto Scaling:** Lanza 2 instancias EC2 usando la plantilla.
> 6.  **Load Balancer:** Crea el ALB para recibir tráfico de internet.

⏳ **Tiempo de espera:** Aproximadamente 5-7 minutos (El RDS tarda en crearse).

---

## 🧪 Fase 3: Validación y Pruebas

Una vez que Terraform termina, te dará un `output` llamado `alb_dns_name`.

### Paso 3.1: Verificar la Web
Copia esa URL (ej: `ws-ha-alb-xxxx.us-east-1.elb.amazonaws.com`) y pégala en el navegador.
* **Éxito:** Verás una pantalla negra con un cohete 🚀 y el ID de la instancia (ej: `i-0516...`).
* **¿Qué significa?** Que Nginx se instaló, Ansible corrió y el Load Balancer funciona.

### Paso 3.2: Prueba de Caos (Chaos Engineering)
Demostremos que el sistema es "Inmortal".
1.  Ve a la consola de AWS -> EC2.
2.  Identifica una instancia que esté "Running".
3.  **Mátala:** Clic derecho -> Terminate Instance.
4.  Vuelve rápido a tu navegador y refresca la página web.
    * **Resultado:** La web NO se cae. El Load Balancer te redirige a la otra instancia viva.
5.  Espera 2 minutos.
    * **Resultado:** Verás en la consola que el **Auto Scaling Group** creó una nueva instancia automáticamente para reemplazar a la muerta.

---

## 🧹 Fase 4: Destrucción Controlada (FinOps)

Terminó el laboratorio. Ahora debemos destruir todo para que no te cobren el NAT Gateway ($0.045/hora).

### Paso 4.1: Destruir Infraestructura
```bash
# Asegúrate de estar en la carpeta /terraform
terraform destroy -auto-approve
```
> **🔍 ¿Qué hace esto?**
> Borra ordenadamente los recursos en orden inverso a su creación. Primero el ALB, luego las EC2, luego el RDS, y al final la Red.
> *Espera hasta ver: "Destroy complete! Resources: 24 destroyed."*

---

## 🕵️ Fase 5: Auditoría Forense y Limpieza Nuclear

Terraform a veces deja "basura" (discos huérfanos, logs, o el bucket S3 que tiene protección contra borrado). Este script es tu seguro de vida financiero.

### Paso 5.1: Ejecutar Auditoría y Nuke
```bash
cd ..  # Vuelve a la raíz del proyecto
./scripts/audit_and_nuke.sh
```

> **🔍 ¿Qué hace este script avanzado?**
> 1.  **Escanea la cuenta:** Busca EC2s, NAT Gateways, EIPs y Volúmenes EBS que tengan el tag del proyecto.
> 2.  **Reporta:** Si encuentra algo vivo, te avisa en ROJO. Si está limpio, sale en VERDE.
> 3.  **Limpieza S3 (La parte difícil):**
>     * Detecta el bucket del backend.
>     * Como el bucket tiene "Versionado", un borrado normal fallaría.
>     * El script borra **todas las versiones históricas** y los "Delete Markers" uno por uno.
>     * Finalmente, borra el bucket vacío.

### Resultado Esperado
Debes ver un mensaje final que diga:
`✅ EL BUCKET S3 YA NO EXISTE.`
`🏁 Auditoría finalizada.`

---

## 🔄 ¿Cómo repetir el laboratorio mañana?

Si quieres volver a practicar desde cero:
1.  Como borramos el bucket S3 en la Fase 5, debes empezar obligatoriamente desde la **Fase 1 (Paso 1.2)**.
2.  Ejecuta `./scripts/00_init_backend.sh`.
3.  Probablemente te dé el mismo nombre de bucket (porque se basa en tu ID de cuenta), así que quizás no necesites editar `backend.tf` de nuevo, pero **verifica siempre**.
4.  Continúa con la Fase 2 (`terraform init`, `apply`).

---
**¡Felicidades!** Has completado el ciclo de vida completo de una infraestructura Enterprise con prácticas de FinOps y Seguridad.

# 🧠 Architecture Deep Dive: Auto Scaling, Self-Healing & Ansible

Este documento detalla los mecanismos internos del laboratorio `aws-self-healing-architecture`. Explica qué archivos controlan la lógica de negocio, cómo se detectan fallos y cómo ocurre la automatización.

---

## 1. Auto Scaling & Self-Healing (El "Cerebro")

La capacidad de escalar (crecer/decrecer) y curarse (reemplazar servidores muertos) no es magia, es configuración explícita en **Terraform**.

### 📂 ¿Dónde se define?
Todo esto vive en el archivo **`terraform/main.tf`** (o donde hayas definido el recurso `aws_autoscaling_group`).

### ⚙️ Los Parámetros Clave
[cite_start]Según la ejecución de tu plan de Terraform [cite: 8-16], esta es la configuración que activa la inteligencia:

1.  **El recurso:** `aws_autoscaling_group` "main".
2.  **Límites de Capacidad:**
    * [cite_start]`min_size = 2`[cite: 12]: **La Regla de Oro.** Le dice a AWS: "Bajo ninguna circunstancia permitas que haya menos de 2 servidores". Si uno muere y quedan 1, AWS está **obligado** a crear otro para cumplir el contrato.
    * [cite_start]`max_size = 4`[cite: 11]: El techo de gasto. No crezcas infinitamente.
    * [cite_start]`desired_capacity = 2`[cite: 9]: El estado ideal en tiempos de paz.

3.  **El Detonador de la "Auto-Curación" (Self-Healing):**
    * [cite_start]`health_check_type = "ELB"`[cite: 10]: **Esta línea es crítica.**
    * **¿Cómo funciona?**
        * Por defecto, EC2 solo mira si el servidor está "encendido" (System Status Checks).
        * Al cambiarlo a **ELB** (Elastic Load Balancer), el Auto Scaling Group le pregunta al balanceador: *"¿Esta instancia está sirviendo la página web correctamente (Código 200)?"*.
        * Si Nginx se cuelga (pero el servidor sigue encendido), el ELB dice "Falla".
        * El Auto Scaling Group recibe la alerta, **termina la instancia enferma** y crea una nueva inmediatamente.

---

## 2. Ansible & El Patrón "Pull" (La Automatización)

Aquí explicamos cómo logramos que una instancia nueva se configure sola sin que tú entres por SSH.

### 📂 ¿Dónde se define?
* [cite_start]**El Detonador:** `terraform/user_data.sh` (Inyectado en el `aws_launch_template` [cite: 50]).
* **La Lógica:** `ansible/playbook.yml` (Dentro del repositorio).

### 🔄 El Flujo de Ejecución (Paso a Paso)

Cuando el Auto Scaling Group crea una nueva instancia (por ejemplo, para reemplazar a una muerta), ocurre esta secuencia exacta:

1.  **Boot (Arranque):** La instancia EC2 nace con Amazon Linux 2 base (vacía).
2.  **User Data (El Primer Aliento):** AWS ejecuta automáticamente el script `terraform/user_data.sh` como `root`.
3.  **Instalación de Herramientas:**
    * El script ejecuta `yum install -y ansible git`. Ahora el servidor tiene cerebro.
4.  **Descarga del Código (Pull):**
    * El script ejecuta: `git clone https://github.com/jgaragorry/aws-self-healing-architecture.git`.
    * **¿Por qué funciona?** Porque el repo es Público y HTTPS. No necesita credenciales.
5.  **Auto-Configuración (Ansible Local):**
    * El script ejecuta: `ansible-playbook playbook.yml --connection=local`.
    * **¿Qué hace esto?** Le dice a Ansible: *"No busques servidores remotos. Tú eres el objetivo. configúrate a ti mismo"*.
    * Ansible lee el `playbook.yml`, instala Nginx, copia el `index.html`, inicia el servicio y asegura que arranque en el reinicio.

**Resultado:** En 3 minutos, tienes un servidor web clonado y funcional, idéntico a los demás.

---

## 3. GitHub Actions (Workflows)

Has notado la carpeta `.github/workflows` vacía. Actualmente, tu laboratorio usa un enfoque **"Pull-Based"** (las instancias tiran del código), por lo que GitHub Actions no está empujando cambios activamente.

### 🤖 ¿Qué podríamos automatizar aquí?
Para llevar este proyecto a nivel "DevOps Pro", podrías crear un archivo `.github/workflows/ci.yml` para:

1.  **Linting de Código:**
    * Cada vez que hagas `git push`, GitHub revisa si tu sintaxis de Terraform (`terraform fmt -check`) y Ansible (`ansible-lint`) es correcta.
    * *Beneficio:* Evita que subas código roto que tire la producción.

2.  **Terraform Plan Automático:**
    * Al abrir un Pull Request, el bot comenta automáticamente qué cambios haría Terraform (plan) antes de que aceptes fusionar.

3.  **Construcción de Imágenes (AMI Baking - Nivel Avanzado):**
    * En lugar de instalar Nginx cada vez que nace una instancia (que tarda 3 mins), GitHub Actions podría usar **Packer** para crear una AMI (Imagen) que ya tenga Nginx instalado.
    * *Beneficio:* Las instancias nuevas estarían listas en 30 segundos en lugar de 3 minutos.

---

##  resumen de Archivos Críticos

| Archivo | Función Crítica |
| :--- | :--- |
| `terraform/main.tf` | Define **CUÁNTOS** servidores debe haber (`min_size`) y **CUÁNDO** matar uno (`health_check_type="ELB"`). |
| `terraform/user_data.sh` | Es el **puente** entre la infraestructura (Terraform) y la configuración (Ansible). Instala Ansible y clona el repo. |
| `ansible/playbook.yml` | Define **CÓMO** debe comportarse el servidor (Instalar Nginx, poner el HTML). |
| `ansible/index.html` | El contenido real de tu sitio web. |

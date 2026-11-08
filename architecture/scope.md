# Alcance y reglas de compromiso

Documento de referencia para todas las pruebas del proyecto **Cloud Security Assessment**. Cualquier prueba fuera de lo descrito aquí queda fuera del proyecto.

## 1. Autorización

- **Laboratorio propio:** todos los recursos los despliega y controla el autor, en su suscripción personal de Azure, su equipo y sus repositorios de GitHub. No hay sistemas ni datos de terceros.
- **Finalidad:** proyecto académico de un bootcamp de ciberseguridad, con fines formativos.

## 2. Enfoque

- **Caja blanca con brecha asumida:** el auditor tiene acceso de lectura al repositorio (Terraform, código y workflows) y una identidad con rol Reader sobre el laboratorio de Azure.
- **Validación:** cada hallazgo se demuestra con una prueba de concepto controlada.
- **Metodología:** fases de CEH (EC-Council) adaptadas a caja blanca; detalle en `pentest/methodology.md`.

## 3. Activos dentro del alcance

| Dominio | Activos |
|---|---|
| Azure — laboratorio | Resource group `azuregoat_app`: Function Apps, Storage Account y contenedores, Cosmos DB, VM, red, cuenta de Automation, identidades gestionadas y RBAC |
| Azure — API | Resource group `rg-vampi`: Container Apps con VAmPI |
| Azure — plataforma | Resource group `rg-platform` (estado de Terraform, identidad OIDC, presupuesto): **solo revisión de configuración, sin explotación** |
| On-premise | VM Ubuntu Server, Docker, clúster kind, Kubernetes Goat y pod `api-test-client` |
| GitHub | Repositorios `cloud-security-assessment` y `cicd-vulnerable-demo`: workflows, configuración e integración OIDC |
| Código | Backend Python y frontend de AzureGoat, VAmPI, Terraform y manifiestos de Kubernetes |

## 4. Fuera del alcance

- Cualquier recurso fuera de los resource groups del laboratorio y de los dos repositorios.
- La infraestructura de Microsoft Azure, GitHub o terceros (planos de control y servicios compartidos).
- Denegación de servicio, pruebas de carga y acciones destructivas no reversibles.
- Ingeniería social y cualquier prueba dirigida a personas.
- La suscripción, el tenant o los recursos de cualquier empleador.

## 5. Reglas durante las pruebas

- **Ventanas de prueba:** los recursos de Azure solo están desplegados durante las sesiones de trabajo y se destruyen al terminar.
- **Exposición mínima:** VAmPI solo acepta conexiones desde la IP del auditor; el API server de Kubernetes nunca se expone a Internet.
- **Credenciales de prueba:** ficticias, canario o de alcance mínimo; nunca credenciales personales ni reutilizables.
- **Persistencia y cambios:** solo para demostrar impacto; se documentan y se revierten en la misma sesión.
- **Registros de auditoría:** no se borran; se analiza qué podría manipular un atacante y qué evidencias se conservan.
- **Terraform:** nunca se ejecuta desde una carpeta sincronizada en la nube (OneDrive); solo desde el pipeline o desde un entorno Linux local.

## 6. Tratamiento de evidencias

- Capturas y salidas de herramientas se guardan en `pentest/evidence/`, excluido del control de versiones por defecto; se revisan antes de publicar nada.
- Claves, tokens y connection strings se ocultan en capturas e informes, aunque pertenezcan a recursos ya destruidos.
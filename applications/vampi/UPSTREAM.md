# Origen del código

| Campo | Valor |
|---|---|
| Proyecto | [VAmPI](https://github.com/erev0s/VAmPI) (erev0s) |
| Commit | `f16052dce83f05847133ec98f01c5193a41de7d8` (07/04/2026) |
| Licencia | MIT (ver `LICENSE`) |
| Cambios respecto al original | Ninguno. Se ha omitido la carpeta `.github/` del proyecto original (sus workflows no aplican aquí) |

**Vulnerable a propósito.** Esta API contiene fallos deliberados del OWASP API Security Top 10. Solo se despliega en el laboratorio, con acceso limitado a la IP del auditor (`terraform/vampi`).

## Cómo se usa en el proyecto

- **Imagen:** el workflow `.github/workflows/build-vampi.yml` construye este directorio con su `Dockerfile` original y la publica en `ghcr.io/pentesting-nublopost-onprem/vampi`.
- **Despliegue:** Azure Container Apps (`terraform/vampi`).
- **Caja blanca:** el código está en el repositorio para revisarlo con Semgrep, Bandit y pip-audit además de probar la API en ejecución.

Las debilidades del `Dockerfile` y de las dependencias (imagen base sin fijar, ejecución como root, versiones antiguas) se mantienen: forman parte del estado AS-IS que se analiza.

# Cliente on-prem de la API (`api-test-client`)

Simula un servicio de NubloPost en el centro de datos propio que consume la API publicada en Azure (VAmPI en Container Apps). Une las dos mitades del laboratorio:

```
pod api-test-client (kind, VM on-prem)
  └─ HTTPS 443 saliente ─> IP pública de casa ─> Container Apps (solo esa IP) ─> VAmPI
```

## Qué se despliega

| Recurso | Detalle |
|---|---|
| Namespace `nublopost-client` | Pod Security Admission en modo `restricted` |
| Secret `vampi-credentials` | URL, usuario y contraseña de la API, generados desde `.env` |
| ConfigMap `hybrid-check` | Script de pruebas `hybrid_check.py` |
| Deployment `api-test-client` | Python 3.13 sin root, sistema de ficheros de solo lectura, sin capacidades ni token de la cuenta de servicio |

El pod está endurecido a propósito. El punto débil es otro: sus credenciales viven en un Secret del clúster. Si en la fase de Kubernetes un atacante llega a leer Secrets (por ejemplo, con el RBAC inseguro de Kubernetes Goat), obtiene acceso a la API de Azure. Esa es la cadena on-prem → cloud del informe.

## Despliegue (dentro de la VM)

```bash
cd ~/cloud-security-assessment && git pull
cd onprem/kubernetes/api-test-client
cp .env.example .env
nano .env                       # VAMPI_URL = salida vampi_url de Terraform
kubectl apply -k .
kubectl -n nublopost-client rollout status deploy/api-test-client
```

Usa una contraseña solo de laboratorio: VAmPI la guarda y, en modo vulnerable, la expone (es uno de sus fallos).

## Pruebas de conexión híbrida

```bash
kubectl -n nublopost-client exec deploy/api-test-client -- python /app/hybrid_check.py --init
```

`--init` reinicia la base de datos de VAmPI, que se pierde cada vez que Container Apps escala a cero. Sin él, las pruebas no tocan los datos.

| Prueba | Qué demuestra |
|---|---|
| DNS | El clúster resuelve el FQDN de Container Apps |
| TCP 443 | Hay salida desde el on-prem |
| TLS | Certificado válido para el nombre, TLS 1.2 o superior |
| Solo HTTPS | HTTP no sirve contenido: redirige a HTTPS |
| API | La IP de casa está en la lista de permitidos (si sale 403, ha cambiado) |
| Autenticación | Login correcto; `/me` sin token devuelve 401 y con token, 200 |

El script nunca imprime la contraseña ni el token, así que su salida sirve tal cual como evidencia.

## Cambiar credenciales o URL

Edita `.env` y repite `kubectl apply -k .`: Kustomize genera un Secret nuevo (con otro sufijo) y reinicia el pod.

## Retirada

```bash
kubectl delete -k .
```

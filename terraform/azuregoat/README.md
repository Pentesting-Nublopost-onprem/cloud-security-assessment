# Raíz `azuregoat`

[AzureGoat](https://github.com/ine-labs/AzureGoat) es el laboratorio vulnerable a propósito que hace de aplicación web de NubloPost: Function Apps, Storage, Cosmos DB, una VM y una cuenta de Automation, en el grupo `azuregoat_app`. Origen, versión y cambios de despliegue: [UPSTREAM.md](UPSTREAM.md).

**Coste:** cobra mientras está encendido (VM, Cosmos DB, Functions). Se despliega, se ataca y se destruye en la misma sesión.

## Despliegue (Azure Cloud Shell, Bash)

Requisito: raíz `platform` aplicada.

```bash
git clone https://github.com/Pentesting-Nublopost-onprem/cloud-security-assessment.git
cd cloud-security-assessment/terraform/azuregoat

# La región debe admitir Functions en Linux Consumption
az functionapp list-consumption-locations --is-linux -o tsv | grep -i sweden

SA=$(az storage account list -g rg-platform --query "[0].name" -o tsv)
terraform init -backend-config="storage_account_name=$SA"
terraform apply
```

- Si la comprobación de región no devuelve nada, elige otra región de esa lista y añade `-var 'location=<región>'` al `apply`.
- El `apply` tarda entre 10 y 15 minutos. La salida `Target_URL` es la aplicación web.
- Durante el `apply`, la salida de algunos pasos aparece como *suppressed*: Terraform la oculta porque llevan claves.

**Nunca hagas commit desde ese clon:** los `local-exec` de AzureGoat escriben claves e IPs reales en ficheros del repositorio. `local.settings.json` se genera en el `apply` a partir de `local.settings.json.example` y está ignorado, pero otros ficheros versionados (como `config.txt`) también se modifican.

## Destrucción (al acabar la sesión)

```bash
terraform destroy
```

Comprueba después que `azuregoat_app` está vacío: `az resource list -g azuregoat_app -o table`. El grupo en sí es de la raíz `platform` y se queda.

## Pruebas

La sesión de Azure (hallazgos previstos, persistencia, Activity Log y criptografía) está en [`pentest/methodology.md`](../../pentest/methodology.md).

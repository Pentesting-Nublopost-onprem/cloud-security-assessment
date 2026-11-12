variable "location" {
  description = "Región de la plataforma y de VAmPI."
  type        = string
  default     = "westeurope"
}

variable "azuregoat_location" {
  description = "Región del grupo de AzureGoat (sus recursos se despliegan en eastus)."
  type        = string
  default     = "eastus"
}

variable "github_org" {
  description = "Organización de GitHub dueña del repositorio."
  type        = string
  default     = "Pentesting-Nublopost-onprem"
}

variable "github_repo" {
  description = "Repositorio cuyos workflows pueden desplegar en Azure."
  type        = string
  default     = "cloud-security-assessment"
}

variable "github_environment" {
  description = "Environment de GitHub que debe declarar el job para obtener el token OIDC."
  type        = string
  default     = "azure-lab"
}

variable "create_budget" {
  description = "Crear el presupuesto de la suscripción (algunas suscripciones de estudiante no admiten presupuestos)."
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Correo que recibe los avisos del presupuesto."
  type        = string
  default     = null

  validation {
    condition     = !var.create_budget || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", coalesce(var.alert_email, "-")))
    error_message = "Indica un correo válido en alert_email (o create_budget = false)."
  }
}

variable "budget_amount" {
  description = "Presupuesto mensual, en la moneda de facturación."
  type        = number
  default     = 20
}

variable "budget_start_date" {
  description = "Inicio del presupuesto (primer día de un mes, RFC 3339). Vacío = el mes en curso."
  type        = string
  default     = null
}

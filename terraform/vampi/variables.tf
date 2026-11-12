variable "allowed_ip" {
  description = "IP pública del auditor (tu conexión de casa). Es la única que llega a VAmPI; la VM on-prem sale por la misma."
  type        = string

  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$", var.allowed_ip))
    error_message = "allowed_ip debe ser una IPv4 sin máscara, por ejemplo 203.0.113.10."
  }
}

variable "image" {
  description = "Imagen de VAmPI que publica el workflow build-vampi en GHCR. Mejor la etiqueta del commit que latest."
  type        = string
  default     = "ghcr.io/pentesting-nublopost-onprem/vampi:latest"
}

variable "vulnerable" {
  description = "Modo de VAmPI: 1 = vulnerable (AS-IS), 0 = corregido (TO-BE)."
  type        = number
  default     = 1

  validation {
    condition     = contains([0, 1], var.vulnerable)
    error_message = "vulnerable solo admite 0 o 1."
  }
}

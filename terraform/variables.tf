variable "kubeconfig_path" {
  description = "Chemin du kubeconfig"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Contexte Kubernetes cible (ex. kind-observability)"
  type        = string
  default     = "kind-observability"
}

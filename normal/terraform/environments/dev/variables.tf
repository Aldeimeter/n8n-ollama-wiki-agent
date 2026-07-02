variable "zone" {
  type    = string
  default = "ru-central1-a"
}

variable "folder_id" {
  type = string
}

variable "project" {
  type = string
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "environment must be in ['dev', 'stage', 'prod']"
  }
}

variable "deploy_user" {
  type    = string
  default = "ansible"
}

terraform {
  required_version = ">= 1.15.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~>0.206"
    }
  }
  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket = "ollama-wikijs-terraform-state-b1gvtrng7fe9okm4to8h"
    key    = "dev/terraform.tfstate"
    region = "ru-central1"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    use_lockfile                = true
  }
}

provider "yandex" {
  zone = var.zone
}

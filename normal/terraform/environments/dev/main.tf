locals {
  prefix = "${var.project}-${var.environment}"
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2404-lts"
}



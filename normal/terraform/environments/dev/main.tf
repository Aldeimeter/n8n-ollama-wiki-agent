locals {
  prefix = "${var.project}-${var.environment}"
}

resource "yandex_vpc_network" "main" {
  name = "${local.prefix}-network"
  folder_id = var.folder_id
}

resource "yandex_vpc_subnet" "main" {
  name = "${local.prefix}-subnet"
  folder_id = var.folder_id
  network_id = yandex_vpc_network.main.id
  zone = var.zone
  v4_cidr_blocks = ["10.0.1.0/24"]
}

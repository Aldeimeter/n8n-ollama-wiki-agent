resource "yandex_vpc_network" "main" {
  name      = "${local.prefix}-network"
  folder_id = var.folder_id
}

resource "yandex_vpc_subnet" "main" {
  name           = "${local.prefix}-subnet"
  folder_id      = var.folder_id
  network_id     = yandex_vpc_network.main.id
  route_table_id = yandex_vpc_route_table.route_table.id
  zone           = var.zone
  v4_cidr_blocks = ["10.0.1.0/24"]
}

resource "yandex_vpc_gateway" "nat_gateway" {
  name      = "${local.prefix}-nat-gateway"
  folder_id = var.folder_id
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "route_table" {
  name       = "${local.prefix}-route-table"
  folder_id  = var.folder_id
  network_id = yandex_vpc_network.main.id
  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

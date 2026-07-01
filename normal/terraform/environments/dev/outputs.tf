output "subnet_cidr" {
  value = one(yandex_vpc_subnet.main.v4_cidr_blocks)
}


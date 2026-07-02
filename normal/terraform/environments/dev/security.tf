resource "yandex_vpc_security_group" "internal" {
  name       = "${local.prefix}-internal-sg"
  network_id = yandex_vpc_network.main.id

  ingress {
    protocol          = "ANY"
    description       = "Allow incoming traffic from members of the same security group"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }

  egress {
    description    = "Allow all outbound (apt, docker pull, DNS)"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "bastion" {
  name       = "${local.prefix}-bastion-sg"
  network_id = yandex_vpc_network.main.id
  ingress {
    description    = "SSH bastion jump-host"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

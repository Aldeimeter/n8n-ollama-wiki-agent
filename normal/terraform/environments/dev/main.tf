locals {
  prefix = "${var.project}-${var.environment}"
}

resource "yandex_vpc_network" "main" {
  name      = "${local.prefix}-network"
  folder_id = var.folder_id
}

resource "yandex_vpc_subnet" "main" {
  name           = "${local.prefix}-subnet"
  folder_id      = var.folder_id
  network_id     = yandex_vpc_network.main.id
  zone           = var.zone
  v4_cidr_blocks = ["10.0.1.0/24"]
}

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

  ingress {
    description    = "SSH for ansible"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow all outbound (apt, docker pull, DNS)"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "public_wikijs" {
  name       = "${local.prefix}-public-wikijs-sg"
  network_id = yandex_vpc_network.main.id

  ingress {
    description    = "Wiki.js web UI"
    protocol       = "TCP"
    port           = "3000"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "public_n8n_web" {
  name       = "${local.prefix}-public-n8n-web-sg"
  network_id = yandex_vpc_network.main.id

  ingress {
    description    = "n8n web UI"
    protocol       = "TCP"
    port           = "5678"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "ssh_private_key" {
  filename        = "${path.module}/.ssh/ansible_ssh.priv"
  content         = tls_private_key.ssh.private_key_openssh
  file_permission = "0600"
}

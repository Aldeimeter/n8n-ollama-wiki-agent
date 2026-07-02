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

resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "ssh_private_key" {
  filename        = "${path.module}/.ssh/ansible_ssh.priv"
  content         = tls_private_key.ssh.private_key_openssh
  file_permission = "0600"
}

resource "yandex_compute_instance" "bastion" {
  name        = "${local.prefix}-bastion"
  hostname    = "bastion"
  zone        = var.zone
  platform_id = "standard-v3"

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.main.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.internal.id, yandex_vpc_security_group.bastion.id]
  }

  metadata = {
    ssh-keys = "${var.deploy_user}:${trimspace(tls_private_key.ssh.public_key_openssh)}"
  }

  scheduling_policy { preemptible = true }
  allow_stopping_for_update = true
}

locals {
  vms = {
    postgresql = { cores = 2, memory = 2, core_fraction = 20, groups = ["db"] }
    ollama     = { cores = 4, memory = 8, core_fraction = 100, disk = 30, groups = ["ai"] }
    n8n-web    = { cores = 2, memory = 2, core_fraction = 20, groups = ["automation", "n8n_web"] }
    n8n-worker = { cores = 2, memory = 2, core_fraction = 20, groups = ["automation", "n8n_worker"] }
    wikijs     = { cores = 2, memory = 2, core_fraction = 20, groups = ["wiki"] }
    redis      = { cores = 2, memory = 1, core_fraction = 20, groups = ["queue"] }
  }

}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2404-lts"
}

resource "yandex_compute_instance" "vm" {
  for_each = local.vms

  name        = "${local.prefix}-${each.key}"
  hostname    = each.key
  platform_id = "standard-v3"
  zone        = var.zone


  resources {
    cores         = each.value.cores
    memory        = each.value.memory
    core_fraction = each.value.core_fraction
  }


  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = try(each.value.disk, 20) # if disk not set, default = 20
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.main.id
    nat       = false
    security_group_ids = [
      yandex_vpc_security_group.internal.id,
    ]
  }

  metadata = {
    ssh-keys = "${var.deploy_user}:${trimspace(tls_private_key.ssh.public_key_openssh)}"
  }

  scheduling_policy { preemptible = true }
  allow_stopping_for_update = true
}

locals {
  # every distinct group across the stack
  all_groups = distinct(flatten([for _, vm in local.vms : vm.groups]))

  # per-host connection facts, read back off created instances 
  host_vars = {
    for name, inst in yandex_compute_instance.vm : name => {
      ansible_host            = inst.network_interface[0].ip_address
      ansible_ssh_common_args = "-o ProxyCommand=\"ssh -i ${abspath(local_sensitive_file.ssh_private_key.filename)} -W %h:%p -o StrictHostKeyChecking=no ${var.deploy_user}@${yandex_compute_instance.bastion.network_interface[0].nat_ip_address}\""
      internal_ip             = inst.network_interface[0].ip_address
    }
  }
  # the ansible YAML inventory as an HCL object
  yc_inventory = {
    all = {
      vars = {
        ansible_user                 = var.deploy_user
        deploy_user                  = var.deploy_user
        ansible_ssh_private_key_file = abspath(local_sensitive_file.ssh_private_key.filename)
        private_subnet               = one(yandex_vpc_subnet.main.v4_cidr_blocks)

      }
      children = {
        for g in local.all_groups : g => {
          hosts = {
            for name, vm in local.vms : name => local.host_vars[name]
            if contains(vm.groups, g)
          }
        }
      }
    }
  }
}

resource "local_file" "yc_inventory" {
  filename = "${path.module}/../../../ansible/inventories/yc/hosts.yml"
  content  = yamlencode(local.yc_inventory)
}

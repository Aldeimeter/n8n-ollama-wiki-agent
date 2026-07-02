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

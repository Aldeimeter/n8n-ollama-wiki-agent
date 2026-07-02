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

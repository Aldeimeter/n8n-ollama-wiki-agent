output "nginx_public_ip" {
  value = yandex_compute_instance.vm["nginx"].network_interface[0].nat_ip_address
}


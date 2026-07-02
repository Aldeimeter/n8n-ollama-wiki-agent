resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "ssh_private_key" {
  filename        = "${path.module}/.ssh/ansible_ssh.priv"
  content         = tls_private_key.ssh.private_key_openssh
  file_permission = "0600"
}

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

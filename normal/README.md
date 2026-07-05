# normal

Ollama + n8n + Wiki.js + Postgres/Redis stack, provisioned by one Ansible
codebase against Yandex Cloud (Terraform) or, historically, local Vagrant VMs.

## Supported target: Yandex Cloud only

As of the nginx reverse-proxy work, **Vagrant is frozen and no longer
maintained.** It still boots the pre-nginx stack (`vagrant/Vagrantfile`,
`vagrant/vms.yml`, `ansible/inventories/vagrant/`), but nothing added from this
point forward — the `nginx` role, the `proxy` host group, `n8n_public_url` /
`wikijs_site_url`, subdomain routing — is wired up for Vagrant. Don't expect
`ansible-playbook -i inventories/vagrant site.yml` to reflect the current
stack; treat it as a snapshot of an earlier phase, not a second supported
environment.

All new work targets `terraform/environments/dev` + `ansible/inventories/yc`.

## Running against YC

```
cd terraform/environments/dev
terraform apply                          # provisions VMs, renders ansible/inventories/yc/hosts.yml
cd ../../../ansible
ansible-galaxy install -r requirements.yml -p roles/
ansible-playbook -i inventories/yc site.yml
```

`terraform apply` re-renders `inventories/yc/hosts.yml` from live instance
state, so re-run it any time the infra changes before re-running the
playbook. The stack is cost-controlled via `terraform destroy` between
sessions — the nginx VM is `preemptible` and gets a **new public IP on every
`apply` after a `destroy`.**

## Reaching n8n and Wiki.js

Both apps sit behind a single nginx VM (the `proxy` group), split by
hostname, not path — Wiki.js doesn't support being served from a subpath
(the maintainers have declined it outright: asset/cookie/routing assumptions
all expect it owns the whole origin), so subdomains are used for both:

- `http://wiki.stack.local/` → Wiki.js
- `http://n8n.stack.local/` → n8n

These hostnames aren't real DNS — nginx picks a `server {}` block by the
`Host` header, and `stack.local` is never resolved anywhere except your own
machine. You need to point it at nginx's current public IP yourself:

```
terraform output nginx_public_ip
```

then add to `/etc/hosts` **on the machine running your browser** (not the
nginx VM):

```
<nginx_public_ip> n8n.stack.local
<nginx_public_ip> wiki.stack.local
```

Because that IP changes on every `apply` after a `destroy`, you'll need to
re-run `terraform output nginx_public_ip` and update these two lines each
time you bring the stack back up. (A wildcard resolver like `nip.io` would
remove this step entirely by encoding the IP in the hostname itself — not
wired up yet, worth revisiting if the manual re-edit gets old.)

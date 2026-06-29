#!/usr/bin/env python3
"""Dynamic ansible inventory from vagrant ssh-config

Vagrant supplies the live connection details (host, NAT port, private key),
while the GROUPS map below supplies membership.
Group names MUST match the files in group_vars/ (db, ai, n8n, wikijs)
"""

import json, os, subprocess, sys

# host -> groups. Mirror your group_vars/*.yml filenames
GROUPS = {
    "postgresql": ["db"],
    "ollama": ["ai"],
    "n8n-web": ["automation", "n8n_web"],
    "n8n-worker": ["automation", "n8n_worker"],
    "wikijs": ["wiki"],
    "redis": ["queue"],
}

# this script lives at normal/ansible/inventory/vagrant.py
# the Vagrantfile and .vagrant/ lives at normal/vagrant/.
HERE = os.path.dirname(os.path.abspath(__file__))
VAGRANT_DIR = os.path.normpath(os.path.join(HERE, "..", "..", "vagrant"))


def ssh_config():
    """Run `vagrant ssh-config` in the Vagrant dir, parse into {host: { key: val }}"""
    out = subprocess.run(
        ["vagrant", "ssh-config"], cwd=VAGRANT_DIR, capture_output=True, text=True
    ).stdout

    hosts, cur = {}, None

    for line in out.splitlines():
        line = line.strip()
        if line.startswith("Host "):
            cur = line.split(None, 1)[1]
            hosts[cur] = {}
        elif cur and " " in line:
            key, val = line.split(None, 1)
            hosts[cur][key] = val
    return hosts


def build():
    inv = {"_meta": {"hostvars": {}}, "all": {"children": []}}
    for host, cfg in ssh_config().items():
        inv["_meta"]["hostvars"][host] = {
            "ansible_host": cfg.get("HostName"),
            "ansible_port": int(cfg.get("Port", 22)),
            "ansible_user": cfg.get("User"),
            "ansible_ssh_private_key_file": cfg.get("IdentityFile", "").strip('""'),
        }
        for group in GROUPS.get(host, ["ungrouped"]):
            inv.setdefault(group, {"hosts": []})["hosts"].append(host)
            if group not in inv["all"]["children"]:
                inv["all"]["children"].append(group)
    return inv


if __name__ == "__main__":
    # Ansible calls `--list` (whole inventory) or `--host X` (one host's vars)
    # We return everything under _meta on --list, so --host is just {}.
    print(json.dumps({} if "--host" in sys.argv else build(), indent=2))

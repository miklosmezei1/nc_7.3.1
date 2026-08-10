# Ansible playbook to quickly set up a test environment

Based on the guide at [../develop.md](../develop.md).

## Requirements

- Set up an Ubuntu VM (24 LTS was tested)
    - Recommended to have 8 GB of RAM and 4 CPU cores
    - Recommended to have 50 GB of disk capacity (at least 20 GB)
    - Optional: Disable LVM during installation
    - Ideally, use the same username as your local UNIX user (otherwise, uncomment the `remote_user` line in the playbook and replace with the user name of the Ubuntu VM)
    - Enable and install OpenSSH
    - Do not enable any snaps
- Install your SSH key to the Ubuntu VM: `cat ~/.ssh/id_*.pub | ssh <ubuntu-vm-ip> tee .ssh/authorized_keys`
- Disable sudo password prompt in the Ubuntu VM
    - Ensure the following line is like so: `/etc/sudoers`: `%sudo   ALL=(ALL:ALL) NOPASSWD: ALL`
- Set up Tailscale
    - If you did not already, create a Tailscale account: https://login.tailscale.com/login
    - Head to: https://login.tailscale.com/admin/dns
        - Make sure to enable MagicDNS And HTTPS Certificates:
          <img width="700" height="373" alt="Bildschirmfoto vom 2025-10-01 17-09-35" src="https://github.com/user-attachments/assets/cf5c8f81-ed4d-4219-a1d7-894b84044cd0" />
        - Also go to https://login.tailscale.com/admin/acls/visual/node-attributes/add and add a tag that allows to use Tailscale Funnel:
          <img width="1499" height="1207" alt="Image" src="https://github.com/user-attachments/assets/05cf24e8-28e5-4fcb-aebd-5d62c49fcb47" />
    - Add your server to your Tailnet
        - **Register your server:**
            - Head to: https://login.tailscale.com/admin/machines/new-linux
            - Click on "Generate install script" (disable the Tags feature) and extract the tskey-auth part that you will need to add to variables of the playbook
- [Install Ansible locally](https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_installation.html)
- Clone this repository locally on your client
    - Set up git or use the GitHub cli: `gh repo clone nextcloud-gmbh/enterprise-aio`

Now is a good time to create a snapshot of the Ubuntu VM in case you need to revert to a clean
state quickly.

## Configure the Playbook

- Configure the variables in the playbook (`enterprise-aio.yaml`) at the top (see `vars` dictionary)
- Set up the inventory (`inventory.yaml`) -> replace the IP address with the one of your Ubuntu VM

## Run the playbook

```sh
cd ansible-example
ansible-playbook enterprise-aio.yaml -i inventory.yaml
```

The playbook is idempotent and can be run multiple times.

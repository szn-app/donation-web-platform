### set values for terraform tool
# check provision_cloud script to manually set these values

# locally generated ssh key pair that will be installed on the servers
ssh_private_key = "~/.ssh/id_ed25519"
ssh_public_key = "~/.ssh/id_ed25519.pub"

# variable for the kube-hetzner module use shell export instead (check script)
hcloud_token = "" # hetzner cloud token
# snapshot ids created using kube-hetzner module 
microos_x86_snapshot_id = ""
microos_arm_snapshot_id = ""
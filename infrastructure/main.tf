### Resource configuration

# Original template from https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner/blob/master/kube.tf.example

# https://registry.terraform.io/modules/kube-hetzner/kube-hetzner/hcloud
# https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner/blob/master/docs/terraform.md
module "kube-hetzner" {
  source = "kube-hetzner/kube-hetzner/hcloud"
  version = "2.16.0"
  providers = {
    hcloud = hcloud
  }
  hcloud_token = var.hcloud_token

  create_kubeconfig = false
  export_values = false # do not export local files 
  create_kustomization = false # do not create local file for kustomization backup

  microos_x86_snapshot_id = var.microos_x86_snapshot_id
  microos_arm_snapshot_id = var.microos_arm_snapshot_id

  ssh_port = 2220 # defualt: 22
  ssh_public_key = file(var.ssh_public_key)
  ssh_private_key = file(var.ssh_private_key)

  automatically_upgrade_k3s = true
  initial_k3s_channel="v1.31"
  automatically_upgrade_os = true
  system_upgrade_enable_eviction = true
  system_upgrade_use_drain = true
  allow_scheduling_on_control_plane = false

  cluster_name = "kubernetes-production"

  network_region = var.network_location[0].zone 
  # DNS provided by Hetzner https://docs.hetzner.com/dns-console/dns/general/recursive-name-servers/.
  dns_servers = [
    "1.1.1.1",  # Cloudflare
    "8.8.8.8",  # Google DNS
    "2606:4700:4700::1111"  # IPv6 Cloudflare DNS
    # "185.12.64.1", # Hetzner DNS
    # "2a01:4ff:ff00::add:1", # Hetzner DNS
  ]

  # https://www.hetzner.com/cloud/load-balancer
  load_balancer_type     = "lb11"
  load_balancer_location = "fsn1"
  enable_klipper_metal_lb = "false"
  # Disables the public network of the load balancer. (default: false).
  # load_balancer_disable_public_network = true

  cni_plugin = "cilium"
  disable_kube_proxy = true # replace 'kube-proxy' with 'cilium'
  disable_network_policy = true
  cilium_routing_mode = "native"
  # NOTE: if Cilium UI enabled it can be accessed using ssh tunnel
  cilium_hubble_enabled = false
  ingress_controller = "none"
  # ingress_target_namespace = "gateway"

  control_plane_nodepools = [
    {
      name        = "control-plane",
      server_type = var.instance_size.small,
      location    = var.network_location[0].region[0],
      placement_group = "controller"
      labels      = local.label.control_plane,
      taints      = [],
      count       = 1 # TODO: 3 nodes for HA
      # kubelet_args = ["kube-reserved=cpu=250m,memory=1500Mi,ephemeral-storage=1Gi", "system-reserved=cpu=250m,memory=300Mi"]
    }
  ]

  agent_nodepools = [
    {
      name        = "agent-small",
      server_type = var.instance_size.small,
      location    = var.network_location[0].region[0],
      placement_group = "worker"
      labels      = local.label.worker,
      taints      = [],
      count       = 2
      # kubelet_args = ["kube-reserved=cpu=50m,memory=300Mi,ephemeral-storage=1Gi", "system-reserved=cpu=250m,memory=300Mi"]
    },
  ]
}




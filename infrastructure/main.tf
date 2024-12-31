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
  # This does not protect deletion from Terraform itself, only though the Hetzner UI interface
  enable_delete_protection = {
    floating_ip   = true
    load_balancer = true
    volume        = true
  }

  microos_x86_snapshot_id = var.microos_x86_snapshot_id
  microos_arm_snapshot_id = var.microos_arm_snapshot_id

  ssh_port = 2220 # defualt: 22
  ssh_public_key = file(var.ssh_public_key)
  ssh_private_key = file(var.ssh_private_key)

  cluster_name = "k3s"
  use_cluster_name_in_node_name = true
  automatically_upgrade_k3s = true
  initial_k3s_channel = "v1.31" # "stable"
  system_upgrade_enable_eviction = true
  system_upgrade_use_drain = true
  allow_scheduling_on_control_plane = false

  automatically_upgrade_os = false # NOTE: must be turned off for single control node setup.
  kured_options = {
    "reboot-days": "su,mo,tu,we,th,fr,sa",
    "start-time": "9pm",
    "end-time": "4pm",
    "time-zone": "America/Chicago",
  }

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

  # for production HA kubernetes: 3 control nodes + 2 agent nodes
  control_plane_nodepools = [
    {
      name        = "control-plane",
      server_type = var.instance_size.small,
      location    = var.network_location[0].region[0],
      placement_group = "controller"
      labels      = local.label.control_plane,
      taints      = [],
      count       = 1 # NOTE: set to 3 control nodes for HA and allowing OS upgrades
      # kubelet_args = ["kube-reserved=cpu=250m,memory=1500Mi,ephemeral-storage=1Gi", "system-reserved=cpu=250m,memory=300Mi"]
    },
    {
      name        = "control-plane-arm",
      server_type = var.instance_size.small_arm,
      location    = var.network_location[0].region[0],
      placement_group = "controller"
      labels      = local.label.control_plane_arm,
      taints      = [],
      count       = 0 
    }
  ]

  # node type per pool > # nodes
  # NOTE: to remove nodes, drain them first from any kubernetes workloads (`kubectl drain ...`)
  agent_nodepools = [
    {
      name        = "worker-small",
      server_type = var.instance_size.small,
      location    = var.network_location[0].region[0],
      placement_group = "worker"
      labels      = local.label.worker,
      taints      = [],
      count       = 1
    },

    {
      name        = "worker-medium",
      server_type = var.instance_size.medium,
      location    = var.network_location[0].region[0],
      placement_group = "worker"
      labels      = local.label.worker,
      taints      = [],
      count       = 0
    },

    {
      name        = "worker-large",
      server_type = var.instance_size.large,
      location    = var.network_location[0].region[0],
      placement_group = "worker"
      labels      = local.label.worker,
      taints      = [],
      count       = 0
    },
  ]

  autoscaler_nodepools = [
    {
      name        = "autoscaled-small"
      server_type = var.instance_size.small
      location    = var.network_location[0].region[0],
      min_nodes   = 0
      max_nodes   = 2
      labels      = {
        "node.kubernetes.io/role": "peak-workloads" # convention labels (doesn't seem used by )
      }
      taints      = [
        {
          key= "node.kubernetes.io/role"
          value= "peak-workloads"
          effect= "NoExecute"
        }
      ]
      # kubelet_args = ["kube-reserved=cpu=250m,memory=1500Mi,ephemeral-storage=1Gi", "system-reserved=cpu=250m,memory=300Mi"]
   }
  ]

}




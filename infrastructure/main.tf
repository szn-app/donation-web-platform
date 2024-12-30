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

  cluster_name = "prod-k3s"

  network_region = var.network_location[0].zone 
  # DNS provided by Hetzner https://docs.hetzner.com/dns-console/dns/general/recursive-name-servers/.
  dns_servers = [
    "185.12.64.1", # Hetzner DNS
    "8.8.8.8", # Google DNS
    "2a01:4ff:ff00::add:1", # Hetzner DNS
  ]

  # https://www.hetzner.com/cloud/load-balancer
  load_balancer_type     = "lb11"
  load_balancer_location = "fsn1"
  # Disables the public network of the load balancer. (default: false).
  # load_balancer_disable_public_network = true

  # Use the klipperLB (similar to metalLB), instead of the default Hetzner load balancer
  enable_klipper_metal_lb = "true" # when true: assumes `allow_scheduling_on_control_plane`=true

  cni_plugin = "flannel"

  ingress_controller = "nginx" # TODO: change to none after verifying that it works and replacing it with application ingress loadbalancer

  system_upgrade_use_drain = false
  allow_scheduling_on_control_plane = true

  control_plane_nodepools = [
    {
      name        = "control-plane",
      server_type = var.instance_size.small,
      location    = var.network_location[0].region[0],
      placement_group = "controller"
      labels      = local.label.control_plane,
      taints      = [],
      count       = 1 # TODO: change to 3 after testing
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
      count       = 0 # TODO: increase # of workers and avoid scheduling on controllers
      # kubelet_args = ["kube-reserved=cpu=50m,memory=300Mi,ephemeral-storage=1Gi", "system-reserved=cpu=250m,memory=300Mi"]
    },
  ]
}




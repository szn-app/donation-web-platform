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

  cluster_name = "prod-k3s"

  ssh_port = 2220 # defualt: 22
  ssh_public_key = file(var.ssh_public_key)
  ssh_private_key = file(var.ssh_private_key)

  # Hetzner locations see https://docs.hetzner.com/cloud/general/locations/
  network_region = var.network_location[0].zone 

  control_plane_nodepools = [
    {
      name        = "control-plane-fsn1",
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
      server_type = "cx22",
      location    = "fsn1",
      placement_group = "worker"
      labels      = local.label.worker,
      taints      = [],
      count       = 0
      # kubelet_args = ["kube-reserved=cpu=50m,memory=300Mi,ephemeral-storage=1Gi", "system-reserved=cpu=250m,memory=300Mi"]
    },
  ]

  # https://www.hetzner.com/cloud/load-balancer
  load_balancer_type     = "lb11"
  load_balancer_location = "fsn1"

  # Disables the public network of the load balancer. (default: false).
  # load_balancer_disable_public_network = true

  # Enable etcd snapshot backups to S3 storage.
  # Just provide a map with the needed settings (according to your S3 storage provider) and backups to S3 will
  # be enabled (with the default settings for etcd snapshots).
  # Cloudflare's R2 offers 10GB, 10 million reads and 1 million writes per month for free.
  # For proper context, have a look at https://docs.k3s.io/datastore/backup-restore.
  # You also can use additional parameters from https://docs.k3s.io/cli/etcd-snapshot, such as `etc-s3-folder`
  # etcd_s3_backup = {
  #   etcd-s3-endpoint        = "xxxx.r2.cloudflarestorage.com"
  #   etcd-s3-access-key      = "<access-key>"
  #   etcd-s3-secret-key      = "<secret-key>"
  #   etcd-s3-bucket          = "k3s-etcd-snapshots"
  #   etcd-s3-region          = "<your-s3-bucket-region|usually required for aws>"
  # }

  ingress_controller = "nginx" # TODO: change to none after verifying that it works and replacing it with application ingress loadbalancer

  # Use the klipperLB (similar to metalLB), instead of the default Hetzner load balancer
  enable_klipper_metal_lb = "true" # when true: assumes `allow_scheduling_on_control_plane`=true
  allow_scheduling_on_control_plane = true

  system_upgrade_use_drain = false

  cni_plugin = "flannel"

  # IP Addresses to use for the DNS Servers, the defaults are the ones provided by Hetzner https://docs.hetzner.com/dns-console/dns/general/recursive-name-servers/.
  # The number of different DNS servers is limited to 3 by Kubernetes itself.
  # It's always a good idea to have at least 1 IPv4 and 1 IPv6 DNS server for robustness.
  dns_servers = [
    "185.12.64.1",
    "185.12.64.2",
    "2a01:4ff:ff00::add:1",
  ]

  create_kubeconfig = false

  export_values = false # do not export local files 
  create_kustomization = false # do not create local file for kustomization backup
}




### Input/Output configurations

locals { 
  tag = { 
    project = ""
  }

  # NOTE: "role=<value>" is a custom key that postinstall custom scripts will synchronize the role label to Longhorn internal node tags
  label = {
    control_plane = ["role=control-plane", "size=${var.instance_size.small}", "region=${var.network_location[0].region[0]}"], 
    control_plane_arm = ["role=control-plane", "size=${var.instance_size.small_arm}", "region=${var.network_location[0].region[0]}"], 
    worker = ["role=worker", "size=${var.instance_size.small}", "region=${var.network_location[0].region[0]}"]

  }
}

# ---

# export TF_VAR_hcloud_token=<...>
variable "hcloud_token" { 
    type = string
    description = "Access Token to Hetzner cloud API"
    sensitive = true 
}

variable "ssh_private_key" { 
    type = string
    sensitive = true 
}

variable "ssh_public_key" {
    type = string
    sensitive = true 
}

variable "kubeconfig-credentials-path" { 
    type = string 
    sensitive = true
    default = "~/.ssh/k8s-project-credentials.kubeconfig.yaml"
}

variable "microos_x86_snapshot_id" {
    type = string
}

variable "microos_arm_snapshot_id" {
    type = string 
}

# zones > regions
# Hetzner locations see https://docs.hetzner.com/cloud/general/locations/
variable "network_location" { 
    type = list(object({
        zone = string, 
        region = list(string)
    }))

    default = [
        {
            zone = "eu-central", 
            region = ["fsn1", "nbg1", "hel1"]
        }, { 
            zone = "us-east", 
            region = ["ash"]
        }, {
            zone = "us-west", 
            region = ["hil"]
        }, 
        {
            zone = "ap-southeast", 
            region = ["sin"]
        }
    ]
    description = "Hetzner cloud network zones - https://docs.hetzner.com/cloud/general/locations/"
}

variable "instance_size" { 
    type = map(string)

    default = {
        small = "cx22", 
        medium = "cx32",
        large = "cx42",
        extralarge = "cx52"

        small_arm = "cax11", 
        medium_arm = "cax21",
        large_arm = "cax31",
        extralarge_arm = "cax41"
    }
    description = "Hetzner cloud server types of shared Intel vCPU - https://www.hetzner.com/cloud/#pricing"
}

# --- 

# data "hcloud_server_types" "all_servers" {}
# output "test_server_info_retrieval" {
#     value = data.hcloud_server_types.all_servers.server_types[0].name
# }

# --- 

# Kubeconfig file content with external IP address
output "kubeconfig" { 
  value     = module.kube-hetzner.kubeconfig
  sensitive = true
}

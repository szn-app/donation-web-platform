### Input/Output configurations

locals { 
  tag = { 
    project = ""
  }

  label = {
    control_plane = ["role=control-plane", "size=${var.instance_size.small}", "region=${var.network_location[0].region[0]}"], 
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

# zones > regions
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
        small = "CX22", 
        medium = "CX32",
        large = "CX42",
        extralarge = "CX52"
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

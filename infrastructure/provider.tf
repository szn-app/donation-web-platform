# Providers configuration

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # https://registry.terraform.io/providers/hetznercloud/hcloud/latest
    hcloud = { 
      source = "hetznercloud/hcloud"
      version = "1.49.1"
    }
 
    # helm = {
    #   source  = "hashicorp/helm"
    #   version = ">= 2.17.0"
    # }
  }
}

# Hetzner Cloud Provider
provider "hcloud" {
  token = var.hcloud_token
}

# Helm Provider
# provider "helm" {
#   kubernetes {
#     config_path = "./k3s_kubeconfig.yaml"
#   }
# }



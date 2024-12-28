#!/bin/bash

# [old] hcloud version && docker-credential-pass version && aws --version
# [manual] setup object storage in Hetzner cloud to allow for kOps operations

# https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner
hetzner() { 

    hcloud version && kubectl version && packer --version
    tofu --version && terraform version # either tools should work

    ssh-keygen -t ed25519

    {
        tmp_script=$(mktemp)
        curl -sSL -o "${tmp_script}" https://raw.githubusercontent.com/kube-hetzner/terraform-hcloud-kube-hetzner/master/scripts/create.sh
        chmod +x "${tmp_script}" 
        "${tmp_script}"
        rm "${tmp_script}"
    }
    hcloud context create "k8s"
    
    ### set variables using "terraform.tfvars" or CLI argument or env variables
    export TF_VAR_hcloud_token=""
    export TF_VAR_ssh_private_key=""
    export TF_VAR_ssh_public_key=""
    
    terraform init --upgrade # installed terraform module dependecies
    terraform validate

    terraform plan -no-color -out kubernetes_cluster.tfplan > plan_readable.txt
    terraform apply kubernetes_cluster.tfplan

    # create kubeconfig (NOTE: shouldn't be version controlled)
    terraform output --raw kubeconfig > clustername_kubeconfig.yaml

    kubectl get namespaces --kubeconfig=k3s_kubeconfig.yaml
    kubectl get nodes --kubeconfig=k3s_kubeconfig.yaml
    hcloud all list
    terraform output kubeconfig
    terraform output -json kubeconfig | jq
    terraform state list
    terraform state show type_of_resource.label_of_resource

    # connect to deployed cluster
    kubectl --kubeconfig clustername_kubeconfig.yaml

    exit 0; 
    terraform destroy
}
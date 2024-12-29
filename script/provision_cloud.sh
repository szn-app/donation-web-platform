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
    hcloud context create "k8s-project"
    

    ### handle terraform 
    {
        pushd infrastructure

        ### set variables using "terraform.tfvars" or CLI argument or env variables
        # export TF_VAR_hcloud_token=""
        # export TF_VAR_ssh_private_key=""
        # export TF_VAR_ssh_public_key=""

        export TF_TOKEN_app_terraform_io=""  
        terraform init --upgrade # installed terraform module dependecies
        terraform validate

        terraform plan -no-color -out kube.tfplan > output_plan.txt.tmp
        terraform apply kube.tfplan

        # create kubeconfig (NOTE: do not version control)
        terraform output --raw kubeconfig > ~/.ssh/k8s-project-credentials.kubeconfig.yaml

        ### verify: 
        kubectl --kubeconfig ~/.ssh/k8s-project-credentials.kubeconfig.yaml get all -A 
        hcloud all list
        terraform state list
        terraform state show type_of_resource.label_of_resource

        popd
        # terraform destroy
    }
    
}
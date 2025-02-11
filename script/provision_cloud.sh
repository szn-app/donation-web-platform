#!/bin/bash

source "./script/library/hetzner/install_gateway_api_cilium.sh"
source "./script/library/installation_gateway_controller_nginx.sh"
source "./script/library/hetzner/install_storage_class.sh"
source "./script/library/install_kubernetes_dashboard.sh"
source "./script/library/install_cert_manager.sh"
source "./script/library/install_monitoring.sh"
source "./script/library/install_envoy_gateway_class.sh"

# remove warnings and logs from coredns
remove_warnings_logs() { 
  kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-custom
  namespace: kube-system
data:
  log.override: |
    #
  stub.server: |
    #
EOF

  kubectl rollout restart deploy/coredns -n kube-system
}

# https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner
hetzner_cloud_provision() {
    action=${1:-"install"}

    if ! command -v kubectl-ctx &> /dev/null; then
        echo "kubectl ctx is not installed. Exiting."
        return
    fi

    if [ "$action" == "delete" ]; then
      pushd infrastructure
        ### [manual] set variables using "terraform.tfvars" or CLI argument or equivalent env variables (with `TF_TOKEN_*` prefix)
        find . -name "*.tfvars"
        set -a && source ".env" && set +a # export TF_TOKEN_app_terraform_io="" 

        printf "Destroying infrastructure...\n"
        terraform init
        terraform destroy -auto-approve
      popd
      return 
    fi

    {
      hcloud version && kubectl version && packer --version
      tofu --version && terraform version # either tools should work
      helm version && cilium version
      k9s version && kubectl krew version
      kubectl krew list | grep ctx && kubectl krew list | grep ns 

    }

    manually_prerequisites() {
      # TODO: automate

      # [manual, then move to ~/.ssh] 
      # Generate an ed25519 SSH key pair - will also be used to log into the machines using ssh
      ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 && chmod 600 ~/.ssh/id_ed25519
      

      # create snapshots with kube-hetzner binaries (idempotent can be executed in existing project)
      create_snapshot() {
          pushd infrastructure

          tmp_script=$(mktemp)
          curl -sSL -o "${tmp_script}" https://raw.githubusercontent.com/kube-hetzner/terraform-hcloud-kube-hetzner/master/scripts/create.sh
          chmod +x "${tmp_script}" 
          "${tmp_script}"
          rm "${tmp_script}"

          popd
      }
      create_snapshot
    }  
    
    ### handle terraform 
    {
      pushd infrastructure

      
      generate_kubeconfig() {
        find . -name "*.tfvars"
        set -a && source ".env" && set +a # export TF_TOKEN_app_terraform_io="" 

        # create kubeconfig (NOTE: do not version control this credentials file)
        terraform output --raw kubeconfig > "$(realpath ~/.kube)/kubernetes-project-credentials.kubeconfig.yml"

        # Set default kubeconfig file path
        DEFAULT_KUBECONFIG="$HOME/.kube/config"

        # Create a backup of the existing kubeconfig file
        if [ -f "$DEFAULT_KUBECONFIG" ]; then
            cp "$DEFAULT_KUBECONFIG" "$DEFAULT_KUBECONFIG.bak"
            echo "Backup of existing kubeconfig created at $DEFAULT_KUBECONFIG.bak"
        fi

        # Find all kubeconfig files matching *.kubeconfig.yml in ~/.kube/
        KUBECONFIG_FILES=$(find "$HOME/.kube" -type f -name "*.kubeconfig.yml")

        # Check if there are any files to merge
        if [ -z "$KUBECONFIG_FILES" ]; then
            echo "No *.kubeconfig.yml files found in $HOME/.kube/"
            exit 1
        fi

        # Merge all kubeconfig files into the default kubeconfig
        # KUBECONFIG=$(echo "$KUBECONFIG_FILES" | tr '\n' ':')
        export KUBECONFIG=$(echo "$KUBECONFIG_FILES" | tr '\n' ':')
        kubectl config view --merge --flatten > "$DEFAULT_KUBECONFIG.tmp"

        # Replace the default kubeconfig with the merged file
        mv "$DEFAULT_KUBECONFIG.tmp" "$DEFAULT_KUBECONFIG"
        find $(realpath ~/.kube) -name "*.kubeconfig.yml" -exec chmod 600 {} + && chmod 600 $(realpath ~/.kube)/config
        echo "Merged kubeconfig files into $DEFAULT_KUBECONFIG"

        # Verify the merge
        kubectl config get-contexts
      }

      patch_init_tf_file() { 
        # Install CRDs required by Cilium Gateway API support (required CRDs before Cilium installation) https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/ 
        #     IMPORTANT: Cilium Gateway API controller must be installed BEFORE Cilium installation, otherwise even a restart won't work
        #!/bin/bash
        INIT_TF_PATH=".terraform/modules/kube-hetzner/init.tf"
        # NOTE: contents of match file should be synchronized with the script that is used for minikube to keep development and production environment in sync 'install_gateway_api_crds'
        PATCH_FILE="init.tf.patch"

        # Check if files exist
        if [[ ! -f "$INIT_TF_PATH" ]]; then
            echo "Error: $INIT_TF_PATH does not exist."
            return
        fi

        if [[ ! -f "$PATCH_FILE" ]]; then
            echo "Error: $PATCH_FILE does not exist."
            return
        fi

        # Verify the target line exists in the file
        if ! grep -q 'kubectl apply -k /var/post_install' "$INIT_TF_PATH"; then
            echo "Error: Target line 'kubectl apply -k /var/post_install' not found in $INIT_TF_PATH."
            return
        fi

        # Read the patch content
        PATCH_CONTENT=$(cat "$PATCH_FILE")

        INDENT="        "  # Use 8 spaces for indentation
        PATCH_CONTENT=$(sed "s/^/$INDENT/" "$PATCH_FILE")  # Add indentation to each line in the patch file

        # Read each line from the patch file
        while IFS= read -r line; do sed -i.bak "/kubectl apply -k \/var\/post_install/i\\\t\t\t\t$line" "$INIT_TF_PATH"; done < "$PATCH_FILE"
        echo "Patch applied successfully. A backup of the original file is saved as ${INIT_TF_PATH}.bak."
      }

      hcloud context create "k8s-project"

      ### [manual] set variables using "terraform.tfvars" or CLI argument or equivalent env variables (with `TF_TOKEN_*` prefix)
      find . -name "*.tfvars"
      set -a && source ".env" && set +a # export TF_TOKEN_app_terraform_io="" 

      export TF_LOG=DEBUG
      terraform init --upgrade # installed terraform module dependecies
      terraform validate

      patch_init_tf_file
      t_plan="$(mktemp).tfplan" && terraform plan -no-color -out $t_plan
      terraform apply -auto-approve $t_plan

      generate_kubeconfig
      
      kubectl ctx k3s

      remove_warnings_logs
      sleep 1 
      install_kubernetes_dashboard  
      install_gateway_api_cilium  # [previous implementation] # installation_gateway_controller_nginx 
      cert_manager_related  # must be restarted after installation of Gateway Api
      sleep 30
      install_storage_class 
      # TODO: check resource limits and prevent contention when using monitoring tools
      # install_monitoring
      install_envoy_gateway_class


      verify_installation() {
        k9s # https://k9scli.io/topics/commands/
        kubectl get all -A 
        kubectl --kubeconfig $kubeconfig get all -A 
        kubectl get configmap -A
        kubectl get secrets -A
        kubectl api-resources
        kubectl api-versions
        kubectl get gatewayclasses
        hcloud all list
        terraform show
        terraform state list
        terraform state show type_of_resource.label_of_resource

        helm list -A --all-namespaces 
        helm get values --all nginx -n nginx 
        helm get manifest nginx -n nginx 
        
        journalctl -r -n 200

        # load balancer hetzner manager (Hetzner Cloud Controller Manager (CCM))
        kubectl logs -n kube-system -l app=hcloud-cloud-controller-manager

        # check cpu/mem utilization
        kubectl get node && kubectl top nodes && kubectl describe node
        kubectl get pods -o wide -A 
        kubectl get pods -n longhorn-system -l app.kubernetes.io/name=longhorn -o wide 
          # NOTE: memory reporting it seems because of cilium is not reported correctly. (discrepancies found between linux command reported memory and kubectl command one)
        kubectl top pods --containers=true -A --sort-by memory
        kubectl get pods -o wide --all-namespaces | grep k3s-control-plane-wug
        HIGHEST_CPU_NODE=$(kubectl top nodes | awk 'NR>1 {print $1, $2+0}' | sort -k2 -nr | head -n 1 | awk '{print $1}')
        kubectl top pods -A -n $HIGHEST_CPU_NODE --sort-by cpu
        # list all pods of controller nodes: 
        {
          for node in $(kubectl get nodes -l role=control-plane -o jsonpath='{.items[*].metadata.name}'); do
            echo "Pods on node: $node"
            kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=$node
          done
        }

        hcloud server list
        {
          free | awk '/Mem:/ {printf "Memory Usage: %.2f%%\n", $3/$2 * 100}'
        }

        ### ssh into remove machines
        # echo "" > ~/.ssh/known_hosts # clear known hosts to permit connection for same assigned IP to different server
        ip_address=$(hcloud server list --output json | jq -r '.[0].public_net.ipv4.ip')
        ssh -p 2220 root@$ip_address
        ip_address=$(hcloud server list --output json | jq -r '.[0].public_net.ipv6.ip' | sed 's/\/.*/1/')
        ssh -p 2220 root@$ip_address 
      }

      popd
    }
}

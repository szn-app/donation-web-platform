#!/bin/bash

install_gateway_api_cilium() { 
 


  restart_cilinium() { 
    kubectl -n kube-system rollout restart deployment/cilium-operator
    kubectl -n kube-system rollout restart ds/cilium
  }

  restart_cilinium

  verify() { 
    kubectl get crd -A
    cilium status
    cilium config view | grep -w "gateway"
    cilium sysdump

    # verify tls setup
    {
      kubectl get configmap -n kube-system cilium-config -o yaml | grep hubble-disable-tls
      kubectl apply -n kube-system -f https://raw.githubusercontent.com/cilium/cilium/main/examples/hubble/hubble-cli.yaml
      # https://docs.cilium.io/en/stable/observability/hubble/configuration/tls/
      # ... 
    }

  }
}

# Gateway controller instlalation - https://gateway-api.sigs.k8s.io/implementations/ & https://docs.nginx.com/nginx-gateway-fabric/installation/ 
# This controller could be used in place of the Cilium Gateway API controller 
installation_gateway_controller_nginx() {
  delete() { 
    kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml   

    kubectl delete -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v1.5.1/deploy/crds.yaml
    kubectl delete -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v1.5.1/deploy/default/deploy.yaml
  }

  # Gateway API CRD installation - https://gateway-api.sigs.k8s.io/guides/#installing-a-gateway-controller
  kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml   

  kubectl apply -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v1.5.1/deploy/crds.yaml
  kubectl apply -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v1.5.1/deploy/default/deploy.yaml
  kubectl get pods -n nginx-gateway
}

install_storage_class() { 
 

  printf "Installing Longhorn storage class...\n"

  kubectl get storageclasses.storage.k8s.io

  annotate_nodes() {
    printf "Annotating nodes for Longhorn storage class...\n"

    # add storage config through annotation (creating Longhorn 'disks')
    # check storageReserve ratio values https://gist.github.com/ifeulner/d311b2868f6c00e649f33a72166c2e5b 
    # /var/lib/longhorn => instruct longhorn to create default 'disk' in path (customized in terraform file)
    # /mnt/longhorn => # network storage mount point (default from kube-hetzner module)
    # 25% of 40 GB local storage ~= 2^30 * 10 (NOTE: Hetzner GiB or GB ?) 
    # 10% of 10GB ~= 2^30 * 1 attached dedicated hcloud volumes
    {
      config=$(cat <<EOT
[
  {
    "name": "longhorn-local-storage",
    "path": "/var/lib/longhorn",
    "allowScheduling": true,
    "storageReserved": 10737418240,
    "tags": [ "local-storage-disk" ]
  },
  {
    "name": "hcloud-volume-mounted",
    "path": "/var/longhorn",
    "allowScheduling": true,
    "storageReserved": 1073741824,
    "tags": [ "network-storage-volume" ]
  }
]
EOT
)

    agent_node_names=($(kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels["node-role.kubernetes.io/control-plane"] | not) | .metadata.name'))
    for node_name in "${agent_node_names[@]}"; do
      echo "annotating node $node_name" 
      kubectl annotate node "$node_name" "node.longhorn.io/default-disks-config=$config" --overwrite   
    done 

    sleep 10

    config=$(cat <<EOT
[
  {
    "name": "longhorn-local-storage",
    "path": "/var/lib/longhorn",
    "allowScheduling": true,
    "storageReserved": 10737418240,
    "tags": [ "local-storage-disk" ]
  }
]
EOT
)

      control_node_names=($(kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels["node-role.kubernetes.io/control-plane"] ) | .metadata.name'))
      for node_name in "${control_node_names[@]}"; do
        echo "annotating node $node_name" 
        kubectl annotate node "$node_name" "node.longhorn.io/default-disks-config=$config" --overwrite   
      done 

    }

    sleep 25

    # Longhorn add tags (longhorn tag) for workers from the Kubernetes labels (synchronize K8s labels to Longhorn tags)
    # NOTE: this tags only nodes that can run pods (if control node is not set to run workloads it will print error message)
    {
      NAMESPACE="longhorn-system" # Namespace for Longhorn
      LABEL_KEY="role" # Label key to match in Kubernetes nodes

      # Iterate through nodes and apply tags
      for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
        # Get the value of the label
        LABEL_VALUE=$(kubectl get node $node -o jsonpath="{.metadata.labels['$LABEL_KEY']}")

        if [ -n "$LABEL_VALUE" ]; then
          echo "Applying Longhorn tag '$LABEL_VALUE' to node '$node'"

          # Patch the Longhorn node with the label value as a tag (this uses a longhorn specific approach)
          printf "kubectl -n $NAMESPACE patch nodes.longhorn.io $node --type='merge' -p \"{\"spec\":{\"tags\":[\"$LABEL_VALUE\"]}}\" \n"
          kubectl -n "$NAMESPACE" patch nodes.longhorn.io "$node" --type='merge' -p "{\"spec\":{\"tags\":[\"$LABEL_VALUE\"]}}"
        else
          echo "Node '$node' does not have label '$LABEL_KEY', skipping."
        fi
      done  
    }

  }

  ###
  define_storage_classes() {
    # storage classes definitions
    t="$(mktemp).yaml" && cat <<-EOF > "$t" # must be .yaml to pass validation
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: longhorn-network-storage
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
parameters:
  numberOfReplicas: "2"
  staleReplicaTimeout: "2880"
  fromBackup: ""
  fsType: "ext4"
  dataLocality: "best-effort"
  diskSelector: "network-storage-volume"
  nodeSelector: "worker" # where Longhorn node tag (internal Longhorn info) is set to worker (as volumes only mounted on agents)
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: longhorn-network-storage-1replica
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
parameters:
  numberOfReplicas: "1"
  staleReplicaTimeout: "2880"
  fromBackup: ""
  fsType: "ext4"
  dataLocality: "best-effort"
  diskSelector: "network-storage-volume"
  nodeSelector: "worker" # where Longhorn node tag (internal Longhorn info) is set to worker (as volumes only mounted on agents)
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: longhorn-local-ext4
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
parameters:
  numberOfReplicas: "3"
  staleReplicaTimeout: "2880" # 48 hours in minutes
  fromBackup: ""
  fsType: "ext4"
  dataLocality: "best-effort"
  diskSelector: "local-storage-disk"
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: longhorn-local-ext4-2replica
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
parameters:
  numberOfReplicas: "2"
  staleReplicaTimeout: "2880" # 48 hours in minutes
  fromBackup: ""
  fsType: "ext4"
  dataLocality: "best-effort"
  diskSelector: "local-storage-disk"
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: longhorn-local-xfs
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
parameters:
  numberOfReplicas: "3"
  staleReplicaTimeout: "2880" # 48 hours in minutes
  fromBackup: ""
  fsType: "xfs"
  dataLocality: "best-effort"
  diskSelector: "local-storage-disk"
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: longhorn-local-ext4-strict-locality
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
parameters:
  numberOfReplicas: "1"
  staleReplicaTimeout: "2880" # 48 hours in minutes
  fromBackup: ""
  fsType: "ext4"
  dataLocality: "strict-local"
  diskSelector: "local-storage-disk"
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: longhorn-local-ext4-disabled-locality
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: Immediate
parameters:
  numberOfReplicas: "3"
  staleReplicaTimeout: "2880" # 48 hours in minutes
  fromBackup: ""
  fsType: "ext4"
  dataLocality: "disabled"
  diskSelector: "local-storage-disk"
EOF
   
    kubectl apply -f $t
  }

  annotate_nodes
  sleep 10
  define_storage_classes

  # [manually] verify that cloud volumes are attached to each nodes at /mnt/longhorn and check longhorn disk in /var/lib/longhorn
  verify_mount_inside_server() {
    kubectl get storageclasses.storage.k8s.io

    lsblk 
    mount | grep longhorn
    df -h
    du -sh /var/lib/longhorn # disk usage

    # for debugging purposes if persistent volumes are not being created
    kubectl logs -n longhorn-system -l app=longhorn-manager
    kubectl get events -n longhorn-system
    kubectl get sc
    kubectl get pv -o yaml
    kubectl get pvc

    # check nodes as registered by Longhorn and which tags Longhorn internally sees for each of the nodes
    kubectl -n longhorn-system get nodes.longhorn.io
    node_name="" 
    kubectl -n longhorn-system get nodes.longhorn.io $node_name -o yaml

    # expose longhorn UI dashboard (create tunnel) 
    kubectl port-forward -n longhorn-system service/longhorn-frontend 8082:80
  }
}

# https://github.com/kubernetes/dashboard
install_kubernetes_dashboard() {
 

  printf "Installing Kubernetes Dashboard...\n"

  helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
  t="$(mktemp)-values.yml" && cat <<EOF > "$t" 
app: 
  scheduling: 
    nodeSelector:
      role: worker
kong:
  proxy:
    http:
      enabled: true
  nodeSelector: 
    role: worker

auth: 
  nodeSelector: 
    role: worker

api: 
  nodeSelector: 
    role: worker

web: 
  nodeSelector: 
    role: worker

metricsScraper: 
  nodeSelector: 
    role: worker
EOF
  helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard --values $t

  # https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md
  t=$(mktemp) && cat <<EOF > "$t" 
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard

---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard

---

apiVersion: v1
kind: Secret
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: "admin-user"   
type: kubernetes.io/service-account-token  
EOF
  kubectl apply -f $t 

  verify_dashboard() { 
    # verify helm custom values 
    helm show values kubernetes-dashboard/kubernetes-dashboard
    # helm uninstall kubernetes-dashboard   --namespace kubernetes-dashboard

      t="$(mktemp)-values.yml" && cat <<EOF > "$t" 
kong:
  proxy:
    http:
      enabled: true
EOF
    y="$(mktemp).yml" && helm template kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --namespace kubernetes-dashboard --values $t > $y && code $y

    # get token 
    export USER_TOKEN=$(kubectl get secret admin-user -n kubernetes-dashboard -o jsonpath="{.data.token}" | base64 -d)
    echo $USER_TOKEN

    kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard-kong-proxy 8081:443
  }
}

### cert-manager installation is done through kube-hetzner module
cert_manager_related() { 
  restart_cert_manager() { 
    

    printf "Restarting cert-manager...\n"

    # verify installation https://cert-manager.io/docs/installation/kubectl/#verify
    verify_cert_manager_installation() {
        t=$(mktemp) && cat <<EOF > "$t"
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager-test
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: test-selfsigned
  namespace: cert-manager-test
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: selfsigned-cert
  namespace: cert-manager-test
spec:
  dnsNames:
    - example.com
  secretName: selfsigned-cert-tls
  issuerRef:
    name: test-selfsigned
EOF
        kubectl apply -f $t 
        sleep 2
        while ! $(kubectl describe certificate -n cert-manager-test | grep "Status" | awk '{print $2}' | grep -i -q "true"); do
          echo "Retry checking for successfully issued certificate. sleep 5s..."; 
          sleep 5
        done
        
        kubectl delete -f $t
    }
    
    sleep 10
    verify_cert_manager_installation
    kubectl rollout restart deployment cert-manager -n cert-manager
    
  }

  # used for cert-manager challenge routes to always return 200 (hackish way to overcome limitations in Gateway API configuration) 
  # allows to probe with $`curl -i cert-manager-health-endpoint.cert-manager/livez`
  expose_status_endpoint() { 
    t=$(mktemp) && cat <<"EOF" > "$t"
apiVersion: v1
kind: Service
metadata:
  name: cert-manager-health-endpoint
  namespace: cert-manager
spec:
  selector:
    app: cert-manager 
  ports:
  # expose port named http-healthz (9403)
  - protocol: TCP
    port: 80
    targetPort: http-healthz 
EOF

    kubectl apply -f $t
  }

  expose_status_endpoint
  restart_cert_manager
}

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

# TODO: solve issue of high resource utilization by Prometheus
install_monitoring() {
  # https://artifacthub.io/packages/helm/prometheus-community/prometheus
  install_prometheus() { 
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update

    t="$(mktemp)-prometheus-values.yml" && cat <<EOF > "$t"
server:
  persistentVolume:
    storageClass: local-path
    size: 3Gi
  nodeSelector: 
    role: worker

alertmanager:
  persistentVolume:
    size: 512Mi
    
resources:
    limits:
      cpu: 150m
      memory: 512Mi
    requests:
      cpu: 80m
      memory: 256Mi
EOF

    helm upgrade prometheus --install prometheus-community/prometheus --namespace monitoring --create-namespace -f $t

    # https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus/values.yaml
    t="$(mktemp)-monitoring-configuration.yml" && cat <<EOF > "$t"
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kube-state-metrics
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: kube-state-metrics
  endpoints:
  - port: http-metrics
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
EOF

  }

  # https://artifacthub.io/packages/helm/grafana/grafana
  install_grafana() { 
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update

    # https://github.com/grafana/helm-charts/blob/main/charts/grafana/values.yaml
    t="$(mktemp)-grafana-values.yml" && cat <<EOF > "$t"
nodeSelector: 
  role: worker
persistence:
  enabled: true
  storageClassName: local-path
  size: 1Gi
service:
  type: ClusterIP
resources:
  limits:
    cpu: 80m
    memory: 200Mi
  requests:
    cpu: 40m
    memory: 128Mi

EOF

    helm upgrade grafana --install grafana/grafana --namespace monitoring --create-namespace -f $t

  }

  manual_steps() { 
    # TODO: install Grafana extension for Prometheus from the graphical interface and implement recommendations from docs
    echo ""
  }

  install_prometheus
  install_grafana

  verify() {
    kubectl get pods -l app=prometheus

    # get grafana password 
    kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
  }

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

#!/bin/bash

install_gateway_api() { 
    [ -z "$1" ] && { echo "Error: No arguments provided."; exit 1; } || kubeconfig="$1" 

    # Gateway API CRD installation - https://gateway-api.sigs.k8s.io/guides/#installing-a-gateway-controller
    kubectl apply --kubeconfig $kubeconfig -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml   

    # Gateway controller instlalation - https://gateway-api.sigs.k8s.io/implementations/ & https://docs.nginx.com/nginx-gateway-fabric/installation/ 
    kubectl apply --kubeconfig $kubeconfig -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v1.5.1/deploy/crds.yaml
    kubectl apply --kubeconfig $kubeconfig -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v1.5.1/deploy/default/deploy.yaml
    kubectl --kubeconfig $kubeconfig get pods -n nginx-gateway
}

install_storage_class() { 
  [ -z "$1" ] && { echo "Error: No arguments provided."; exit 1; } || kubeconfig="$1" 

  kubectl --kubeconfig $kubeconfig get storageclasses.storage.k8s.io


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

  agent_node_names=($(kubectl --kubeconfig "$kubeconfig" get nodes -o json | jq -r '.items[] | select(.metadata.labels["node-role.kubernetes.io/control-plane"] | not) | .metadata.name'))
  for node_name in "${agent_node_names[@]}"; do
    echo "annotating node $node_name" 
    kubectl --kubeconfig "$kubeconfig" annotate node "$node_name" "node.longhorn.io/default-disks-config=$config" --overwrite   
  done 

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

    control_node_names=($(kubectl --kubeconfig "$kubeconfig" get nodes -o json | jq -r '.items[] | select(.metadata.labels["node-role.kubernetes.io/control-plane"] ) | .metadata.name'))
    for node_name in "${control_node_names[@]}"; do
      echo "annotating node $node_name" 
      kubectl --kubeconfig "$kubeconfig" annotate node "$node_name" "node.longhorn.io/default-disks-config=$config" --overwrite   
    done 

  }

  # Longhorn add tags for workers from the Kubernetes labels (synchronize K8s labels to Longhorn tags)
  {
    NAMESPACE="longhorn-system" # Namespace for Longhorn
    LABEL_KEY="role" # Label key to match in Kubernetes nodes

    # Iterate through nodes and apply tags
    for node in $(kubectl --kubeconfig $kubeconfig get nodes -o jsonpath='{.items[*].metadata.name}'); do
      # Get the value of the label
      LABEL_VALUE=$(kubectl --kubeconfig $kubeconfig get node $node -o jsonpath="{.metadata.labels['$LABEL_KEY']}")

      if [ -n "$LABEL_VALUE" ]; then
        echo "Applying Longhorn tag '$LABEL_VALUE' to node '$node'"

        # Patch the Longhorn node with the label value as a tag
        kubectl --kubeconfig $kubeconfig -n $NAMESPACE patch nodes.longhorn.io $node --type='merge' -p "{\"spec\":{\"tags\":[\"$LABEL_VALUE\"]}}"
      else
        echo "Node '$node' does not have label '$LABEL_KEY', skipping."
      fi
    done  
  }

  ###
  
  # storage classes definitions
  t="$(mktemp).yaml" && cat <<-EOF > "$t"
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: longhorn-network-storage
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
parameters:
  numberOfReplicas: "3"
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
   
  kubectl --kubeconfig $kubeconfig apply -f $t

  # [manually] verify that cloud volumes are attached to each nodes at /mnt/longhorn and check longhorn disk in /var/lib/longhorn
  verify_mount_inside_server() {
    kubectl --kubeconfig $kubeconfig get storageclasses.storage.k8s.io

    lsblk 
    mount | grep longhorn
    df -h
    du -sh /var/lib/longhorn # disk usage

    # for debugging purposes if persistent volumes are not being created
    kubectl --kubeconfig "$kubeconfig" logs -n longhorn-system -l app=longhorn-manager
    kubectl --kubeconfig "$kubeconfig" get events -n longhorn-system
    kubectl --kubeconfig "$kubeconfig" get sc
    kubectl --kubeconfig "$kubeconfig" get pv -o yaml
    kubectl --kubeconfig "$kubeconfig" get pvc

    # check nodes as registered by Longhorn and which tags Longhorn internally sees for each of the nodes
    kubectl --kubeconfig "$kubeconfig" -n longhorn-system get nodes.longhorn.io
    node_name="" 
    kubectl --kubeconfig "$kubeconfig" -n longhorn-system get nodes.longhorn.io $node_name -o yaml

    # expose longhorn UI dashboard 
    kubectl --kubeconfig "$kubeconfig" port-forward -n longhorn-system service/longhorn-frontend 8082:80
  }
}

# https://github.com/kubernetes/dashboard
install_kubernetes_dashboard() {
  [ -z "$1" ] && { echo "Error: No arguments provided."; exit 1; } || kubeconfig="$1" 

  helm --kubeconfig $kubeconfig repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
  helm --kubeconfig $kubeconfig upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard

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
  kubectl --kubeconfig $kubeconfig apply -f $t 

  verify_dashboard() { 
    # get token 
    export USER_TOKEN=$(kubectl --kubeconfig "$kubeconfig" get secret admin-user -n kubernetes-dashboard -o jsonpath="{.data.token}" | base64 -d)
    echo $USER_TOKEN

    kubectl --kubeconfig "$kubeconfig" port-forward -n kubernetes-dashboard service/kubernetes-dashboard-kong-proxy 8081:443
  }
}

install_cert_manager() { 
    [ -z "$1" ] && { echo "Error: No arguments provided."; exit 1; } || kubeconfig="$1" 

    # https://cert-manager.io/docs/installation/helm/
    helm --kubeconfig $kubeconfig repo add jetstack https://charts.jetstack.io --force-update
    helm --kubeconfig $kubeconfig install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.16.2 --set crds.enabled=true \
        --set config.apiVersion="controller.config.cert-manager.io/v1alpha1" \
        --set config.kind="ControllerConfiguration" \
        --set config.enableGatewayAPI=true

    # verify installation https://cert-manager.io/docs/installation/kubectl/#verify
    {
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
            
        kubectl --kubeconfig $kubeconfig apply -f $t 
        while ! kubectl --kubeconfig $kubeconfig describe certificate -n cert-manager-test | grep "Status" | awk '{print $2}' | grep -i -q "true"; do
          echo "Retry checking for successfully issued certificate. sleep 5s..."; 
          sleep 5
        done
        
        kubectl --kubeconfig $kubeconfig delete -f $t
    }

  kubectl --kubeconfig $kubeconfig rollout restart deployment cert-manager -n cert-manager
}

# https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner
hetzner() { 
    hcloud version && kubectl version && packer --version
    tofu --version && terraform version # either tools should work
    helm version

    # TODO: automate
    # [manual, then move to ~/.ssh] 
    # will also be used to log into the machines using ssh
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

        export TF_LOG=DEBUG
        export TF_TOKEN_app_terraform_io=""  
        terraform init --upgrade # installed terraform module dependecies
        terraform validate

        terraform plan -no-color -out kube.tfplan > output_plan.txt.tmp
        terraform apply kube.tfplan # terraform destroy # when completely redploying
        
        # create kubeconfig (NOTE: do not version control this credentials file)
        export kubeconfig="$(realpath ~/.ssh)/kubernetes-project-credentials.kubeconfig.yaml"
        t=$(mktemp) && terraform output --raw kubeconfig > "$t" && mv $t $kubeconfig && chmod 600 "$kubeconfig"

        install_kubernetes_dashboard  "$kubeconfig"
        install_gateway_api "$kubeconfig"
        install_cert_manager "$kubeconfig"
        install_storage_class "$kubeconfig"

        verify_installation() {
          kubectl --kubeconfig $kubeconfig get all -A 
          kubectl --kubeconfig $kubeconfig get configmap -A
          kubectl --kubeconfig $kubeconfig api-resources
          kubectl --kubeconfig $kubeconfig api-versions
          hcloud all list
          terraform show
          terraform state list
          terraform state show type_of_resource.label_of_resource

          helm list -A --all-namespaces --kubeconfig $kubeconfig
          helm get values --all nginx -n nginx --kubeconfig $kubeconfig
          helm get manifest nginx -n nginx --kubeconfig $kubeconfig
          
          journalctl -r -n 200

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

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

minikube_mock_storage_classes() {
    t="$(mktemp).yaml" && cat <<-EOF > "$t" # must be .yaml to pass validation
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-network-storage
provisioner: k8s.io/minikube-hostpath
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-network-storage-1replica
provisioner: k8s.io/minikube-hostpath
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-local-ext4
provisioner: k8s.io/minikube-hostpath
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-local-ext4-2replica
provisioner: k8s.io/minikube-hostpath
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-local-xfs
provisioner: k8s.io/minikube-hostpath
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-local-ext4-strict-locality
provisioner: k8s.io/minikube-hostpath
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-local-ext4-disabled-locality
provisioner: k8s.io/minikube-hostpath
EOF

  kubectl apply -f $t
}
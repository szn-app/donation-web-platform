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

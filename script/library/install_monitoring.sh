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

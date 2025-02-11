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
    cilium config view | grep -w "enabe-gateway-api"
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

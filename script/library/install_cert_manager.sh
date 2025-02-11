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


# NOTE: version should match the installation of cert-manager through terraform kube-hetzner equivalent module
minikube_install_cert_manager() {
  helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.15.3 -f ./infrastructure/helm_values/cert-manager-values.yml --set nodeSelector=null
} 
# installs an Envoy gateway class internal to the cluster (not exposed externally)
# https://gateway.envoyproxy.io/docs/install/install-helm/
install_envoy_gateway_class() {
    pushd ./manifest/envoy_proxy
    
    action=${1:-"install"}
    {
        if [ "$action" == "delete" ]; then
            # permit forceful deletion of gatewayclass
            kubectl delete envoyproxy envoy-proxy-config-internal -n envoy-gateway-system # --force
            kubectl patch gatewayclass envoy-internal -n envoy-gateway-system -p '{"metadata":{"finalizers":[]}}' --type=merge 
            kubectl delete gatewayclass envoy-internal -n envoy-gateway-system # --force
            helm delete envoy-gateway -n envoy-gateway-system
            return 
        fi
    }

    install_gateway_class() {
        # install CRDs (NOTE: Helm doesn't update CRDs already installed - manual upgrade would be required)
        # https://gateway.envoyproxy.io/docs/tasks/traffic/gatewayapi-support/
        helm upgrade --install envoy-gateway oci://docker.io/envoyproxy/gateway-helm --version v1.2.6 -n envoy-gateway-system --create-namespace -f ./helm-values.yml
        kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available    

        t="$(mktemp).yml" && cat << 'EOF' > $t
# customize EnvoyProxy CRD https://gateway.envoyproxy.io/docs/api/extension_types/
# This configurations creates a service as ClusterIP preventing assigning external IP address to it
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: envoy-proxy-config-internal
  namespace: envoy-gateway-system
spec:
  provider:
    type: Kubernetes
    kubernetes:
      envoyService:
        # additional config from kube-hetzner module's loadbalancer controller
        annotations:
            load-balancer.hetzner.cloud/disable: "true"
        # Use ClusterIP instead of LoadBalancer (making the gateway internal only)
        type: ClusterIP
        # set fixed name to refernce it in manifest yml files
        name: envoy-gateway-internal
---
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy-internal
  namespace: envoy-gateway-system
spec:
    controllerName: gateway.envoyproxy.io/gatewayclass-controller-internal
    parametersRef:
        group: gateway.envoyproxy.io
        kind: EnvoyProxy
        name: envoy-proxy-config-internal
        namespace: envoy-gateway-system
EOF

        kubectl apply -f $t -n envoy-gateway-system

        verify() { 
            # check schema
            kubectl get crd envoyproxies.config.gateway.envoyproxy.io -o yaml
            kubectl explain envoyproxy.spec.provider.kubernetes
        }
    }

    install_gateway_class

    verify() {
        helm status envoy-gateway -n envoy-gateway-system
        y="$(mktemp).yml" && helm get all envoy-gateway -n envoy-gateway-system > $y && printf "rendered manifest template: file://$y\n"  # code -n $y


        {
            t="$(mktemp).sh" && cat << 'EOF' > $t
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: envoy-gateway
spec:
  gatewayClassName: envoy
  listeners:
    - name: http
      protocol: HTTP
      port: 80
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  labels:
    app: backend
    service: backend
spec:
  ports:
    - name: http
      port: 3000
      targetPort: 3000
  selector:
    app: backend
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
      version: v1
  template:
    metadata:
      labels:
        app: backend
        version: v1
    spec:
      serviceAccountName: backend
      containers:
        - image: gcr.io/k8s-staging-gateway-api/echo-basic:v20231214-v1.0.0-140-gf544a46e
          imagePullPolicy: IfNotPresent
          name: backend
          ports:
            - containerPort: 3000
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: backend
spec:
  parentRefs:
    - name: envoy-gateway
  hostnames:
    - "www.example.com"
  rules:
    - backendRefs:
        - group: ""
          kind: Service
          name: backend
          port: 3000
          weight: 1
      matches:
        - path:
            type: PathPrefix
            value: /

EOF
            kubectl apply -f $t -n envoy-gateway-system

            export GATEWAY_HOST=$(kubectl get gateway/envoy-gateway -n envoy-gateway-system -o jsonpath='{.status.addresses[0].value}')
            curl --verbose --header "Host: www.example.com" http://$GATEWAY_HOST/get

            kubectl delete -f $t -n envoy-gateway-system --ignore-not-found=true
        }
    }
    popd
}
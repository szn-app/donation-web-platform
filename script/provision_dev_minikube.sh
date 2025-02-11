#!/bin/bash

# add hosts DNS resolution in Fedora: resolve *.test to $(minikube ip)
install_domain_dns_systemd_resolved_for_test_domains() {
# add minikube dns to linux as a dns server https://minikube.sigs.k8s.io/docs/handbook/addons/ingress-dns/#Linux
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/minikube.conf << EOF
[Resolve]
DNS=$(minikube ip)
Domains=test
EOF
sudo systemctl restart systemd-resolved
}

bootstrap_minikube() {
    action=${1:-"install"}

    if ! command -v kubectl-ctx &> /dev/null; then
        echo "kubectl ctx is not installed. Exiting."
        return
    fi

    if [ "$action" == "delete" ]; then
        minikube delete
        return 
    fi

    docker context ls
    docker context use default
    
    minikube config set driver docker
    fix_issue_docker() {
        # fix issue with docker cli plugins where symlinks are corrupted and invalid
        rm ~/.docker/cli-plugins/*
    }
    minikube start --driver=docker
    kubectl ctx minikube
    kubectl config get-contexts

    {
        minikube addons enable metrics-server
        minikube addons enable dashboard
        launch_dashboard_proxy() {
            # lanch minikube dashboard proxy
            minikube dashboard --url &
        }
    }
    {
        # Ingress k8s resource controllers
        minikube addons enable ingress # NGINX Ingress controller
        minikube addons enable ingress-dns 

        source "./script/library/installation_gateway_controller_nginx.sh"
        installation_gateway_controller_nginx

        kubectl get pods -n ingress-nginx # verify Ingress controller running
    }
    {
        source "./script/library/install_envoy_gateway_class.sh"
        install_envoy_gateway_class
    }
    {
        source "./script/library/install_cert_manager.sh"
        minikube_install_cert_manager
        cert_manager_related
    }

    {
        source "./script/library/hetzner/install_storage_class.sh"
        minikube_mock_storage_classes
    }    

    install_domain_dns_systemd_resolved_for_test_domains
    # NOTE: careful of minikube dns caching and limitations, if dns name is not resolved after a change, an entire restart of minikube and probably disable/enable addons is required. 

    verify() { 
        minikube kubectl -- get po -A # for a separate version kubectl install
        # or 
        kubetcl ctx minikube
        kubectl cluster-info 
        kubectl get nodes
    }

}


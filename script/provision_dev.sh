#!/bin/bash

misc_provision_dev() { 
    # clone with submodules
    git clone --recursive https://github.com/szn-app/donation-app
}

git_submodule() {
    onetime_intialization() {
        git submodule add https://github.com/szn-app/fork-kratos-selfservice-ui-node.git service/auth-ui/kratos-selfservice-ui-node
    }

    example_remove() { 
        git submodule deinit -f service/auth-ui/kratos-selfservice-ui-node
        git rm --cached service/auth-ui/kratos-selfservice-ui-node
        rm -r .git/modules
        # [manual] remove section from .git/config
    }

    git submodule init && git submodule update
}

record_version() { 
    NODE_VERSION=$(node -v | cut -d 'v' -f2)
    PNPM_VERSION=$(pnpm --version | cut -d ' ' -f2)
    RUST_VERSION=$(rustc --version | awk '{print $2}') 
    CARGO_VERSION=$(cargo --version | awk '{print $2}')
    DOCKER_VERSION=$(docker version --format '{{.Server.Version}}')
    MINIKUBE_VERSION=$(/usr/bin/minikube version --short)  
    KUBERNETES_VERSION=$(kubectl version | awk '{printf "\t%s:\t%s\n", $1" "$2, $3}')
    KUSTOMIZE_VERSION=$(kustomize version)
    KOPS_VERSION=$(kops version --short)

    echo "Node.js version: ${NODE_VERSION}" > version.txt
    echo "pnpm version: ${PNPM_VERSION}" >> version.txt
    echo "Rust version: ${RUST_VERSION}" >> version.txt
    echo "Cargo version: ${CARGO_VERSION}" >> version.txt
    echo "Docker version: ${DOCKER_VERSION}" >> version.txt
    echo "Minikube version: ${MINIKUBE_VERSION}" >> version.txt
    printf "Kubernetes version: \n%s\n" "$KUBERNETES_VERSION" >> version.txt
    echo "Kustomize version: ${KUSTOMIZE_VERSION}" >> version.txt
    echo "kOps version: ${KOPS_VERSION}" >> version.txt

    cat ./version.txt
}

provision_tauri() {
    if [[ $OSTYPE == 'linux-gnu' && -f /etc/redhat-release ]]; then 
        sudo dnf install lsb_release -y
    fi

    if [[ $(uname -s) == "Linux" ]]; then
        distro=$(lsb_release -is)
        version=$(lsb_release -rs)

        echo "Detected distribution: $distro"
        echo "Detected version: $version"

        if [[ "$distro" == "Fedora" ]]; then
            install_tauri_dependencies_fedora
        elif [[ "$distro" == "Debian" ]]; then
            install_tauri_dependencies_debian
        else
            echo "Error: unsupported Linux distribution detected"
            exit 1
        fi
    else
        echo "Error: this script is only supported on Linux systems"
        exit 1
    fi

    cargo install create-tauri-app --locked 
    cargo install tauri-cli --locked

    echo "create-tauri-app $(cargo create-tauri-app --version)"
    echo "cargo-tauri $(cargo tauri --version)"
}

## https://v2.tauri.app/start/prerequisites/#linux
## IMPORTANT! script is used in ./github/workflows/*
install_tauri_dependencies_debian() {
    sudo apt update
    sudo apt install libwebkit2gtk-4.1-dev \
        build-essential \
        curl \
        wget \
        file \
        libxdo-dev \
        libssl-dev \
        libgtk-3-dev \
        libayatana-appindicator3-dev \
        librsvg2-dev
}

install_tauri_dependencies_fedora() {
    sudo dnf check-update
    sudo dnf install webkit2gtk4.0-devel \
        openssl-devel \
        curl \
        wget \
        file \
        libappindicator-gtk3-devel \
        librsvg2-devel
    sudo dnf group install "C Development Tools and Libraries"
}

setup_android_sdk_variables() { 
    export JAVA_HOME=/usr/local/android-studio/jbr
    export ANDROID_HOME="$HOME/Android/Sdk"
    export NDK_HOME="$ANDROID_HOME/ndk/$(ls -1 $ANDROID_HOME/ndk)"
}

### TODO: this is temporary nodes check if it works 
android_studio_for_Tauri() { 
	sudo yum install zlib.i686 ncurses-libs.i686 bzip2-libs.i686
	
	## [manual] download and install androind studio rpm
	tar -zxvf android-studio-2024.2.1.12-linux.tar.gz
	mv androind-studio /usr/local
	cd /usr/local/android-studio/bin/
	chmod +x ./studio.sh
	./studio
	
	## then install the SDKs required for Tauri from the android studio settings (SDK manager)
}

setup_nodejs_for_react_development_environment() { 
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
    nvm install 23
    node -v && npm -v 

    sudo npm install -g pnpm
}

setup_monorepo() { 
    pnpm install release-please -g
    
    # using `release-please-config.json` file to bootstrap release-please 
    release-please bootstrap \
        --token=$GITHUB_TOKEN \
        --repo-url=szn-app/donation-app --dry-run

    release-please release-pr \
        --token=$GITHUB_TOKEN \
        --repo-url=szn-app/donation-app --dry-run

    release-please github-release --token=$GITHUB_TOKEN --repo-url=szn-app/donation-app

}

setup_docker_github_container_registry() {
    CR_PAT='token'
    echo $CR_PAT | docker login ghcr.io -u 'username' --password-stdin # using PAT token    
}

kubernetes_dev() {
    # optional installation for more command options compared to `kubectl kustomize <...>` (kubectly kustomize preinstalled plugin)
    install_kustomize() { 
        TMP=$(mktemp -d)
        pushd $TMP
            curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash

            sudo mv kustomize /usr/local/bin/kustomize
        popd
        rm -r $TMP
        kustomize version
    }

    install_kubernetes_CRD_and_controllers() { 
        # Ingress k8s resource controllers
        minikube addons enable ingress # NGINX Ingress controller
        minikube addons enable ingress-dns 

        # Gateway API CRD installation - https://gateway-api.sigs.k8s.io/guides/#installing-a-gateway-controller
        kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml   

        # Gateway controller instlalation - https://gateway-api.sigs.k8s.io/implementations/ & https://docs.nginx.com/nginx-gateway-fabric/installation/ 
        kubectl apply -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v1.5.1/deploy/crds.yaml
        kubectl apply -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v1.5.1/deploy/default/deploy.yaml
        kubectl get pods -n nginx-gateway
    }


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

    # installations required
    install_kustomize

    minikube addons enable dashboard
    install_kubernetes_CRD_and_controllers
    kubectl get pods -n ingress-nginx # verify Ingress controller running
    install_domain_dns_systemd_resolved_for_test_domains
    # NOTE: careful of minikube dns caching and limitations, if dns name is not resolved after a change, an entire restart of minikube and probably disable/enable addons is required. 

    docker context ls && kubectl config get-contexts
    docker context use default
    minikube config set driver docker

    minikube start --driver=docker


    minikube kubectl -- get po -A # for a separate version kubectl install
    # or 
    kubectl cluster-info 
    kubectl get nodes

    minikube dashboard --url
}




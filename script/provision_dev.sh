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
test_domain_dns_systemd_resolved() {
# add minikube dns to linux as a dns server https://minikube.sigs.k8s.io/docs/handbook/addons/ingress-dns/#Linux
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/minikube.conf << EOF
[Resolve]
DNS=$(minikube ip)
Domains=~test
EOF
sudo systemctl restart systemd-resolved
}

    docker --version && kubectl version && minikube version
    minikube addons enable dashboard
    minikube addons enable ingress # NGINX Ingress controller
    minikube addons enable ingress-dns 
    kubectl get pods -n ingress-nginx # verify Ingress controller running
    test_domain_dns_systemd_resolved

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

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

# one-time scripts to setup the project
bootstrap_local_dev_machine() {
    clone_with_submodules() { 
        git clone --recursive https://github.com/szn-app/donation-app
    }

    git_submodule() {
        onetime_intialization() {
            git submodule add https://github.com/szn-app/fork-kratos-selfservice-ui-node.git service/auth-ui/kratos-selfservice-ui-node
            git submodule add https://github.com/szn-app/ai-generated dependency/ai-generated
        }

        example_remove() { 
            git submodule deinit -f service/auth-ui/kratos-selfservice-ui-node
            git rm --cached service/auth-ui/kratos-selfservice-ui-node
            rm -r .git/modules/kratos-selfservice-ui-node
            # [manual] remove section from .git/config
        }

        git submodule init && git submodule update
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

    setup_docker_github_container_registry() {
        CR_PAT='token'
        echo $CR_PAT | docker login ghcr.io -u 'username' --password-stdin # using PAT token    
    }

    generate_initial_release_please_config() {
        pnpm install release-please -g

        # using `release-please-config.json` file to bootstrap release-please 
        release-please bootstrap --token=$GITHUB_TOKEN --repo-url=szn-app/donation-app --dry-run

        # for debug development: 
        release-please release-pr --token=$GITHUB_TOKEN --repo-url=szn-app/donation-app --dry-run
        release-please github-release --token=$GITHUB_TOKEN --repo-url=szn-app/donation-app
    }

    setup_nodejs_for_react_development_environment() {
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
        nvm install 23
        node -v && npm -v 

        sudo npm install -g pnpm
    }
}


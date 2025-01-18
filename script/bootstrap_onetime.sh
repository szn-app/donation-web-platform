install_tailwindcss() { 
    pnpm install -D tailwindcss postcss autoprefixer
    pnpm dlx tailwindcss init -p
    
    pnpm install -D prettier prettier-plugin-tailwindcss

    example() { 
        pnpm tailwindcss -i ./src/input.css -o ./src/output.css --watch
    }
}

install_shadcn_for_vite() { 
    install_tailwindcss

    # follow https://ui.shadcn.com/docs/installation/vite
    # [manual] setup configs and paths resolution

    pnpm dlx shadcn@latest init
    pnpm dlx shadcn@latest add button
}   

install_nextui() {
    # https://nextui.org/docs/guide/installation#global-installation
    pnpm add @nextui-org/react framer-motion
    echo "public-hoist-pattern[]=*@nextui-org/*" > .npmrc && pnpm install

    pnpm add @nextui-org/button
    # [manual] add component styles to tailwind.config.js
}

install_cilium_cli() { 
    CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
    CLI_ARCH=amd64
    if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
    curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
    sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
    sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
    rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
}

install_kubectl_krew_plugin_manager() { 
    (
    set -x; cd "$(mktemp -d)" &&
    OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
    KREW="krew-${OS}_${ARCH}" &&
    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
    tar zxvf "${KREW}.tar.gz" &&
    ./"${KREW}" install krew
    )

    export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

    kubectl krew 
}

install_k8s_tools() { 
    brew install derailed/k9s/k9s
    kubectl krew install ctx
    kubectl krew install ns
    brew install fzf
}
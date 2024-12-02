provision_tauri() {
    if [[ $(uname -s) == "Linux" ]]; then
        distro=$(lsb_release -is)
        version=$(lsb_release -rs)

        echo "Detected distribution: $distro"
        echo "Detected version: $version"

        if [[ "$distro" == "Debian" ]]; then
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
install_tauri_dependencies_debian() {
    sudo apt update
    sudo apt install libwebkit2gtk-4.1-dev \
    build-essential \
    curl \
    wget \
    file \
    libxdo-dev \
    libssl-dev \
    libayatana-appindicator3-dev \
    librsvg2-dev
}
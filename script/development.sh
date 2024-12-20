misc() { 
    # modify permission
    find ./ -maxdepth 4 -name "script.sh" -exec chmod +x {} \;

    cargo create-tauri-app 
}

## IMPORTANT! used in .github/workflows/*
build_react_spa() { 
    pushd ./service/web-server

    pnpm install --frozen-lockfile
    pnpm run build
    
    popd
}

develop_tauri_desktop_with_workaround_black_screen() { 
    cd ./service/web-server
    WEBKIT_DISABLE_COMPOSITING_MODE=1 cargo tauri dev
}

develop_tauri_android() { 
    ./script.sh setup_android_sdk_variables

    cargo tauri android init
    cargo tauri android dev
}

develop_pnpm_react() { 
    cd web-server
    pnpm install
    # run application development
    WEBKIT_DISABLE_COMPOSITING_MODE=1 cargo tauri dev
}

build() {
    pnpm install
    NO_STRIP=true cargo tauri build 
    # run application
    WEBKIT_DISABLE_COMPOSITING_MODE=1 ./src-tauri/target/release/bundle/appimage/*.AppImage
}

record_version() { 
    NODE_VERSION=$(node -v | cut -d 'v' -f2)
    PNPM_VERSION=$(pnpm --version | cut -d ' ' -f2)
    RUST_VERSION=$(rustc --version | awk '{print $2}') 
    CARGO_VERSION=$(cargo --version | awk '{print $2}')

    echo "Node.js version: ${NODE_VERSION}" > version.txt
    echo "pnpm version: ${PNPM_VERSION}" >> version.txt
    echo "Rust version: ${RUST_VERSION}" >> version.txt
    echo "Cargo version: ${CARGO_VERSION}" >> version.txt
}

# for feature branches and hotfixes.
feature_pull_request() {  
    if [[ $# -lt 1 ]]; then
        exit 1; 
    fi

    local feature_branch="${1:-feature/example}"
    git push origin $feature_branch
    
    # PR to trigger CI test
    gh pr create --head $feature_branch --base main --title "feat(frontend): new implementation feature" --fill-verbose
    # or merges but without triggering CI test
    {
        git checkout main
        git merge --squash $feature_branch -m "feat(frontend): new implementation feature"
    }

    # NOTE: automerge is applied only on PRs from branches that are prefix with "feature/*" or "hotfix/*".
}

minikube() {
    # bind docker images directly inside minikube
    eval $(minikube docker-env)
    (cd service/web-server && ./script.sh build_container)

    kubectl create namespace donation-app   
    kubectl config set-context --current --namespace=donation-app
    kubectl config view && kubectl get namespace && kubectl config get-contexts

    (cd manifest/development && kubectl apply -k .)
    minikube ip 
    # expose service to host: 
    minikube tunnel 
    minikube service dev-web-server --url  --namespace=donation-app

    nslookup donation-app.test $(minikube ip) # query dns server running in minikube cluaster
    ping donation-app.test
}
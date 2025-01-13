#!/bin/bash

misc() { 
    # clone with submodules
    git clone --recursive https://github.com/szn-app/donation-app

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
    # or 
    pnpm run dev
}

build() {
    pnpm install
    NO_STRIP=true cargo tauri build 
    # run application
    WEBKIT_DISABLE_COMPOSITING_MODE=1 ./src-tauri/target/release/bundle/appimage/*.AppImage
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
    (cd service/web-server && ./script.sh build_container_web_server)

    # kubectl create namespace donation-app 
    kubectl config set-context --current --namespace=donation-app
    kubectl config view && kubectl get namespace && kubectl config get-contexts

    (cd manifest/development && kubectl apply -k .)
    kubectl get all
 
    minikube ip 
    # expose service to host: 
    minikube tunnel # expose all possible resources (e.g. loadbalancers)
    minikube service dev-web-server --url  --namespace=donation-app

    nslookup donation-app.test $(minikube ip) # query dns server running in minikube cluaster
    dig donation-app.test
    export GW=$(minikube ip) # or direct gateway ip exposed using minikube tunnel.
    curl --resolve donation-app.test:80:$GW donation-app.test
    ping donation-app.test

    # using ingress 
    kubectl describe ingress ingress -n donation-app
    

    # using gateway 
    {
        export GW=$(minikube ip) # or direct gateway ip exposed using minikube tunnel.
        kubectl apply -k ./manifest/gateway/development
        minikube tunnel # otherwise, with ingress-dns and ingress.yml re-route to gateway will make accessing gateway through domain resolution directly with minikube ip
        minikube dashboard
        kubectl describe gateway -n donation-app
        kubectl describe httproute -n donation-app
        dig donation
        curl --resolve donation-app.test:80:$GW donation-app.test

    }

    kubectl apply -k ./manifest/entrypoint/development

}

git_submodule() {
    onetime_intialization() {
        git submodule add https://github.com/ory/kratos-selfservice-ui-node.git service/auth-ui/kratos-selfservice-ui-node
    }

    example_remove() { 
        git submodule deinit -f service/auth-ui
        git rm --cached service/auth-ui
        rm -r .git/modules
        # [manual] remove section from .git/config
    }

    git submodule init && git submodule update
}
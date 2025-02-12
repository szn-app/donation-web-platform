#!/bin/bash

misc_() {
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

build_app() {
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

{
    # alternative approach to build all containers directly into minikube
    build_all_containers_directly_into_minikube() {
        # bind docker images directly inside minikube
        eval $(minikube docker-env) # bind docker command to minikube docker
        (cd service/web-server && ./script.sh build_container_web_server)
        (cd service/auth-ui && ./script.sh bulid_container_auth_ui)
        (cd service/auth-token-exchange && ./script.sh build_container_auth_token_exchange)

        { # reverse minikube eval
            unset DOCKER_TLS_VERIFY
            unset DOCKER_HOST
            unset DOCKER_CERT_PATH
        }
    }
}
build_all_containers_with_load() {
    (cd service/web-server && ./script.sh build_container_web_server)
    docker save web-server:latest | (eval $(minikube docker-env) && docker load)

    (cd service/auth-ui && ./script.sh bulid_container_auth_ui)
    docker save auth-ui:latest | (eval $(minikube docker-env) && docker load)
    
    (cd service/auth-token-exchange && ./script.sh build_container_auth_token_exchange)
    docker save auth-token-exchange:latest | (eval $(minikube docker-env) && docker load)
}

{
    deploy_local_minikube_only_app() {
        build_all_containers_with_load
        
        source ./script/deploy.sh
        deploy --environment development --action app
    }
}
deploy_local_minikube() {
    action=${1:-"install"}

    example_scripts() {
        kubectl config view && kubectl get namespace && kubectl config get-contexts

        (cd manifest/development && kubectl apply -k .)
        kubectl get all
    
        minikube ip 
        # expose service to host: 
        minikube tunnel # expose all possible resources (e.g. loadbalancers)
        minikube service dev-web-server --url --namespace=donation-app

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

        curl -i --header "Host: donation-app.test" "<ip-of-load-balancer>"
    }

    if [ "$action" == "delete" ]; then
        minikube delete
        return 
    elif [ "$action" == "kustomize" ]; then
        source ./script/deploy.sh
        deploy --environment development --action kustomize
        return
    fi

    build_all_containers_with_load
    # build_all_containers_directly_into_minikube

    source ./script/deploy.sh
    deploy --environment development --action install

    kubectl config set-context --current --namespace=all

    tunnel() {
        terminate_background_jobs() {
            jobs -p | xargs kill -9
            pkill -f "minikube tunnel"
        }
        terminate_background_jobs

        sudo echo "" # switch to sudo explicitely
        minikube tunnel & 
        sleep 5 
        
        while ! kubectl get svc nginx-gateway -n nginx-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' &> /dev/null; do
            echo "Waiting for load balancer IP..."
            sleep 5
        done
        loadbalancer_ip=$(kubectl get svc nginx-gateway -n nginx-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        curl -k -i --header "Host: donation-app.test" $loadbalancer_ip

        sudo sed -i '/\.test/d' /etc/hosts
        echo "$loadbalancer_ip donation-app.test auth.donation-app.test api.donation-app.test test.donation-app.test *.donation-app.test" | sudo tee -a /etc/hosts

        curl -k -i --resolve donation-app.test:443:$loadbalancer_ip https://donation-app.test
        curl -k -i https://donation-app.test
    }

    tunnel
}

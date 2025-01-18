#!/bin/bash

# [obsolete]
manual_service_tag_version() { 
    local service="${1:-web-server}" 
    local version="${2:-0.1.0}" 

    # bump package.json version
    set_version() {
        local new_version="$1"

        jq --arg new_version "$new_version" '.version = $new_version' package.json > package.json.tmp
        mv package.json.tmp package.json

        echo "Version set to $new_version"
    }

    pushd ./service/$service
    set_version "$version"

    git add package.json
    git commit -m "$service $version version bump"

    popd
}

# [obsolete]
manual_release_package() {
    local service="${1:-web-server}" 
    local version="${2:-0.1.0}" 

    if ! git symbolic-ref --short HEAD | grep -q '^main$'; then
        echo "error: not on main branch."
        exit 1;
    fi

    if [[ -z "$(git diff --cached --name-only)" ]]; then
        echo "No staged files found. Proceeding..."
        if [[ -n "$(git status --porcelain)" ]]; then
            git stash 
        fi 
    else 
        echo "There are staged files. Please commit or stash them before proceeding."
        exit 1
    fi

    if [[ $# -gt 1 ]]; then
        service_tag_version $service $version
    fi

    git push origin 

    git tag $service-v$version
    git push --tags

    git stash pop > /dev/null 2>&1
}

example_workflow_with_release_please_manually_triggered() { 
    create_feature_pr() {
        feature_branch=$1
        git checkout -b $feature_branch
        git commit --allow-empty -m "commit 1" 
        git commit --allow-empty -m "commit 2" 
        git commit --allow-empty -m "commit 3"
        git push --set-upstream origin $feature_branch
        gh pr create --base main --head $feature_branch --title "feat: adding feacture x to component A" --fill-verbose
    }

    merge_last_pr() { 
        local feature_branch=$1
        git fetch origin 
        git checkout main 
        last_pr_number=$(gh pr list --state open --json number | jq -r '.[0].number') 
        default_branch=$(git remote show origin | grep "HEAD branch:" | awk '{print $3}')
        pr_title=$(gh pr view "$last_pr_number" --json title | jq -r '.title')
        gh pr merge $last_pr_number --squash -t "$pr_title"
        git pull && git push origin main 
    }

    local release_please_workflow=release.yml

    local feature_branch=branch_feature_x
    create_feature_pr $feature_branch

    # create release pr
    merge_last_pr $feature_branch # merge feature pr
    gh workflow run $release_please_workflow # -> release pr is created. 
    gh run list --workflow=$release_please_workflow 

    {
        # new features can be added and will be appended to the existing release PR managed by `release-please``.
        local feature_branch=branch_feature_y
        create_feature_pr $feature_branch
        
        # create release pr
        merge_last_pr $feature_branch # merge feature pr
        gh workflow run $release_please_workflow # -> release pr is created. 
        gh run list --workflow=$release_please_workflow 

        merge_last_pr $feature_branch # merge release pr
    }

    # create a package release on Github
    merge_last_pr $feature_branch # merge release pr
    gh workflow run $release_please_workflow # -> package a github release
}

delete_tag() { 
    tag=${1:-web-server-v0.1.1}
    git push origin :$tag
    git tag -d $tag
}

# NOTE: Dockerfile labels should associate package release to github repo (otherwise a manual web interface association is required)
github_container_registry_deploy() {
    TAG=web-server:latest
    docker tag $TAG ghcr.io/szn-app/donation-app/$TAG
    docker push ghcr.io/szn-app/donation-app/$TAG
}

env_files() { 
    _related_commands() { 
        find . -name '.env.template' 
        sed "s/<username>/your_username/g;s/<password>/your_password/g;s/YOUR_API_KEY/your_actual_api_key/g;s/YOUR_SECRET_KEY/your_actual_secret_key/g" < .env.template > .env
    }

    # create .env files from default template if doesn't exist
    create_env_files() {
            # Find all *.env.template files
            find . -name "*.env.template" | while IFS= read -r template_file; do
                    # Extract filename without extension
                    filename=$(basename "$template_file" | cut -d '.' -f 1)
                    env_file="$(dirname "$template_file")/$filename.env"

                    # Check if .env file already exists
                    if [ ! -f "$env_file" ]; then
                            # Create a new .env file from the template in the same directory
                            cp "$template_file" "$env_file" 
                            echo "created env file file://$env_file from $template_file"
                    fi
            done
    }

    generate_secret_auth_ui() {
    # generate secrets for production
        auth_ui_secret_file="./manifest/auth_ui/production/secret.env"
        if [ ! -f "$auth_ui_secret_file" ]; then
            t=$(mktemp) && cat <<EOF > "$t"
COOKIE_SECRET="$(openssl rand -base64 32)"
CSRF_COOKIE_NAME="$(shuf -n 1 /usr/share/dict/words | tr -d '\n')_csrf"
CSRF_COOKIE_SECRET="$(openssl rand -base64 32)"
EOF

            mv $t $auth_ui_secret_file
            echo "generated secrets file: file://$auth_ui_secret_file" 
        fi
    }

    generate_database_kratos_credentials() {
        db_secret_file="./manifest/auth/ory-kratos/db_kratos_secret.env"
        if [ ! -f "$db_secret_file" ]; then
            t=$(mktemp) && cat <<EOF > "$t"
DB_USER="$(shuf -n 1 /usr/share/dict/words | tr -d '\n')"
DB_PASSWORD="$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9')"
EOF

            mv $t $db_secret_file
            echo "generated secrets file: file://$db_secret_file" 
        fi
    }

    generate_database_hydra_credentials() {
        db_secret_file="./manifest/auth/ory-hydra/db_hydra_secret.env"
        if [ ! -f "$db_secret_file" ]; then
            t=$(mktemp) && cat <<EOF > "$t"
DB_USER="$(shuf -n 1 /usr/share/dict/words | tr -d '\n')"
DB_PASSWORD="$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9')"
EOF

            mv $t $db_secret_file
            echo "generated secrets file: file://$db_secret_file" 
        fi
    }

    generate_database_kratos_credentials
    generate_database_hydra_credentials
    generate_secret_auth_ui
    create_env_files
}

# https://k8s.ory.sh/helm/
# $`install_ory_stack
# $`install_ory_stack delete
install_ory_stack() { 
     
    action=${1:-"install"}

    {
        if [ "$action" == "delete" ]; then
            helm uninstall kratos -n auth
            helm uninstall postgres-kratos -n auth
            helm uninstall hydra -n auth
            helm uninstall postgres-hydra -n auth
            helm uninstall oathkeeper -n auth
            return 
        fi
    }
    
    intall_kratos() { 
        pushd ./manifest/auth
        printf "install Postgresql for Ory Kratos \n"

        set -a
        source ory-kratos/db_kratos_secret.env
        set +a
        helm upgrade --reuse-values --install postgres-kratos bitnami/postgresql -n auth --create-namespace -f ory-kratos/postgresql-values.yml \
            --set auth.username=${DB_USER} \
            --set auth.password=${DB_PASSWORD} \
            --set auth.database=kratos_db
        # this will generate 'postgres-kratos-postgresql' service

        printf "install Ory Kratos \n"
        # preprocess file through substituting env values
        t="$(mktemp).yml" && envsubst < ory-kratos/kratos-config.yml > $t && printf "replaced env variables in manifest: file://$t\n" 
        default_secret="$(openssl rand -hex 16)"
        cookie_secret="$(openssl rand -hex 16)"
        cipher_secret="$(openssl rand -hex 16)"
        helm upgrade --install kratos ory/kratos -n auth --create-namespace -f ory-kratos/helm-values.yml -f $t \
            --set kratos.config.secrets.default[0]="$default_secret" \
            --set kratos.config.secrets.cookie[0]="$cookie_secret" \
            --set kratos.config.secrets.cipher[0]="$cipher_secret" \
            --set env[0].name=DB_USER --set env[0].value=${DB_USER} \
            --set env[0].name=DB_PASSWORD --set env[0].value=${DB_PASSWORD}

        popd
    }
    
    install_hydra() {
        pushd ./manifest/auth
        printf "install Postgresql for Ory Hydra \n"

        set -a
        source ory-hydra/db_hydra_secret.env # DB_USER, DB_PASSWORD
        set +a
        helm upgrade --reuse-values --install postgres-hydra bitnami/postgresql -n auth --create-namespace -f ory-hydra/postgresql-values.yml \
            --set auth.username=${DB_USER} \
            --set auth.password=${DB_PASSWORD} \
            --set auth.database=hydra_db
        # this will generate 'postgres-hydra-postgresql' service

        printf "install Ory Hydra \n"
        # preprocess file through substituting env values
        t="$(mktemp).yml" && envsubst < ory-hydra/hydra-config.yml > $t && printf "replaced env variables in manifest: file://$t\n" 
        system_secret="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | base64)" 
        cookie_secret="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | base64)" 
        helm upgrade --install hydra ory/hydra -n auth --create-namespace -f ory-hydra/helm-values.yml -f $t \
            --set kratos.config.secrets.system[0]="$system_secret" \
            --set kratos.config.secrets.cookie[0]="$cookie_secret" \
            --set env[0].name=DB_USER --set env[0].value=${DB_USER} \
            --set env[0].name=DB_PASSWORD --set env[0].value=${DB_PASSWORD}

        popd
    }

    install_oathkeeper() {
        pushd ./manifest/auth
        printf "install Ory Aothkeeper \n"
        
        helm upgrade --install oathkeeper ory/oathkeeper -n auth --create-namespace -f ory-oathkeeper/helm-values.yml -f ory-oathkeeper/oathkeeper-config.yml

        popd
    }

create_oauth2_client_for_trusted_app() {
        pushd ./manifest/auth

        example_hydra_admin() { 
            kubectl run -it --rm --image=debian:latest debug-pod --namespace auth -- /bin/bash
            {
                apt update && apt install curl -y
                # install hydra
                bash <(curl https://raw.githubusercontent.com/ory/meta/master/install.sh) -d -b . hydra v2.2.0 && mv hydra /usr/bin/

                curl http://hydra-admin:4445/admin/clients

                delete_all_clients() { 
                    client_list=$(curl -X GET 'http://hydra-admin:4445/admin/clients' | jq -r '.[].client_id')
                    for client in $client_list
                    do
                        echo "Deleting client: $client"
                        curl -X DELETE "http://hydra-admin:4445/admin/clients/$client"
                    done
                }
            }

            hydra list oauth2-clients --endpoint "http://hydra-admin:4445"
        }

        # port-forward hydra-admin 
        # kpf -n auth services/hydra-admin 4445:4445

        {
            kubectl run --image=nicolaka/netshoot setup-pod --namespace auth -- /bin/sh -c "while true; do sleep 60; done"
            sleep 5

            # app client users for trusted app
            # redirect uri is where the resource owner (user) will be redirected to once the authorization server grants permission to the client
            # NOTE: using the `authorization code` the client gets both `accesst token` and `id token` when `scope` includes `openid`.
            t="$(mktemp).sh" && cat << 'EOF' > $t
#!/bin/bash
echo 'Running setup script!'
curl 'http://hydra-admin:4445/admin/clients' | jq -r '.[] | select(.client_id=="frontend-client") | .client_id' | grep -q 'frontend-client' || curl -X POST 'http://hydra-admin:4445/admin/clients' -H 'Content-Type: application/json' \
--data '{
    "client_id": "frontend-client",
    "client_name": "frontend-client",
    "grant_types": ["authorization_code", "refresh_token"],
    "response_types": ["code id_token"],
    "redirect_uris": ["http://auth.wosoom.com/authorize/oauth-redirect"], 
    "audience": ["exposed-api"],    
    "scope": "offline_access openid",
    "token_endpoint_auth_method": "client_secret_post",
    "skip_consent": true,
    "skip_logout_prompt": true,
    "post_logout_redirect_uris": []
}'
EOF
            kubectl cp $t setup-pod:$t --namespace auth
            kubectl exec -it setup-pod --namespace auth -- /bin/sh -c "chmod +x $t && $t"
        }

        {
            # internal service communication
            client_secret="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | base64)" 
            t="$(mktemp).sh" && cat << 'EOF' > $t
#!/bin/bash
echo 'Running setup script!'

curl -s 'http://hydra-admin:4445/admin/clients' | jq -r '.[] | select(.client_id=="internal-communication") | .client_id' | grep -q 'internal-communication' || \
curl -X POST 'http://hydra-admin:4445/admin/clients' -H 'Content-Type: application/json' \
--data '{
    "client_id": "internal-communication",
    "client_name": "internal-communication",
EOF
        echo "\"client_secret\": \"$client_secret\"," >> $t
        cat << EOF >> $t
    "grant_types": ["client_credentials"],
    "response_types": [],
    "redirect_uris": [],
    "audience": ["internal-api", "exposed-api"],
    "scope": "offline_access openid custom_scope:read",
    "token_endpoint_auth_method": "client_secret_basic",
    "skip_consent": false,
    "post_logout_redirect_uris": [],
    "skip_logout_prompt": false
}'                        
EOF
            kubectl cp $t setup-pod:$t --namespace auth
            kubectl exec -it setup-pod --namespace auth -- /bin/sh -c "chmod +x $t && $t"

        }

        kubectl delete --force pod setup-pod -n auth


        # NOTE: this is not a proper OIDC exposure to other services (only an example) 
        # for third party apps to access data 
        # curl -X POST 'http://hydra-admin/admin/clients' \
        # -H 'Content-Type: application/json' \
        # --data-raw '{
        #     "client_id": "third-party",
        #     "client_name": "third-party",
        #     "grant_types": ["authorization_code", "refresh_token"],
        #     "response_types": ["code"],
        #     "redirect_uris": ["http://localhost:8000/oauth-redirect"],
        #     "audience": ["exposed-api"],
        #     "scope": "offline_access openid custom_scope:read",
        #     "token_endpoint_auth_method": "client_secret_post",
        #     "skip_consent": false,
        #     "post_logout_redirect_uris": [],
        #     "skip_logout_prompt": false
        # }'

        manual_verify() { 
            kubectl exec -it setup-pod --namespace auth -- /bin/sh -c "curl http://hydra-admin:4445/admin/clients | jq"
        }

        popd
    }

    # ory stack charts
    helm repo add ory https://k8s.ory.sh/helm/charts
    # postgreSQL
    helm repo add bitnami https://charts.bitnami.com/bitnami 
    helm repo update

    intall_kratos
    install_hydra
    install_oathkeeper
    create_oauth2_client_for_trusted_app

    manual_verify() { 
        # use --debug with `helm` for verbose output

        kubectl port-forward -n auth service/kratos-admin 8083:80

        kubectl run -it --rm --image=nicolaka/netshoot debug-pod --namespace auth -- /bin/bash 
        {
            $(nslookup kratos-admin)
            
            # execute from within `auth` cluster namespace
            # get an example payload from login and registration
            flow_id=$(curl -s -X GET -H "Accept: application/json" http://kratos-public/self-service/login/api  | jq -r '.id')
            curl -s -X GET -H "Accept: application/json" "http://kratos-public/self-service/login/flows?id=$flow_id" | jq

            flow_id=$(curl -s -X GET -H "Accept: application/json" http://kratos-public/self-service/registration/api | jq -r '.id')
            curl -s -X GET -H "Accept: application/json" "http://kratos-public/self-service/registration/flows?id=$flow_id" | jq
        }

        # verify database:
        set -a
        source manifest/auth/ory-kratos/db_kratos_secret.env
        set +a
        kubectl run -it --rm --image=postgres debug-pod --namespace auth --env DB_USER=$DB_USER --env DB_PASSWORD=$DB_PASSWORD -- /bin/bash
        {
            export PGPASSWORD=$DB_PASSWORD
            psql -h "postgres-kratos-postgresql" -U "$DB_USER" -d "kratos_db" -p 5432 -c "\dt" 
            psql -h "postgres-kratos-postgresql" -U "$DB_USER" -d "kratos_db" -p 5432 -c "SELECT * FROM identities;" 
        }

        # manage users using Ory Admin API through the CLI tool
        kubectl run -it --rm --image=nicolaka/netshoot debug-pod --namespace auth -- /bin/bash
        {            
            export KRATOS_ADMIN_URL="http://kratos-admin" 
            # https://www.ory.sh/docs/kratos/reference/api
            curl -X GET "$KRATOS_ADMIN_URL/admin/health/ready"
            curl -X GET "$KRATOS_ADMIN_URL/admin/identities" -H "Content-Type: application/json" | jq
            list_all_sessions() {
                for identity_id in $(curl -X GET "$KRATOS_ADMIN_URL/admin/identities" -H "Content-Type: application/json" | jq -r '.[].id'); do
                    echo "Sessions for Identity: $identity_id"
                    curl -X GET "$KRATOS_ADMIN_URL/admin/identities/$identity_id/sessions" -H "Content-Type: application/json" | jq
                    echo ""
                done
            }
            list_all_sessions

        }

    }
}

kustomize_kubectl() {
    action=${1:-"install"}

    kubectl ctx k3s-project

    {
        if [ "$action" == "delete" ]; then
            kubectl delete -k ./manifest/entrypoint/production
            install_ory_stack delete
            return 
         elif [ "$action" == "kustomize" ]; then
            pushd manifest/entrypoint/production 
            t="$(mktemp).yaml" && kubectl kustomize ./ > $t && printf "rendered manifest template: file://$t\n"  # code -n $t
            popd
            return
        fi
    }


    env_files

    install_ory_stack

    pushd ./manifest 
        kubectl apply -k ./entrypoint/production
        {
            pushd ./entrypoint/production 
            t="$(mktemp).yaml" && kubectl kustomize ./ > $t && printf "rendered manifest template: file://$t\n"  # code -n $t
            popd
        }
    popd 
    
    echo "Services deployed to the cluster. NOTE: wait few minutes to complete startup and propagate TLS certificate generation"

    # verify cluster certificate issued successfully 
    _verify() {
        ### generate combined configuration
        kubectl kustomize ./manifest/gateway/development > ./tmp/combined_manifest.yml
        cat ./tmp/combined_manifest.yml | kubectl apply -f -

        kubectl kustomize ./
        kubectl get -k ./
        kubectl --kubeconfig $kubeconfig  get -k ./
        kubectl describe -k ./
        kubectl diff -k ./

        kubectl get clusterissuer -A # two issuers: staging & production issuers
        kubectl describe challenge -A # ephemeral challenge appearing during certificate issuance process
        kubectl get order -A # should be STATE = pending → STATE = valid
        kubectl get certificate -A # should be READY = True
        kubectl get httproute -A
        kubectl get gateway -A

        # check dns + web server response with tls staging certificate
        domain_name=""
        curl -I http://$domain_name
        curl --insecure -I https://$domain_name
        cloud_load_balancer_ip=""
        curl --header "Host: donation-app.com" $cloud_load_balancer_ip

        # run ephemeral debug container
        kubectl run -it --rm --image=nicolaka/netshoot debug-pod --namespace some_namespace -- /bin/bash 
        
    }

}


### example and verification
{
    example_test_cilium() { 

        cilium config view | grep -w "enabe-gateway-api"
    }
}
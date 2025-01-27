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

    generate_database_keto_credentials() {
        db_secret_file="./manifest/auth/ory-keto/db_keto_secret.env"
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
    generate_database_keto_credentials
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

            kubectl delete secret ory-hydra-client--frontend-client-oauth -n auth
            kubectl delete secret ory-hydra-client--frontend-client -n auth
            kubectl delete secret ory-hydra-client--internal-communication -n auth
            kubectl delete secret ory-hydra-client--oathkeeper-introspection -n auth
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
        t="$(mktemp).yml" && envsubst < ory-kratos/kratos-config.yml > $t && printf "generated manifest with replaced env variables: file://$t\n" 
        default_secret="$(openssl rand -hex 16)"
        cookie_secret="$(openssl rand -hex 16)"
        cipher_secret="$(openssl rand -hex 16)"
        helm upgrade --install kratos ory/kratos -n auth --create-namespace -f ory-kratos/helm-values.yml -f $t \
            --set-file 'identitySchemas=ory-kratos/identity-default-schema.json' \
            --set kratos.config.secrets.default[0]="$default_secret" \
            --set kratos.config.secrets.cookie[0]="$cookie_secret" \
            --set kratos.config.secrets.cipher[0]="$cipher_secret" \
            --set env[0].name=DB_USER --set env[0].value=${DB_USER} \
            --set env[0].name=DB_PASSWORD --set env[0].value=${DB_PASSWORD}

        verify()  {
            t="$(mktemp).yml" && helm upgrade --dry-run --debug --install kratos ory/kratos -n auth --create-namespace -f ory-kratos/helm-values.yml -f $t --set-file 'identitySchemas=ory-kratos/identity-default-schema.json' --set kratos.config.secrets.default[0]="$default_secret" --set kratos.config.secrets.cookie[0]="$cookie_secret" --set kratos.config.secrets.cipher[0]="$cipher_secret" --set env[0].name=DB_USER --set env[0].value=${DB_USER} --set env[0].name=DB_PASSWORD --set env[0].value=${DB_PASSWORD} > $t && printf "generated manifest with replaced env variables: file://$t\n"
            
            # https://www.ory.sh/docs/kratos/self-service
            {
                # https://www.ory.sh/docs/kratos/quickstart#perform-registration-login-and-logout
                # return a new login flow and csrf_token 
                flow=$(curl -s -X GET -H "Accept: application/json" "https://auth.wosoom.com/authenticate/self-service/login/api")
                flowId=$(echo $flow | jq -r '.id')
                actionUrl=$(echo $flow | jq -r '.ui.action') && echo $actionUrl
                # display info about the new login flow and required parameters
                curl -s -X GET -H "Accept: application/json" "https://auth.wosoom.com/authenticate/self-service/login/flows?id=$flowId" | jq
                curl -s -X POST -H  "Accept: application/json" -H "Content-Type: application/json" -d '{"identifier": "i-do-not-exist@user.org", "password": "the-wrong-password", "method": "password"}' "$actionUrl" | jq
            }

            {
                # makes internal call to https://auth.wosoom.com/authenticate/self-service/login/api to retrieve csrf_token and redirect user
                curl -s -i -X GET -H "Accept: text/html" https://auth.wosoom.com/authenticate/self-service/login/browser 
                # login will make POST request with required parameters to /self-service/login/flows?id=$flowId 
                printf "visit https://auth.wosoom.com/login?flow=$flowId\n"   
            }

            # send cookies in curl
            {
                # A cookie jar for storing the CSRF tokens
                cookieJar=$(mktemp) && flowId=$(curl -s -X GET --cookie-jar $cookieJar --cookie $cookieJar -H "Accept: application/json" https://auth.wosoom.com/authenticate/self-service/login/browser | jq -r '.id')
                # The endpoint uses Ory Identities' REST API to fetch information about the request
                curl -s -X GET --cookie-jar $cookieJar --cookie $cookieJar -H "Accept: application/json" "https://auth.wosoom.com/authenticate/self-service/login/flows?id=$flowId" | jq
            }

            # registration flow 
            {
                flowId=$(curl -s -X GET -H "Accept: application/json" https://auth.wosoom.com/authenticate/self-service/registration/api | jq -r '.id')
                curl -s -X GET -H "Accept: application/json" "https://auth.wosoom.com/authenticate/self-service/registration/flows?id=$flowId" | jq
            }


        }

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
        t="$(mktemp).yml" && envsubst < ory-hydra/hydra-config.yml > $t && printf "generated manifest with replaced env variables: file://$t\n" 
        system_secret="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | base64 -w 0)" 
        cookie_secret="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | base64 -w 0)" 
        helm upgrade --install hydra ory/hydra -n auth --create-namespace -f ory-hydra/helm-values.yml -f $t \
            --set kratos.config.secrets.system[0]="$system_secret" \
            --set kratos.config.secrets.cookie[0]="$cookie_secret" \
            --set env[0].name=DB_USER --set env[0].value=${DB_USER} \
            --set env[0].name=DB_PASSWORD --set env[0].value=${DB_PASSWORD}

        verify() { 
            # /.well-known/jwks.json
            # /.well-known/openid-configuration
            # /oauth2/auth
            # /oauth2/token
            # /oauth2/revoke
            # /oauth2/fallbacks/consent
            # /oauth2/fallbacks/error
            # /oauth2/sessions/logout
            # /userinfo

            kubectl run -it --rm --image=debian:latest debug-pod-client --namespace auth -- /bin/bash
            {
                apt update && apt install curl jq -y
                # install hydra
                bash <(curl https://raw.githubusercontent.com/ory/meta/master/install.sh) -d -b . hydra v2.2.0 && mv hydra /usr/bin/

                curl -s http://hydra-admin/admin/clients | jq

                # https://www.ory.sh/docs/hydra/self-hosted/quickstart
                # [OAuth 2.0] create client and perform "clients credentials" grant
                {
                    client=$(hydra create client --endpoint http://hydra-admin/ --format json --grant-type client_credentials)
                    # parse the JSON response using jq to get the client ID and client secret:
                    client_id=$(echo $client | jq -r '.client_id')
                    client_secret=$(echo $client | jq -r '.client_secret')

                    # perform client credentials grant
                    CREDENTIALS_GRANT=$(hydra perform client-credentials --endpoint http://hydra-public/ --client-id "$client_id" --client-secret "$client_secret")
                    printf "%s\n" "$CREDENTIALS_GRANT"
                    TOKEN=$(printf "%s\n" "$CREDENTIALS_GRANT" | grep "ACCESS TOKEN" | awk '{if($1 == "ACCESS" && $2 == "TOKEN") {print $3}}')

                    # token introspection 
                    hydra introspect token --format json-pretty --endpoint http://hydra-admin/ $TOKEN
                }

                # [OAuth 2.0] user "Code" grant 
                {
                    # example of public client which cannot provide client secrets (authentication flow only using client id )
                    code_client=$(hydra create client --endpoint http://hydra-admin --grant-type authorization_code,refresh_token --response-type code,id_token --format json --scope openid --scope offline --redirect-uri http://hydra-public/callback --token-endpoint-auth-method none)
                    code_client=$(hydra create client --endpoint http://hydra-admin --grant-type authorization_code,refresh_token --response-type code,id_token --format json --scope openid --scope offline --redirect-uri http://hydra-public/callback)
                    code_client_id=$(echo $code_client | jq -r '.client_id')
                    code_client_secret=$(echo $code_client | jq -r '.client_secret')
                    # perform Authorization Code flow to grant Code 
                    hydra perform authorization-code --port 5555 --client-id $code_client_id --endpoint http://hydra-admin/ --scope openid --scope offline
                    # [execute on local mahcine] access hydra's Authorization Code flow endpoint
                    # NOTE: requires exposing all relied on services because the examplery authorization page on 5555 redirects to the endpoint hydra-admin which is not exposed in localhost 
                    {
                        # TODO: APPROACH NOT WORKING - browser doesn't resolve kubernetes services
                        kubectl run --image=overclockedllama/docker-chromium debug-auth-browser --namespace auth
                        kubectl port-forward pod/debug-auth-browser 5800:5800 --namespace auth
                        # access browser at localhost:5800 (on local machine) and navigate to localhost:5555 (which is inside kubernetes)
                        kubectl delete pod debug-auth-browser --grace-period=0 --force -n auth
                    }
                    # [another approach]  requires a reverse proxy or solution to map /etc/hosts domains to specific localhost port, in order to fix redirections
                    {
                        # TODO: APPROACH NOT WOKRING INCOMPLETE
                        kubectl port-forward pod/debug-pod-client 5555:5555 --namespace auth
                        kubectl port-forward service/hydra-admin 5556:80 --namespace auth
                        kubectl port-forward service/hydra-public 5557:80 --namespace auth
                        # echo "127.0.0.1 localhost:5556" | tee -a /etc/hosts
                        # sed -i '/127.0.0.1 example1.com/d' /etc/hosts
                    }
                }
            }
        }

        popd
    }

    install_oathkeeper() {
        pushd ./manifest/auth

        generate_oathkeeper_oauth2_client_credentials_env_file() {
            CLIENT_NAME="oathkeeper-introspection"
            CLIENT_SECRET=$(kubectl get secret ory-hydra-client--oathkeeper-introspection -n auth -o jsonpath="{.data.$CLIENT_NAME}" | base64 -d)

            # Check if the secret was retrieved successfully
            if [[ -z "$CLIENT_SECRET" ]]; then
                echo "Error: Failed to retrieve client secret 'ory-hydra-client--oathkeeper-introspection' from Kubernetes."
                exit 1
            fi

            # create authorization header value
            OATHKEEPER_CLIENT_CREDENTIALS=$(printf "${CLIENT_NAME}:${CLIENT_SECRET}" | base64 -w 0)

            secret="./ory-oathkeeper/secret.env"

            t=$(mktemp) && cat <<EOF > "$t"
OATHKEEPER_CLIENT_CREDENTIALS="${OATHKEEPER_CLIENT_CREDENTIALS}"
EOF
            mv $t $secret
            echo "generated secrets file: file://$secret" 
        }

        printf "install Ory Aothkeeper \n"
        generate_oathkeeper_oauth2_client_credentials_env_file
        set -a
        source ory-oathkeeper/secret.env 
        set +a

        # t="$(mktemp).pem" && openssl genrsa -out "$t" 2048 # create private key
        # # Generate a JWKs file (if needed) - basic example using OpenSSL:
        # y="$(mktemp).json" && openssl rsa -in "$t" -pubout -outform PEM > $y 
        # echo "jwt file created file://$y"

        t="$(mktemp).yml" && envsubst < ory-oathkeeper/oathkeeper-config.yml > $t && printf "generated manifest with replaced env variables: file://$t\n" 
        helm upgrade --install oathkeeper ory/oathkeeper -n auth --create-namespace -f ory-oathkeeper/helm-values.yml -f $t \
             --set-file 'oathkeeper.accessRules=./ory-oathkeeper/oathkeeper-access-rules.json'
             # --set-file "oathkeeper.mutatorIdTokenJWKs=$y" 

        verify() { 
            t="$(mktemp).yml" && helm upgrade --dry-run --debug --install oathkeeper ory/oathkeeper -n auth --create-namespace -f ory-oathkeeper/helm-values.yml -f ory-oathkeeper/oathkeeper-config.yml --set-file 'oathkeeper.accessRules=./ory-oathkeeper/oathkeeper-access-rules.json' > $t && printf "generated manifest with replaced env variables: file://$t\n"

            oathkeeper rules validate --file ory-oathkeeper/oathkeeper-access-rules.json

            curl -i https://auth.wosoom.com/authorize/health/alive
            curl -i https://auth.wosoom.com/authorize/health/ready
            curl https://auth.wosoom.com/authorize/.well-known/jwks.json | jq

            kubectl run -it --rm --image=nicolaka/netshoot debug-pod --namespace auth -- /bin/bash
            {
                curl  http://hydra-public/.well-known/jwks.json | jq # public keys used to verify JWT tokens
                curl http://oathkeeper-api/rules | jq "."
                curl http://hydra-admin/admin/clients | jq
            }

            curl -i https://api.wosoom.com/p/ 
            curl -H "Accept: text/html" -X GET https://api.wosoom.com/p/ 

            # NOTE: gaining authorization code process requires a browser or tool that handles consent
            # NOTE: SDK libraries for Oauth and OIDC compose requests better
            # initiate login flow and redirect to login page
            printf "visit in browser %s" "https://auth.wosoom.com/authorize/oauth2/auth?client_id=frontend-client&response_type=code%20id_token&scope=offline_access%20openid&redirect_url=https://wosoom.com/&state=some_random_string&nonce=some_other_random_string"
            # using the other client
            printf "visit in browser %s" "https://auth.wosoom.com/authorize/oauth2/auth?client_id=frontend-client-oauth&response_type=code&scope=offline_access%20openid&redirect_url=https://wosoom.com&state=some_random_string&nonce=some_random_str"
            # [manual] following the process should redirect after login with the authorization code provided in the URL
            {
                # typically would run from within the cluster using the backend server of the frontend ui application (must be secure as it contains client secret)
                # EXAMPLE for usage with client_secret_post

                CLIENT_ID="frontend-client-oauth"
                CLIENT_SECRET="WHdvNml2UkpBZmk3Q1pyQ3k5VHJKS1BNTFVMd3BoNkk="
                AUTHORIZATION_CODE="ory_ac_OKO7yH2ONi0aA1iAU2mFBatT6QAGF2wrkKEXUlmT71w.exdzV6GyFy57zHy2ox2HD_HRBalGOL6KCVWsBS55_0Y"  # [manually eplace this] update the code from the result redirect url parameter
                REDIRECT_URI="https://wosoom.com"

                # Execute the curl request
                tokens_payload=$(curl -k -s --request POST \
                    --url https://auth.wosoom.com/authorize/oauth2/token \
                    --header "accept: application/x-www-form-urlencoded" \
                    --form "grant_type=authorization_code" \
                    --form "code=${AUTHORIZATION_CODE}" \
                    --form "redirect_uri=${REDIRECT_URI}" \
                    --form "client_id=${CLIENT_ID}" \
                    --form "client_secret=${CLIENT_SECRET}" \
                    --form "scope=offline_access openid" | jq)
                
                ACCESS_TOKEN=$(echo $tokens_payload | jq -r '.access_token')
                REFRESH_TOKEN=$(echo $tokens_payload | jq -r '.refresh_token')
                ID_TOKEN=$(echo $tokens_payload | jq -r '.id_token')


                example_for_client_secret_basic_method() { 
                    CLIENT_ID="frontend-client-oauth"
                    CLIENT_SECRET="MEhmcEoyVXc5Y3RDcXlQZndkZ1A2WXZsazdVNHZ2OHM="
                    AUTHORIZATION_CODE="ory_ac_aMKwa8sp41LARkYAUn9XdV6ll_XSWz5TE6TGR9ge8jw.YkU6W-aX8Zs5KkG0RS9zHSHAbYhcNbWNXWU-fhmOxUc" 
                    REDIRECT_URI="https://wosoom.com"
                    # Base64 encode the client ID and secret
                    BASE64_CREDENTIALS=$(echo -n "${CLIENT_ID}:${CLIENT_SECRET}" | base64 -w 0)
                    echo $BASE64_CREDENTIALS
                    # Construct the curl command
                    curl -i -k -X POST \
                        -H "Content-Type: application/x-www-form-urlencoded" \
                        -H "Authorization: Basic ${BASE64_CREDENTIALS}" \
                        -d "grant_type=authorization_code" \
                        -d "code=${AUTHORIZATION_CODE}" \
                        -d "redirect_uri=${REDIRECT_URI}" \
                        https://auth.wosoom.com/authorize/oauth2/token
                }

                # use token to access restricted endpoint 
                curl -i -k -H "Authorization: Bearer $ACCESS_TOKEN" https://api.wosoom.com

                # request refresh token 
                curl -k -i --request POST \
                    --url https://auth.wosoom.com/authorize/oauth2/token \
                    --header "accept: application/x-www-form-urlencoded" \
                    --form "grant_type=refresh_token" \
                    --form "refresh_token=${REFRESH_TOKEN}" \
                    --form "redirect_uri=${REDIRECT_URI}" \
                    --form "client_id=${CLIENT_ID}"  \
                    --form "client_secret=${CLIENT_SECRET}" \
                    --form "scope=offline_access openid"
            }
        }

        popd
    }

create_oauth2_client_for_trusted_app() {
        pushd ./manifest/auth

        example_hydra_admin() { 
            kubectl run -it --rm --image=debian:latest debug-pod --namespace auth -- /bin/bash
            {
                # install hydra
                apt update && apt install curl jq -y
                bash <(curl https://raw.githubusercontent.com/ory/meta/master/install.sh) -d -b . hydra v2.2.0 && mv hydra /usr/bin/

                curl http://hydra-admin/admin/clients | jq

                delete_all_clients() { 
                    client_list=$(curl -X GET 'http://hydra-admin/admin/clients' | jq -r '.[].client_id')
                    for client in $client_list
                    do
                        echo "Deleting client: $client"
                        curl -X DELETE "http://hydra-admin/admin/clients/$client"
                    done
                }
            }

            hydra list oauth2-clients --endpoint "http://hydra-admin"
        }

        # port-forward hydra-admin 
        # kpf -n auth services/hydra-admin 4445:4445

        kubectl run --image=debian:latest setup-pod --namespace auth -- /bin/sh -c "while true; do sleep 60; done"
        kubectl wait --for=condition=ready pod/setup-pod --namespace=auth --timeout=300s

        {
                        t="$(mktemp).sh" && cat << 'EOF' > $t
#!/bin/bash
apt update && apt install curl jq -y
bash <(curl https://raw.githubusercontent.com/ory/meta/master/install.sh) -d -b . hydra v2.2.0 && mv hydra /usr/bin/
curl -s http://hydra-admin/admin/clients | jq
EOF
            kubectl cp $t setup-pod:$t --namespace auth
            kubectl exec -it setup-pod --namespace auth -- /bin/sh -c "chmod +x $t && $t"
        }
        
        {

            # app client users for trusted app

            example_using_hydra() { 
                t="$(mktemp).sh" && cat << 'EOF' > $t
#!/bin/bash
hydra create oauth2-client --name frontend-client-2 --audience backend-service --endpoint http://hydra-admin --grant-type authorization_code,refresh_token --response-type code --redirect-uri https://wosoom.com --scope offline_access,openid --skip-consent --skip-logout-consent --token-endpoint-auth-method client_secret_post
EOF
                kubectl cp $t setup-pod:$t --namespace auth
                kubectl exec -it setup-pod --namespace auth -- /bin/bash -c "chmod +x $t && $t"
            }


            # redirect uri is where the resource owner (user) will be redirected to once the authorization server grants permission to the client
            # NOTE: using the `authorization code` the client gets both `accesst token` and `id token` when `scope` includes `openid`.
            client_secret="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | base64 -w 0)" 
            client_exist=$(curl -s 'http://hydra-admin/admin/clients' | jq -r '.[] | select(.client_id=="frontend-client") | .client_id')
            t="$(mktemp).sh" && cat << EOF > $t
#!/bin/bash

client_exist=\$(curl -s 'http://hydra-admin/admin/clients' | jq -r '.[] | select(.client_id=="frontend-client") | .client_id')

if [[ -z "\$client_exist" ]]; then
echo 'Adding oauth2 client'

curl -X POST 'http://hydra-admin/admin/clients' -H 'Content-Type: application/json' \
    --data '{
        "client_id": "frontend-client",
        "client_name": "frontend-client",
        "client_secret": "${client_secret}",
        "grant_types": ["authorization_code", "refresh_token"],
        "response_types": ["code id_token"],
        "redirect_uris": ["https://wosoom.com"], 
        "audience": ["https://wosoom.com"],    
        "scope": "offline_access openid",
        "token_endpoint_auth_method": "client_secret_post",
        "skip_consent": true,
        "skip_logout_prompt": true,
        "post_logout_redirect_uris": []
    }'
fi
EOF
            kubectl cp $t setup-pod:$t --namespace auth
            kubectl exec -it setup-pod --namespace auth -- /bin/sh -c "chmod +x $t && $t"
            # create/update secret 
            if [[ -z "$client_exist" ]]; then
                kubectl create secret generic ory-hydra-client--frontend-client -n auth --from-literal=client_secret="$client_secret" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null
            fi

            example_alternative_option() {
                # TODO: incomplete example
                # https://www.ory.sh/docs/hydra/self-hosted/quickstart
                hydra create client \
                    --endpoint http://hydra-admin \
                    --grant-type authorization_code,refresh_token \
                    --response-type code,id_token \
                    --format json \
                    --scope openid --scope offline \
                    --redirect-uri https://wosoom.com/ --token-endpoint-auth-method none

                code_client_id=$(echo $code_client | jq -r '.client_id')
                code_client_secret=$(echo $code_client | jq -r '.client_secret')
            }

        }
        {

            client_secret="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | base64 -w 0)" 
            client_exist=$(curl -s 'http://hydra-admin/admin/clients' | jq -r '.[] | select(.client_id=="frontend-client-oauth") | .client_id')
            t="$(mktemp).sh" && cat << EOF > $t
#!/bin/bash

client_exist=\$(curl -s 'http://hydra-admin/admin/clients' | jq -r '.[] | select(.client_id=="frontend-client-oauth") | .client_id')

if [[ -z "\$client_exist" ]]; then
echo 'Adding oauth2 client'

curl -X POST 'http://hydra-admin/admin/clients' -H 'Content-Type: application/json' \
    --data '{
        "client_id": "frontend-client-oauth",
        "client_name": "frontend-client-oauth",
        "client_secret": "${client_secret}",
        "grant_types": ["authorization_code", "refresh_token"],
        "response_types": ["code"],
        "redirect_uris": ["https://wosoom.com"], 
        "audience": ["https://wosoom.com"],    
        "scope": "offline_access openid",
        "token_endpoint_auth_method": "client_secret_post",
        "skip_consent": true,
        "skip_logout_prompt": true,
        "post_logout_redirect_uris": []
    }'
fi
EOF
            kubectl cp $t setup-pod:$t --namespace auth
            kubectl exec -it setup-pod --namespace auth -- /bin/sh -c "chmod +x $t && $t"
            # create/update secret 
            if [[ -z "$client_exist" ]]; then
                kubectl create secret generic ory-hydra-client--frontend-client-oauth -n auth --from-literal=client_secret="$client_secret" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null
            fi

            example_alternative_option() {
                # TODO: incomplete example
                # https://www.ory.sh/docs/hydra/self-hosted/quickstart
                hydra create client \
                    --endpoint http://hydra-admin \
                    --grant-type authorization_code,refresh_token \
                    --response-type code,id_token \
                    --format json \
                    --scope openid --scope offline \
                    --redirect-uri https://wosoom.com/ --token-endpoint-auth-method none

                code_client_id=$(echo $code_client | jq -r '.client_id')
                code_client_secret=$(echo $code_client | jq -r '.client_secret')
            }

        }

        {
            # internal service communication
            client_secret="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | base64 -w 0)" 
            client_exist=$(curl -s 'http://hydra-admin/admin/clients' | jq -r '.[] | select(.client_id=="internal-communication") | .client_id')
            t="$(mktemp).sh" && cat << EOF > $t
#!/bin/bash

client_exist=\$(curl -s 'http://hydra-admin/admin/clients' | jq -r '.[] | select(.client_id=="internal-communication") | .client_id')

if [[ -z "\$client_exist" ]]; then
echo 'Adding oauth2 client'

curl -X POST 'http://hydra-admin/admin/clients' -H 'Content-Type: application/json' \
    --data '{
        "client_id": "internal-communication",
        "client_name": "internal-communication",
        "client_secret": "${client_secret}",
        "grant_types": ["client_credentials"],
        "response_types": [],
        "redirect_uris": ["https://wosoom.com"], 
        "audience": ["internal-service", "external-service"],
        "scope": "offline_access openid custom_scope:read",
        "token_endpoint_auth_method": "client_secret_basic",
        "skip_consent": false,
        "post_logout_redirect_uris": [],
        "skip_logout_prompt": false
    }'                      

fi

EOF
            kubectl cp $t setup-pod:$t --namespace auth
            kubectl exec -it setup-pod --namespace auth -- /bin/sh -c "chmod +x $t && $t"
            # create/update secret 
            if [[ -z "$client_exist" ]]; then
                kubectl create secret generic ory-hydra-client--internal-communication -n auth --from-literal=internal-communication="$client_secret" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null
            fi 

        }



        {
            # Oathkeeper introspection
            client_secret="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | base64 -w 0)" 
            client_exist=$(curl -s 'http://hydra-admin/admin/clients' | jq -r '.[] | select(.client_id=="oathkeeper-introspection") | .client_id')
            t="$(mktemp).sh" && cat << EOF > $t
#!/bin/bash

client_exist=\$(curl -s 'http://hydra-admin/admin/clients' | jq -r '.[] | select(.client_id=="oathkeeper-introspection") | .client_id')

if [[ -z "\$client_exist" ]]; then
echo 'Adding oauth2 client'

curl -X POST 'http://hydra-admin/admin/clients' -H 'Content-Type: application/json' \
    --data '{
        "client_id": "oathkeeper-introspection",
        "client_name": "oathkeeper-introspection",
        "client_secret": "${client_secret}",
        "grant_types": ["client_credentials"],
        "response_types": ["token"],
        "audience": ["internal-service"],
        "scope": "introspect",
        "token_endpoint_auth_method": "client_secret_basic"
    }'                     
fi
EOF
            kubectl cp $t setup-pod:$t --namespace auth
            kubectl exec -it setup-pod --namespace auth -- /bin/sh -c "chmod +x $t && $t"
            # create/update secret 
            if [[ -z "$client_exist" ]]; then
                kubectl create secret generic ory-hydra-client--oathkeeper-introspection -n auth --from-literal=oathkeeper-introspection="$client_secret" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null
            fi 

        }
        
        kubectl delete --force pod setup-pod -n auth > /dev/null 2>&1


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
        #     "audience": ["external-service"],
        #     "scope": "offline_access openid custom_scope:read",
        #     "token_endpoint_auth_method": "client_secret_post",
        #     "skip_consent": false,
        #     "post_logout_redirect_uris": [],
        #     "skip_logout_prompt": false
        # }'

        manual_verify() { 
            kubectl run -it --rm --image=nicolaka/netshoot debug-pod --namespace auth -- curl http://hydra-admin/admin/clients | jq
            kubectl run -it --rm --image=nicolaka/netshoot debug-pod --namespace auth -- curl http://hydra-admin/admin/clients/frontend-client | jq
        }

        popd
    }

    install_keto() {
        pushd ./manifest/auth
        
        printf "install Postgresql for Ory Keto \n"
        set -a
        source ory-keto/db_keto_secret.env # DB_USER, DB_PASSWORD
        set +a
        helm upgrade --reuse-values --install postgres-keto bitnami/postgresql -n auth --create-namespace -f ory-keto/postgresql-values.yml \
            --set auth.username=${DB_USER} \
            --set auth.password=${DB_PASSWORD} \
            --set auth.database=keto_db
        # this will generate 'postgres-keto-postgresql' service

        printf "install Ory Keto \n"
        # preprocess file through substituting env values
        t="$(mktemp).yml" && envsubst < ory-keto/keto-config.yml > $t && printf "generated manifest with replaced env variables: file://$t\n" 
        helm upgrade --install keto ory/keto -n auth --create-namespace -f ory-keto/helm-values.yml -f $t \
            --set env[0].name=DB_USER --set env[0].value=${DB_USER} \
            --set env[0].name=DB_PASSWORD --set env[0].value=${DB_PASSWORD}

        {
            printf "Keto: create relations rules \n"
            
            kubectl run --image=debian:latest setup-pod-keto --namespace auth -- /bin/sh -c "while true; do sleep 60; done"
            kubectl wait --for=condition=ready pod/setup-pod-keto --namespace=auth --timeout=300s

            {
                t="$(mktemp).sh" && cat << 'EOF' > $t
#!/bin/bash
apt update && apt install curl jq -y
bash <(curl https://raw.githubusercontent.com/ory/meta/master/install.sh) -d -b . keto v0.12.0-alpha.0 && chmod +x ./keto && mv ./keto /usr/bin/

# keto --read-remote http://keto-read --write-remote http://keto-write relation-tuple get
EOF
                kubectl cp $t setup-pod-keto:$t --namespace auth
                kubectl exec -it setup-pod-keto --namespace auth -- /bin/sh -c "chmod +x $t && $t"
            }
            {
                t="$(mktemp).sh" && cat << 'EOF' > $t
#!/bin/bash

# keto relation-tuple create --namespace="resources" --object="resources:xyz" --relation="read" --subject="{{ .AuthenticationSession.Subject }}" --flavor="keto"

EOF
                kubectl cp $t setup-pod-keto:$t --namespace auth
                kubectl exec -it setup-pod-keto --namespace auth -- /bin/sh -c "chmod +x $t && $t"
            }

            kubectl delete --force pod setup-pod-keto -n auth > /dev/null 2>&1
        }

        verify() {
            alias keto="docker run -it --network cat-videos-example_default -e KETO_READ_REMOTE=\"keto:4466\" oryd/keto:v0.7.0-alpha.1"

            http PUT http://keto.example.com/write/relation-tuples namespace=access object=administration relation=access subject_id=admin
            http PUT http://keto.example.com/write/relation-tuples namespace=access object=application relation=access subject_id=admin
            http PUT http://keto.example.com/write/relation-tuples namespace=access object=application relation=access subject_id=user

            # check
            http -b http://keto.example.com/read/check namespace=access object=administration relation=access subject_id=admin
            # {
            #     "allowed": true
            # }
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
    install_keto
    create_oauth2_client_for_trusted_app
    install_oathkeeper # depends on `create_oauth2_client_for_trusted_app`


    manual_verify() { 
        # use --debug with `helm` for verbose output
        
        # tunnel to remote service 
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

# https://gateway.envoyproxy.io/docs/install/install-helm/
install_envoy_gateway() {
    pushd ./manifest/envoy_proxy
    
    action=${1:-"install"}
    {
        if [ "$action" == "delete" ]; then
            # permit forceful deletion of gatewayclass
            kubectl patch gatewayclass envoy-internal -n envoy-gateway-system -p '{"metadata":{"finalizers":[]}}' --type=merge 
            kubectl delete gatewayclass envoy-internal -n envoy-gateway-system # --force
            helm delete envoy-gateway -n envoy-gateway-system
            return 
        fi
    }

    install_gateway_class() {
        # install CRDs (NOTE: Helm doesn't update CRDs already installed - manual upgrade would be required)
        # https://gateway.envoyproxy.io/docs/tasks/traffic/gatewayapi-support/
        helm upgrade --install envoy-gateway oci://docker.io/envoyproxy/gateway-helm --version v1.2.6 -n envoy-gateway-system --create-namespace -f ./helm-values.yml
        kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available    

        t="$(mktemp).yml" && cat << 'EOF' > $t
# customize EnvoyProxy CRD https://gateway.envoyproxy.io/docs/api/extension_types/
# This configurations creates a service as ClusterIP preventing assigning external IP address to it
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: envoy-proxy-config-internal
  namespace: envoy-gateway-system
spec:
  provider:
    type: Kubernetes
    kubernetes:
      envoyService:
        annotations:
            load-balancer.hetzner.cloud/disable: "true" # additional config from kube-hetzner module's loadbalancer controller
        type: ClusterIP  # Use ClusterIP instead of LoadBalancer (making the gateway internal only)
---
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy-internal
  namespace: envoy-gateway-system
spec:
    controllerName: gateway.envoyproxy.io/gatewayclass-controller-internal
    parametersRef:
        group: gateway.envoyproxy.io
        kind: EnvoyProxy
        name: envoy-proxy-config-internal
        namespace: envoy-gateway-system
EOF

        kubectl apply -f $t -n envoy-gateway-system

        verify() { 
            # check schema
            kubectl get crd envoyproxies.config.gateway.envoyproxy.io -o yaml
            kubectl explain envoyproxy.spec.provider.kubernetes
        }
    }

    install_gateway_class

    verify() {
        helm status envoy-gateway -n envoy-gateway-system
        y="$(mktemp).yml" && helm get all envoy-gateway -n envoy-gateway-system > $y && printf "rendered manifest template: file://$y\n"  # code -n $y


        {
            t="$(mktemp).sh" && cat << 'EOF' > $t
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: envoy-gateway
spec:
  gatewayClassName: envoy
  listeners:
    - name: http
      protocol: HTTP
      port: 80
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  labels:
    app: backend
    service: backend
spec:
  ports:
    - name: http
      port: 3000
      targetPort: 3000
  selector:
    app: backend
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
      version: v1
  template:
    metadata:
      labels:
        app: backend
        version: v1
    spec:
      serviceAccountName: backend
      containers:
        - image: gcr.io/k8s-staging-gateway-api/echo-basic:v20231214-v1.0.0-140-gf544a46e
          imagePullPolicy: IfNotPresent
          name: backend
          ports:
            - containerPort: 3000
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: backend
spec:
  parentRefs:
    - name: envoy-gateway
  hostnames:
    - "www.example.com"
  rules:
    - backendRefs:
        - group: ""
          kind: Service
          name: backend
          port: 3000
          weight: 1
      matches:
        - path:
            type: PathPrefix
            value: /

EOF
            kubectl apply -f $t -n envoy-gateway-system

            export GATEWAY_HOST=$(kubectl get gateway/envoy-gateway -n envoy-gateway-system -o jsonpath='{.status.addresses[0].value}')
            curl --verbose --header "Host: www.example.com" http://$GATEWAY_HOST/get

            kubectl delete -f $t -n envoy-gateway-system --ignore-not-found=true
        }
    }
    popd
}

deploy_application() {
    action=${1:-"install"}

    {
        if [ "$action" == "delete" ]; then
            kubectl delete -k ./manifest/entrypoint/production
            return 
        fi
    }

    pushd ./manifest 
        kubectl apply -k ./entrypoint/production
        {
            pushd ./entrypoint/production 
            t="$(mktemp).yml" && kubectl kustomize ./ > $t && printf "rendered manifest template: file://$t\n"  # code -n $t
            popd
        }
    popd 
}

restart_cilinium() { 
    kubectl -n kube-system rollout restart deployment/cilium-operator
    kubectl -n kube-system rollout restart ds/cilium
}

kustomize_kubectl() {
    action=${1:-"install"} && shift

    if ! command -v kubectl-ctx &> /dev/null; then
        echo "kubectl ctx is not installed. Exiting."
        return
    fi

    kubectl ctx k3s
    env_files

    {
        if [ "$action" == "delete" ]; then
            install_ory_stack delete
            install_envoy_gateway delete
            deploy_application delete
            return 
         elif [ "$action" == "kustomize" ]; then
            pushd manifest/entrypoint/production 
            t="$(mktemp).yml" && kubectl kustomize ./ > $t && printf "rendered manifest template: file://$t\n"  # code -n $t
            popd
            return
         elif [ "$action" == "app" ]; then
            deploy_application
            return
        elif [ "$action" != "install" ]; then
            # Call the function based on the argument
            if declare -f "$action" > /dev/null; then
                "$action" "$@" # Call the function
                return
            else
                echo "Unknown action: $action"
                return 
            fi
        fi
    }

    install_ory_stack
    install_envoy_gateway
    deploy_application
    
    echo "Services deployed to the cluster (wait few minutes to complete startup and propagate TLS certificate generation)."

    _fix() { 
        restart_cilinium  # [issue] restarting fixs gateway has no ip assignment by controller
    }
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

        kubectl get nodes --show-labels

        # cert-manager related 
        # two issuers: staging & production issuers 
        # ephemeral challenge appearing during certificate issuance process 
        # certificate should be READY = True
        # order: should be STATE = pending → STATE = valid
        kubectl get clusterissuer,certificate,order,challenge -A 
        kubectl get gateway,httproute,crds -A 
        kubectl describe gateway -n gateway

        # check dns + web server response with tls staging certificate
        domain_name=""
        curl -i http://$domain_name
        curl --insecure -I https://$domain_name
        cloud_load_balancer_ip=""
        curl -i --header "Host: donation-app.com" $cloud_load_balancer_ip
        kubectl logs -n kube-system deployments/cilium-operator | grep gateway

        # run ephemeral debug container
        kubectl run -it --rm --image=nicolaka/netshoot debug-pod --namespace some_namespace -- /bin/bash 
        kubectl run -it --rm --image=busybox debug-pod-2 --namespace auth -- /bin/bash nslookup oathkeeper-proxy
        
        kubectl -n kube-system edit configmap cilium-config
    }

}


### example and verification
{
    example_test_cilium() { 

        cilium config view | grep -w "enabe-gateway-api"
    }
}
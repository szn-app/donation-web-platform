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
    cookie_secret="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)" 
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
            # install dependencies including Hydra
            {
                apt update && apt install curl jq -y
                bash <(curl https://raw.githubusercontent.com/ory/meta/master/install.sh) -d -b . hydra v2.2.0 && mv hydra /usr/bin/
            }


            curl -s http://hydra-admin/admin/clients | jq

            # https://www.ory.sh/docs/hydra/self-hosted/quickstart
            # [OAuth 2.0] create client and perform "clients credentials" grant
            {
                client=$(hydra create client --endpoint http://hydra-admin--format json --grant-type client_credentials)
                # parse the JSON response using jq to get the client ID and client secret:
                client_id=$(echo $client | jq -r '.client_id')
                client_secret=$(echo $client | jq -r '.client_secret')

                # perform client credentials grant
                CREDENTIALS_GRANT=$(hydra perform client-credentials --endpoint http://hydra-public/ --client-id "$client_id" --client-secret "$client_secret")
                printf "%s\n" "$CREDENTIALS_GRANT"
                TOKEN=$(printf "%s\n" "$CREDENTIALS_GRANT" | grep "ACCESS TOKEN" | awk '{if($1 == "ACCESS" && $2 == "TOKEN") {print $3}}')

                # token introspection 
                hydra introspect token --format json-pretty --endpoint http://hydra-admin$TOKEN
                { # test envoy gateway + oathkeeper as external authorization  
                    # introspects http://oathkeeper-api:80/decisions
                    curl -i -k -H "Authorization: Bearer $TOKEN" https://test.wosoom.com/oauth-header 
                }
            }

            # [OAuth 2.0] user "Code" grant 
            {
                # example of public client which cannot provide client secrets (authentication flow only using client id )
                code_client=$(hydra create client --endpoint http://hydra-admin --grant-type authorization_code,refresh_token --response-type code,id_token --format json --scope openid --scope offline --redirect-uri http://hydra-public/callback --token-endpoint-auth-method none)
                code_client=$(hydra create client --endpoint http://hydra-admin --grant-type authorization_code,refresh_token --response-type code,id_token --format json --scope openid --scope offline --redirect-uri http://hydra-public/callback)
                code_client_id=$(echo $code_client | jq -r '.client_id')
                code_client_secret=$(echo $code_client | jq -r '.client_secret')
                # perform Authorization Code flow to grant Code 
                hydra perform authorization-code --port 5555 --client-id $code_client_id --endpoint http://hydra-admin--scope openid --scope offline
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
    
    example_using_hydra() { 
        t="$(mktemp).sh" && cat << 'EOF' > $t
#!/bin/bash
hydra create oauth2-client --name frontend-client-2 --audience backend-service --endpoint http://hydra-admin --grant-type authorization_code,refresh_token --response-type code --redirect-uri https://wosoom.com --scope offline_access,openid --skip-consent --skip-logout-consent --token-endpoint-auth-method client_secret_post
EOF
        kubectl cp $t setup-pod:$t --namespace auth
        kubectl exec -it setup-pod --namespace auth -- /bin/bash -c "chmod +x $t && $t"
    }

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

    {

        # app client users for trusted app

        # redirect uri is where the resource owner (user) will be redirected to once the authorization server grants permission to the client
        # NOTE: using the `authorization code` the client gets both `accesst token` and `id token` when `scope` includes `openid`.
        client_name="frontend-client"
        client_secret="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | base64 -w 0)"
        client_exist=$(kubectl exec -it setup-pod --namespace auth -- curl -s 'http://hydra-admin/admin/clients' | jq -r ".[] | select(.client_id==\"$client_name\") | .client_id")

        if [[ -z "$client_exist" ]]; then
            echo 'Adding oauth2 client'

            t="$(mktemp).sh" && cat << EOF > $t
#!/bin/bash

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
    "skip_logout_consent": true,
    "post_logout_redirect_uris": []
}'

EOF
            kubectl cp $t setup-pod:$t --namespace auth
            kubectl exec -it setup-pod --namespace auth -- /bin/sh -c "chmod +x $t && $t"
            # create/update secret 
            kubectl create secret generic ory-hydra-client--frontend-client -n auth --from-literal=client_secret="$client_secret" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null
        fi

    }
    {

        client_name="frontend-client-oauth"
        client_secret="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | base64 -w 0)"
        client_exist=$(kubectl exec -it setup-pod --namespace auth -- curl -s 'http://hydra-admin/admin/clients' | jq -r ".[] | select(.client_id==\"$client_name\") | .client_id")

        if [[ -z "$client_exist" ]]; then
            echo 'Adding oauth2 client'
        
            t="$(mktemp).sh" && cat << EOF > $t
#!/bin/bash

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
    "skip_logout_consent": true,
    "post_logout_redirect_uris": []
}'
EOF
            kubectl cp $t setup-pod:$t --namespace auth
            kubectl exec -it setup-pod --namespace auth -- /bin/sh -c "chmod +x $t && $t"
            # create/update secret 
            kubectl create secret generic ory-hydra-client--frontend-client-oauth -n auth --from-literal=client_secret="$client_secret" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null
        fi

    }

    {
        client_name="frontend-client-oauth-consent"
        client_secret="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | base64 -w 0)"
        client_exist=$(kubectl exec -it setup-pod --namespace auth -- curl -s 'http://hydra-admin/admin/clients' | jq -r ".[] | select(.client_id==\"$client_name\") | .client_id")
        
        if [[ -z "$client_exist" ]]; then
            echo 'Adding oauth2 client'
            
            t="$(mktemp).sh" && cat << EOF > $t
#!/bin/bash

curl -X POST 'http://hydra-admin/admin/clients' -H 'Content-Type: application/json' \
--data '{
    "client_id": "frontend-client-oauth-consent",
    "client_name": "frontend-client-oauth-consent",
    "client_secret": "${client_secret}",
    "grant_types": ["authorization_code", "refresh_token"],
    "response_types": ["code id_token"],
    "redirect_uris": ["https://wosoom.com"], 
    "audience": ["https://wosoom.com"],    
    "scope": "offline_access openid",
    "token_endpoint_auth_method": "client_secret_post",
    "skip_consent": false,
    "skip_logout_consent": true,
    "post_logout_redirect_uris": []
}'
EOF
            kubectl cp $t setup-pod:$t --namespace auth
            kubectl exec -it setup-pod --namespace auth -- /bin/sh -c "chmod +x $t && $t"
            # create/update secret 
            kubectl create secret generic ory-hydra-client--frontend-client-oauth-consent -n auth --from-literal=client_secret="$client_secret" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null
        fi
    }

    {
        # internal service communication
        client_name="internal-communication"
        client_secret="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | base64 -w 0)"
        client_exist=$(kubectl exec -it setup-pod --namespace auth -- curl -s 'http://hydra-admin/admin/clients' | jq -r ".[] | select(.client_id==\"$client_name\") | .client_id")

        if [[ -z "$client_exist" ]]; then
            echo 'Adding oauth2 client'
    
            t="$(mktemp).sh" && cat << EOF > $t
#!/bin/bash

curl -X POST 'http://hydra-admin/admin/clients' -H 'Content-Type: application/json' \
--data '{
    "client_id": "internal-communication",
    "client_name": "internal-communication",
    "client_secret": "${client_secret}",
    "grant_types": ["client_credentials"],
    "response_types": [],
    "redirect_uris": ["https://wosoom.com"], 
    "audience": ["internal-service", "external-service"],
    "scope": "offline_access openid email profile",
    "token_endpoint_auth_method": "client_secret_basic",
    "skip_consent": false,
    "post_logout_redirect_uris": [],
    "skip_logout_consent": false
}'                      

EOF
            kubectl cp $t setup-pod:$t --namespace auth
            kubectl exec -it setup-pod --namespace auth -- /bin/sh -c "chmod +x $t && $t"
            # create/update secret 
            kubectl create secret generic ory-hydra-client--internal-communication -n auth --from-literal=client_secret="$client_secret" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null
        fi 

    }



    {
        # Oathkeeper introspection
        client_name="oathkeeper-introspection"
        client_secret="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | base64 -w 0)"
        client_exist=$(kubectl exec -it setup-pod --namespace auth -- curl -s 'http://hydra-admin/admin/clients' | jq -r ".[] | select(.client_id==\"$client_name\") | .client_id")
        
        if [[ -z "$client_exist" ]]; then
            echo 'Adding oauth2 client'

            t="$(mktemp).sh" && cat << EOF > $t
#!/bin/bash

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
EOF
            kubectl cp $t setup-pod:$t --namespace auth
            kubectl exec -it setup-pod --namespace auth -- /bin/sh -c "chmod +x $t && $t"
            # create/update secret 
            kubectl create secret generic ory-hydra-client--oathkeeper-introspection -n auth --from-literal=client_secret="$client_secret" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null
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
    #     "skip_logout_consent": false
    # }'

    manual_verify() { 
        kubectl run -it --rm --image=nicolaka/netshoot debug-pod --namespace auth -- curl http://hydra-admin/admin/clients | jq
        kubectl run -it --rm --image=nicolaka/netshoot debug-pod --namespace auth -- curl http://hydra-admin/admin/clients/frontend-client | jq
    }

    popd
}

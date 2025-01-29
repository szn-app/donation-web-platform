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

### usecases: 
# Examples of Oathkeeper validation setups possible: 
#   a. JWT stored in a cookie
#   b. Kratos session token
#   c. Hydra OAuth2 access token in a cookie
install_oathkeeper() {

    generate_oathkeeper_oauth2_client_credentials_env_file() {
        pushd ./manifest/auth
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
        popd
    }

    # used also to update access rules
    helm_install_oathkeeper() {
        pushd ./manifest/auth
        set -a
        source ory-oathkeeper/secret.env 
        set +a

        # t="$(mktemp).pem" && openssl genrsa -out "$t" 2048 # create private key
        # # Generate a JWKs file (if needed) - basic example using OpenSSL:
        # y="$(mktemp).json" && openssl rsa -in "$t" -pubout -outform PEM > $y 
        # echo "jwt file created file://$y"

        t="$(mktemp).yml" && envsubst < ory-oathkeeper/oathkeeper-config.yml > $t && printf "generated manifest with replaced env variables: file://$t\n" 
        helm upgrade --install oathkeeper ory/oathkeeper -n auth --create-namespace -f ory-oathkeeper/helm-values.yml -f $t \
                --set-file oathkeeper.accessRules=./ory-oathkeeper/access-rules.json
                # --set-file "oathkeeper.mutatorIdTokenJWKs=$y" 
        popd
    }

    printf "install Ory Aothkeeper \n"
    generate_oathkeeper_oauth2_client_credentials_env_file
    helm_install_oathkeeper

    verify() { 
        pushd ./manifest/auth
        {
            # manually validate rendered deployment manifest files
            t="$(mktemp).yml" && helm upgrade --dry-run --debug --install oathkeeper ory/oathkeeper -n auth --create-namespace -f ory-oathkeeper/helm-values.yml -f ory-oathkeeper/oathkeeper-config.yml --set-file 'oathkeeper.accessRules=./ory-oathkeeper/access-rules.json' > $t && printf "generated manifest with replaced env variables: file://$t\n"
        }

        oathkeeper rules validate --file ory-oathkeeper/access-rules.json

        curl -i https://auth.wosoom.com/authorize/health/alive
        curl -i https://auth.wosoom.com/authorize/health/ready
        curl https://auth.wosoom.com/authorize/.well-known/jwks.json | jq

        kubectl run -it --rm --image=nicolaka/netshoot debug-pod --namespace auth -- /bin/bash
        {
            curl  http://hydra-public/.well-known/jwks.json | jq # public keys used to verify JWT tokens
            curl http://oathkeeper-api/rules | jq "."
            curl http://hydra-admin/admin/clients | jq
        }

        curl -k -i https://test.wosoom.com/allow/ 
        curl -k -i -H "Accept: text/html" -X GET https://test.wosoom.com/allow/ 

        # NOTE: gaining authorization code process requires a browser or tool that handles consent; SDK libraries for Oauth and OIDC compose requests better
        oauth2_flow() { 
            # initiate login flow and redirect to login page
            # following the process should redirect after login with the authorization code provided in the URL
            {
                {
                    printf "visit in browser %s" "https://auth.wosoom.com/authorize/oauth2/auth?client_id=frontend-client&response_type=code%20id_token&scope=offline_access%20openid&redirect_uri=https://wosoom.com&state=some_random_string&nonce=some_other_random_string"

                    # typically would run from within the cluster using the backend server of the frontend ui application (must be secure as it contains client secret)
                    # EXAMPLE for usage with client_secret_post

                    CLIENT_ID="frontend-client"
                    # CLIENT_SECRET="$(kubectl get secret "ory-hydra-client--$CLIENT_ID" -n auth -o jsonpath='{.data.client_secret}')"
                    CLIENT_SECRET=""
                    # [manually eplace this] update the code from the result redirect url parameter after login
                    AUTHORIZATION_CODE=""
                    REDIRECT_URI="https://wosoom.com"
                }
                # or 
                {
                    printf "visit in browser %s" "https://auth.wosoom.com/authorize/oauth2/auth?client_id=frontend-client-oauth&response_type=code&scope=offline_access%20openid&redirect_uri=https://wosoom.com&state=some_random_string&nonce=some_random_str"

                    # typically would run from within the cluster using the backend server of the frontend ui application (must be secure as it contains client secret)
                    # EXAMPLE for usage with client_secret_post

                    CLIENT_ID="frontend-client-oauth"
                    # CLIENT_SECRET="$(kubectl get secret "ory-hydra-client--$CLIENT_ID" -n auth -o jsonpath='{.data.client_secret}')"
                    CLIENT_SECRET=""
                    # [manually eplace this] update the code from the result redirect url parameter after login
                    AUTHORIZATION_CODE=""
                    REDIRECT_URI="https://wosoom.com"
                }
            }

            # Execute the curl request
            # -v -s -o /dev/null  -k
            tokens_payload=$(curl -k -s --request POST --url https://auth.wosoom.com/authorize/oauth2/token --header "accept: application/x-www-form-urlencoded" \
                --form "grant_type=authorization_code" \
                --form "code=${AUTHORIZATION_CODE}" \
                --form "redirect_uri=${REDIRECT_URI}" \
                --form "client_id=${CLIENT_ID}" \
                --form "client_secret=${CLIENT_SECRET}" \
                --form "scope=offline_access openid" | jq)
            
            ACCESS_TOKEN=$(echo $tokens_payload | jq -r '.access_token')
            REFRESH_TOKEN=$(echo $tokens_payload | jq -r '.refresh_token')
            ID_TOKEN=$(echo $tokens_payload | jq -r '.id_token')

            curl -k -i --request POST --url http://hydra-admin/admin/oauth2/introspect --header "accept: application/x-www-form-urlencoded" --form "token=$ACCESS_TOKEN" 
            # access restricted endpoint through Envoy Gateway + Oauthkeeper as introspection (calls http://oathkeeper-admin:80/decisions)
            curl -i -k -H "Authorization: Bearer $ACCESS_TOKEN" https://test.wosoom.com/oauth-header

            # request refresh token 
            curl -k -i --request POST --url https://auth.wosoom.com/authorize/oauth2/token --header "accept: application/x-www-form-urlencoded" \
                --form "grant_type=refresh_token" \
                --form "refresh_token=${REFRESH_TOKEN}" \
                --form "redirect_uri=${REDIRECT_URI}" \
                --form "client_id=${CLIENT_ID}"  \
                --form "client_secret=${CLIENT_SECRET}" \
                --form "scope=offline_access openid"
        }

        # directly request token with Hydra Oauth2.0 client id+secret
        client_secret_basic_method() { 
            CLIENT_ID="internal-communication"
            # CLIENT_SECRET="$(kubectl get secret "ory-hydra-client--$CLIENT_ID" -n auth -o jsonpath="{.data.client_secret}")"
            CLIENT_SECRET="SFM2RzdneHN0RGIycno5Vmp2bElkbGpnMXpZVEVyMTk="
            REDIRECT_URI="https://wosoom.com"
            # Base64 encode the client ID and secret
            BASE64_CREDENTIALS=$(echo -n "${CLIENT_ID}:${CLIENT_SECRET}" | base64 -w 0)
            echo $BASE64_CREDENTIALS
            # Construct the curl command

            tokens_payload=$(curl -s -k -X POST \
                -H "Content-Type: application/x-www-form-urlencoded" \
                -H "Authorization: Basic ${BASE64_CREDENTIALS}" \
                -d "grant_type=client_credentials" \
                https://auth.wosoom.com/authorize/oauth2/token | jq)
            
            ACCESS_TOKEN=$(echo $tokens_payload | jq -r '.access_token')

            curl -k -i --request POST --url http://hydra-admin/admin/oauth2/introspect --header "accept: application/x-www-form-urlencoded" --form "token=$ACCESS_TOKEN" 
            # access restricted endpoint through Envoy Gateway + Oauthkeeper as introspection (calls http://oathkeeper-admin:80/decisions)
            curl -i -k -H "Authorization: Bearer $ACCESS_TOKEN" https://test.wosoom.com/oauth-header
        }
        
        popd
    }

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
            kubectl create secret generic ory-hydra-client--internal-communication -n auth --from-literal=client_secret="$client_secret" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null
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
    #     "skip_logout_prompt": false
    # }'

    manual_verify() { 
        kubectl run -it --rm --image=nicolaka/netshoot debug-pod --namespace auth -- curl http://hydra-admin/admin/clients | jq
        kubectl run -it --rm --image=nicolaka/netshoot debug-pod --namespace auth -- curl http://hydra-admin/admin/clients/frontend-client | jq
    }

    popd
}

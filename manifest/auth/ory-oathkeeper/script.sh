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
        SECRET_NAME="ory-hydra-client--oathkeeper-introspection"
        CLIENT_SECRET=$(kubectl get secret "$SECRET_NAME" -n "auth" -o jsonpath='{.data.client_secret}')

        if [[ -z "$CLIENT_SECRET" ]]; then
            printf "Error: generate_oathkeeper_oauth2_client_credentials_env_file@install_oathkeeper function depends on create_oauth2_client_for_trusted_app"
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

        curl -i https://auth.donation-app.test/authorize/health/alive
        curl -i https://auth.donation-app.test/authorize/health/ready
        curl https://auth.donation-app.test/authorize/.well-known/jwks.json | jq

        kubectl run -it --rm --image=nicolaka/netshoot debug-pod --namespace auth -- /bin/bash
        {
            curl  http://hydra-public/.well-known/jwks.json | jq # public keys used to verify JWT tokens
            curl http://oathkeeper-api/rules | jq "."
            curl http://hydra-admin/admin/clients | jq
        }

        curl -k -i https://test.donation-app.test/allow/ 
        curl -k -i -H "Accept: text/html" -X GET https://test.donation-app.test/allow/ 

        # NOTE: gaining authorization code process requires a browser or tool that handles consent; SDK libraries for Oauth and OIDC compose requests better
        oauth2_flow() {
            # initiate login flow and redirect to login page
            # following the process should redirect after login with the authorization code provided in the URL
            {
                {
                    printf "visit in browser %s" "https://auth.donation-app.test/authorize/oauth2/auth?client_id=frontend-client&response_type=code%20id_token&scope=offline_access%20openid&redirect_uri=https://donation-app.test&state=some_random_string&nonce=some_other_random_string"

                    # typically would run from within the cluster using the backend server of the frontend ui application (must be secure as it contains client secret)
                    # EXAMPLE for usage with client_secret_post

                    CLIENT_ID="frontend-client"
                    # CLIENT_SECRET=""
                    CLIENT_SECRET="$(kubectl get secret "ory-hydra-client--$CLIENT_ID" -n auth -o jsonpath='{.data.client_secret}' | base64 -d)"
                    # [manually eplace this] update the code from the result redirect url parameter after login
                    AUTHORIZATION_CODE=""
                    REDIRECT_URI="https://donation-app.test"
                }
                # or 
                {
                    printf "visit in browser %s" "https://auth.donation-app.test/authorize/oauth2/auth?client_id=frontend-client-oauth&response_type=code&scope=offline_access%20openid&redirect_uri=https://donation-app.test&state=some_random_string&nonce=some_random_str"

                    # typically would run from within the cluster using the backend server of the frontend ui application (must be secure as it contains client secret)
                    # EXAMPLE for usage with client_secret_post

                    CLIENT_ID="frontend-client-oauth"
                    CLIENT_SECRET="$(kubectl get secret "ory-hydra-client--$CLIENT_ID" -n auth -o jsonpath='{.data.client_secret}' | base64 -d)"
                    # CLIENT_SECRET=""
                    # [manually eplace this] update the code from the result redirect url parameter after login
                    AUTHORIZATION_CODE="ory_ac_qdyriUfO1jyHatQzcjZ4oTvqei-aB5BRREoY-XwAB2o.jrTz5KqJ_wZzbCTMWf0Gl4tyTnyJwz6c66Zyhd-YKHc"
                    REDIRECT_URI="https://donation-app.test"
                }
                # or 
                {
                    printf "visit in browser %s" "https://auth.donation-app.test/authorize/oauth2/auth?client_id=frontend-client-oauth-consent&response_type=code%20id_token&scope=offline_access%20openid&redirect_uri=https://donation-app.test&state=some_random_string&nonce=some_other_random_string"

                    # typically would run from within the cluster using the backend server of the frontend ui application (must be secure as it contains client secret)
                    # EXAMPLE for usage with client_secret_post

                    # [manually eplace this] update the code from the result redirect url parameter after login
                    AUTHORIZATION_CODE="ory_ac_FbhszJNnQ94P_Du28iCx75mVjM2LwJuheZtds3KEHCs.QCw9XsW1gDX04EtrEfGNwqbJ3hcoTETDBuvk9d1sFO4"
                    CLIENT_ID="frontend-client-oauth-consent"
                    CLIENT_SECRET="$(kubectl get secret "ory-hydra-client--$CLIENT_ID" -n auth -o jsonpath='{.data.client_secret}' | base64 -d)" # NOTE: the secret is retreived by kubectl and base64 is applied thus decoding is required
                    # CLIENT_SECRET=""
                    REDIRECT_URI="https://donation-app.test"
                }

            }

            # Execute the curl request
            # -v -s -o /dev/null  -k
            tokens_payload=$(curl -k -s --request POST --url https://auth.donation-app.test/authorize/oauth2/token --header "accept: application/x-www-form-urlencoded" \
                --form "grant_type=authorization_code" \
                --form "code=${AUTHORIZATION_CODE}" \
                --form "redirect_uri=${REDIRECT_URI}" \
                --form "client_id=${CLIENT_ID}" \
                --form "client_secret=${CLIENT_SECRET}" \
                --form "scope=offline_access openid" | jq)
            
            ACCESS_TOKEN=$(echo $tokens_payload | jq -r '.access_token')
            REFRESH_TOKEN=$(echo $tokens_payload | jq -r '.refresh_token')
            ID_TOKEN=$(echo $tokens_payload | jq -r '.id_token')

            # verify tokens
            kubectl run -it --rm --image=nicolaka/netshoot debug-pod --namespace auth -- /bin/bash
            {
                curl -k -i --request POST --url http://hydra-admin/admin/oauth2/introspect --header "accept: application/x-www-form-urlencoded" --form "token=$ACCESS_TOKEN" 
                # access restricted endpoint through Envoy Gateway + Oauthkeeper as introspection (calls http://oathkeeper-admin:80/decisions)
                curl -i -k -H "Authorization: Bearer $ACCESS_TOKEN" https://test.donation-app.test/oauth-header

                # request refresh token 
                curl -k -i --request POST --url https://auth.donation-app.test/authorize/oauth2/token --header "accept: application/x-www-form-urlencoded" \
                    --form "grant_type=refresh_token" \
                    --form "refresh_token=${REFRESH_TOKEN}" \
                    --form "redirect_uri=${REDIRECT_URI}" \
                    --form "client_id=${CLIENT_ID}"  \
                    --form "client_secret=${CLIENT_SECRET}" \
                    --form "scope=offline_access openid"
            }
            {
                # decode JWT id_token
                echo -n "$ID_TOKEN" | cut -d "." -f2 | base64 -d | jq .
            }
        }

        # directly request token with Hydra Oauth2.0 client id+secret
        client_secret_basic_method() {
            CLIENT_ID="internal-communication"
            CLIENT_SECRET="$(kubectl get secret "ory-hydra-client--$CLIENT_ID" -n auth -o jsonpath="{.data.client_secret}" | base64 -d)"
            # CLIENT_SECRET=""
            REDIRECT_URI="https://donation-app.test"
            # Base64 encode the client ID and secret
            BASE64_CREDENTIALS=$(echo -n "${CLIENT_ID}:${CLIENT_SECRET}" | base64 -w 0)
            echo $BASE64_CREDENTIALS
            # Construct the curl command

            tokens_payload=$(curl -s -k -X POST -H "Content-Type: application/x-www-form-urlencoded" \
                -H "Authorization: Basic ${BASE64_CREDENTIALS}" \
                -d "grant_type=client_credentials" \
                https://auth.donation-app.test/authorize/oauth2/token | jq)
            echo $tokens_payload
            
            ACCESS_TOKEN=$(echo $tokens_payload | jq -r '.access_token')
            echo $ACCESS_TOKEN

            # verify tokens
            {
                # access restricted endpoint through Envoy Gateway + Oauthkeeper as introspection (calls http://oathkeeper-admin:80/decisions)
                curl -i -k -H "Authorization: Bearer $ACCESS_TOKEN" https://test.donation-app.test/oauth-header
                # run within cluster
                kubectl run -it --rm --image=nicolaka/netshoot debug-pod-auth --namespace auth -- /bin/bash
                {
                    curl -k -i --request POST --url http://hydra-admin/admin/oauth2/introspect --header "accept: application/x-www-form-urlencoded" --form "token=$ACCESS_TOKEN" 
                }
                # check as JWT
                curl -i -k -H "Authorization: Bearer $ACCESS_TOKEN" https://test.donation-app.test/jwt
            }
        }
        
        popd
    }

}


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
            # install dependencies including Hydra
            {
                apt update && apt install curl jq -y
                bash <(curl https://raw.githubusercontent.com/ory/meta/master/install.sh) -d -b . hydra v2.2.0 && mv hydra /usr/bin/
            }


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

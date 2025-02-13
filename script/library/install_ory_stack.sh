# https://k8s.ory.sh/helm/
# $`install_ory_stack
# $`install_ory_stack --action delete
install_ory_stack() {
    local environment="development" # environment = development, production
    local action="install" # action = install, delete

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --environment) environment="$2"; shift ;;
            --action) action="$2"; shift ;;
            *) echo "Unknown parameter passed: $1"; exit 1 ;;
        esac
        shift
    done

    {
        if [ "$action" == "delete" ]; then
            helm uninstall kratos -n auth
            helm uninstall postgres-kratos -n auth
            helm uninstall hydra -n auth
            helm uninstall postgres-hydra -n auth
            helm uninstall keto -n auth
            helm uninstall postgres-keto -n auth
            helm uninstall oathkeeper -n auth

            kubectl delete secret ory-hydra-client--frontend-client-oauth -n auth
            kubectl delete secret ory-hydra-client--frontend-client -n auth
            kubectl delete secret ory-hydra-client--internal-communication -n auth
            kubectl delete secret ory-hydra-client--oathkeeper-introspection -n auth

            if [ "$environment" == "development" ]; then
                kubectl delete pv --all
                kubectl delete pvc --all
            fi
            return 
        fi
    }

    # ory stack charts
    helm repo add ory https://k8s.ory.sh/helm/charts
    # postgreSQL
    helm repo add bitnami https://charts.bitnami.com/bitnami 
    helm repo update

    install_kratos $environment
    install_hydra $environment
    install_keto
    create_oauth2_client_for_trusted_app $environment
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


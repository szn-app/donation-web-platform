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

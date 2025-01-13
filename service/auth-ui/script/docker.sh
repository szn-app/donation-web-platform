## IMPORTANT! used in .github/workflows/*
bulid_container_auth_ui() {
    pushd kratos-selfservice-ui-node
    
    docker build . -t auth-ui:latest

    popd
}

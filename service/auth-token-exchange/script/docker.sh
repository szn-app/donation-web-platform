misc_auth_token_exchange() { 
    cargo build 
    cargo run 
    cargo build --release
}

# IMPORTANT! used by release.yml workflow
build_container_auth_token_exchange() { 
    # NOTE: uses buildx (instead of the legacy build)
    docker build . -t auth_token_exchange:latest
}

run_docker_auth_token_exchange() {
    docker run -d -p 80:3000 auth_token_exchange
}

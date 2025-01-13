# IMPORTANT! used by release.yml workflow
build_container_web_server() { 
    # NOTE: uses buildx (instead of the legacy build)
    docker build . -t web-server:latest
}

run() {
    docker run -d -p 80:80 web-server
}

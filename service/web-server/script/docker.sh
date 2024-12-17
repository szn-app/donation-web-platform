build() { 
    docker build -t web-server .
}

run() {
    docker run -d -p 80:80 web-server
}
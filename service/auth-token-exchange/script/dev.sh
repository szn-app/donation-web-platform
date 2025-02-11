test() { 
    cargo watch -q -c -w src/ -x run
    cargo watch -q -c -w tests/ -x "test -q test_main -- --nocapture" 
}

single_test() { 
    cargo watch -q -c -w src/ -x run &
    sleep 1s
    cargo test -q test_main -- --nocapture 
    kill $(jobs -p)
}

bootstrap() { 
    cargo install cargo-binstall
    
    # cargo binstall cargo-watch
    cargo install cargo-watch --locked
}
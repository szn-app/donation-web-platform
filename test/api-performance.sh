#!/bin/bash

# quick api performance test
# copy over functions to shell script and run by name

export ip_address=''

latency() {
    [ -z "$ip_address" ] && export ip_address=""

    for i in {1..100}; do 
        curl $ip_address \
            -H 'cache-control: no-cache' \
            -H 'pragma: no-cache' \
            --compressed \
            --insecure -s -o /dev/null -w "%{time_total}s\n";
    done
}

latency_parallel_1() {
    [ -z "$ip_address" ] && export ip_address=""

    seq 1 500 | xargs -P 100 -I{} curl http://$ip_address/path-{} --insecure -s -o /dev/null -w "%{time_total}s\n"
} 

latency_parallel_2() {
    [ -z "$ip_address" ] && export ip_address=""

    for i in $(seq 1 500); do 
         curl "http://$ip_address/path-${i}" --insecure -s -o /dev/null -w "%{time_total}s\n" & >/dev/null 2>&1
    done; 
    wait >/dev/null 2>&1 
}
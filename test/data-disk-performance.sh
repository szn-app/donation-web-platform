#!/bin/bash

run_test_dbench() { 
    kubectl --kubeconfig "$kubeconfig" apply -f test-storage-iops.yml
}
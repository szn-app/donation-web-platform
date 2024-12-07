service_tag_version() { 
    local service="${1:-web-server}" 
    local version="${2:-0.1.0}" 

    # bump package.json version
    set_version() {
        local new_version="$1"

        jq --arg new_version "$new_version" '.version = $new_version' package.json > package.json.tmp
        mv package.json.tmp package.json

        echo "Version set to $new_version"
    }

    # Call the set_version function
    pushd ./service/$service
    set_version "$version"
    git add package.json
    git commit -m "version bump"
    git tag $service-v$version
    popd
}

release_package() {
    if [[ $# -gt 0 ]]; then
        service_tag_version $1 $2
    fi

    git push --tags
}

delete_tag() { 
    tag=web-server-v0.1.1
    git push origin :$tag
    git tag -d $tag
}
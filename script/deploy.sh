
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

    pushd ./service/$service
    set_version "$version"

    git add package.json
    git commit -m "$service $version version bump"

    popd
}

release_package() {
    local service="${1:-web-server}" 
    local version="${2:-0.1.0}" 

    if [[ -z "$(git diff --cached --name-only)" ]]; then
        echo "No staged files found. Proceeding..."
        if [[ -n "$(git status --porcelain)" ]]; then
            git stash 
        fi 
    else 
        echo "There are staged files. Please commit or stash them before proceeding."
        exit 1
    fi

    if [[ $# -gt 1 ]]; then
        service_tag_version $service $version
    fi

    git checkout main
    git merge development 
    git tag $service-v$version
    git checkout development

    git push origin main development
    git push --tags

    git stash pop > /dev/null 2>&1
}

delete_tag() { 
    tag=${1:-web-server-v0.1.1}
    git push origin :$tag
    git tag -d $tag
}

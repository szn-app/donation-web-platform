
manual_service_tag_version() { 
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

manual_release_package() {
    local service="${1:-web-server}" 
    local version="${2:-0.1.0}" 

    if ! git symbolic-ref --short HEAD | grep -q '^main$'; then
        echo "error: not on main branch."
        exit 1;
    fi

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

    git push origin 

    git tag $service-v$version
    git push --tags

    git stash pop > /dev/null 2>&1
}

example_workflow_with_release_please_manually_triggered() { 
    create_feature_pr() {
        feature_branch=$1
        git checkout -b $feature_branch
        git commit --allow-empty -m "commit 1" 
        git commit --allow-empty -m "commit 2" 
        git commit --allow-empty -m "commit 3"
        git push --set-upstream origin $feature_branch
        gh pr create --base main --head $feature_branch --title "feat: adding feacture x to component A" 
    }

    merge_last_pr() { 
        local feature_branch=$1
        git fetch origin 
        git checkout main 
        last_pr_number=$(gh pr list --state open --json number | jq -r '.[0].number') 
        default_branch=$(git remote show origin | grep "HEAD branch:" | awk '{print $3}')
        pr_title=$(gh pr view "$last_pr_number" --json title | jq -r '.title')
        gh pr merge $last_pr_number --squash -t "$pr_title"
        git pull && git push origin main 
    }

    local release_please_workflow=monorepo-release.yml

    local feature_branch=branch_feature_x
    create_feature_pr $feature_branch

    # create release pr
    merge_last_pr $feature_branch # merge feature pr
    gh workflow run $release_please_workflow # -> release pr is created. 
    gh run list --workflow=$release_please_workflow 

    {
        # new features can be added and will be appended to the existing release PR managed by `release-please``.
        local feature_branch=branch_feature_y
        create_feature_pr $feature_branch
        
        # create release pr
        merge_last_pr $feature_branch # merge feature pr
        gh workflow run $release_please_workflow # -> release pr is created. 
        gh run list --workflow=$release_please_workflow 

        merge_last_pr $feature_branch # merge release pr
    }

    # create a package release on Github
    merge_last_pr $feature_branch # merge release pr
    gh workflow run $release_please_workflow # -> package a github release
}

delete_tag() { 
    tag=${1:-web-server-v0.1.1}
    git push origin :$tag
    git tag -d $tag
}

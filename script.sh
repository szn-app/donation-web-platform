#!/bin/bash
## Entrypoint for project scripts
# `chmod +x ./script.sh`
# `./script.sh <function-name> [args...]`

load_scripts_recursive() {
    SCRIPT_DIR="$1"  # Get directory from argument

    # Validate input
    if [[ -z "$SCRIPT_DIR" ]]; then
        echo "Usage: $0 <script_directory>"
        return 1
    elif [[ ! -d "$SCRIPT_DIR" ]]; then
        echo "Error: '$SCRIPT_DIR' is not a valid directory."
        return 1
    fi

    # Find and source all .sh scripts recursively
    for script in $(find "$SCRIPT_DIR" -type f -name "*.sh"); do
        echo "Sourcing $script..."
        source "$script"
    done
}

# load functions
load_scripts_recursive "./script/" 

# call function in this script file from commandline argument
{
    fn_name="$1"
    if [[ $# -lt 1 ]]; then
        # This case can be used for executing $`source ./script.sh` to load functions to current shell session.
        echo "using source ./script.sh loads functions to current shell session"
    elif ! declare -f "$fn_name" || ! [[ $(type -t "$fn_name") ]]; then # check if defined in current file or sourced declaration 
        echo "Error: function '$fn_name' not declared. "
        exit 1
    else 
        # redirect call to function name provided
        shift
        "$fn_name" "$@"
    fi
}

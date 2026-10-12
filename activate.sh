#!/bin/bash
#
# activate.sh - Activate the Python virtual environment, environment variables and ssh-agent session needed to run dbt.
#
# Usage:
#   source ~/workspace/dbt/activate.sh [--update]
#
# Options:
#   -u, --update    Check for Python and dbt updates (skipped by default)
#   -h, --help      Show this help message and exit
#
# Must be sourced, not executed (./activate.sh would run in a throwaway subprocess and none of the virtual environment, exported variables or ssh-agent session would persist in the calling shell).
# Safe to call multiple times: skips the re-activation of the virtual environment if it is already active and the start of the SSH agent if it is already running.
#

# Force sourcing instead of executing
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo 'Error: source ./activate.sh instead of executing it.' >&2
    exit 1
fi

usage() {
    sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# Load the shared configuration settings for the dbt helper scripts.
source "$(dirname -- "${BASH_SOURCE[0]}")/config.sh"
check_for_updates=false

while [[ $# -gt 0 ]];
do
    case "$1" in
        -u|--update)
            check_for_updates=true
            shift 1
            ;;
        -h|--help)
            usage
            return 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            return 1
            ;;
    esac
done

echo "Starting action: Cleaning log files from previous runs"
rm "${local_logs_dir%/}/"*

if [ -n "$VIRTUAL_ENV" ];
then
    echo 'Skipping action: Python Virtual Environment already active'
else
    echo 'Starting action: Activating Python Virtual Environment'
    source "$local_virtual_env_activation_path"
fi

if ssh-add -l &>/dev/null;
then
    echo 'Skipping action: SSH agent already running with a loaded key'
else
    echo 'Starting action: Starting SSH Agent and adding key'
    eval "$(ssh-agent -s)"
    ssh-add "$local_ssh_key_path"
    ssh -T git@github.com
fi

if [ "$check_for_updates" = true ]; then
    echo 'Starting action: Check for updates'
    echo 'Python versions available on the system'
    py list
    echo 'Latest Python version available online'
    py list --online --one
    echo 'Current dbt version (flags a newer dbt-core release if available)'
    dbt --version
else
    echo 'Skipping action: Check for updates'
fi

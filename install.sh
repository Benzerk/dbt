#!/bin/bash
#
# install.sh - One-time setup: create the Python virtual environment for dbt, install the company CA certificate, and install the project's Python dependencies.
#
# Usage:
#   source ~/workspace/dbt/install.sh
#
# Can be sourced or executed, but sourcing leaves the virtual environment active in the calling shell afterward instead of requiring a separate `source activate.sh`.
# Stops on the first failing command (set -e) instead of silently continuing with a broken/partial install.
#

# Prevent sourcing instead of executing
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    printf 'Error: run this script with bash ./install.sh; do not source it.\n' >&2
    return 1
fi

set -euo pipefail

# Load the shared configuration settings for the dbt helper scripts.
source "$(dirname -- "${BASH_SOURCE[0]}")/config.sh"

echo 'Creating Virtual Environment'
py --version
rm -rf "$local_virtual_env_dir"
py -m venv "$local_virtual_env_dir"

echo 'Activating Virtual Environment'
source "$local_virtual_env_activation_path"

echo 'Installing Libraries'
py -m ensurepip --default-pip
py -m pip install --upgrade pip
pip install -r "${local_root_dir%/}/requirements.txt"

echo 'Creating Logs Directory'
mkdir -p "${local_logs_dir%/}/"

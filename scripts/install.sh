#!/bin/bash
#
# install.sh - One-time setup: create the Python virtual environment for dbt, install the company CA certificate, and install the project's Python dependencies.
#
# Usage:
#   bash scripts/install.sh
#
# Must be executed; activate the environment afterward with `source scripts/activate.sh`.
# Stops on the first failing command (set -e) instead of silently continuing with a broken/partial install.
#

# Prevent sourcing instead of executing
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    echo 'Error: run this script with bash scripts/install.sh; do not source it.' >&2
    return 1
fi

set -euo pipefail

# Load the shared configuration settings for the dbt helper scripts.
source "$(dirname -- "${BASH_SOURCE[0]}")/../config/config.sh"

echo 'Creating Virtual Environment'
py "-$local_python_version" --version
rm -rf "$local_virtual_env_dir"
py "-$local_python_version" -m venv "$local_virtual_env_dir"

echo 'Activating Virtual Environment'
source "$local_virtual_env_activation_path"

echo 'Installing Libraries'
python -m ensurepip --default-pip
python -m pip install --upgrade pip
python -m pip install -r "${local_root_dir%/}/config/requirements.txt"

echo 'Creating Logs Directory'
mkdir -p "${local_logs_dir%/}/"

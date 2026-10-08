#!/bin/bash
#
# config.sh - Shared environment settings for the dbt helper scripts.
#
# Usage:
#   source ./config.sh
#
# Should be sourced, not executed, to properly set environment variables in the calling shell.
#

# Force sourcing instead of executing
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    printf 'Error: source ./config.sh instead of executing it.\n' >&2
    exit 1
fi

# Local root directory
local_root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
local_logs_dir="${local_root_dir%/}/logs"

# Local paths for certificates and SSH keys
local_certificate_path="${local_root_dir%/}/zscaler.pem"
local_ssh_key_path="$HOME/.ssh/id_ed25519"

# Local path for Python virtual environment on Windows
local_virtual_env_dir="${local_root_dir%/}/.virtualenv/"
local_virtual_env_activation_path="${local_virtual_env_dir%/}/Scripts/activate"

# Environement variables for proxy, certificates, and Python package management
echo 'Setting Environment Variables'
export HTTP_PROXY='http://127.0.0.1:9000/'
export HTTPS_PROXY='http://127.0.0.1:9000/'
export REQUEST_CA_BUNDLE="$local_certificate_path"
export PIP_CERT="$local_certificate_path"
export PIP_TRUSTED_HOST="pypi.python.org pypi.org files.pythonhosted.org"
export SNOWFLAKE_LOGIN_EMAIL='email@example.com'

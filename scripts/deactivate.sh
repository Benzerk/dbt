#!/bin/bash
#
# deactivate.sh - Undo activate.sh: unset the dbt-related environment variables and deactivate the Python virtual environment.
#
# Usage:
#   source ~/workspace/dbt/deactivate.sh
#
# Must be sourced, not executed (./deactivate.sh would run in a throwaway subprocess and the unset/deactivate calls would have no effect on the calling shell).
# Safe to call multiple times: deactivation of the virtual environment and stop of the ssh-agent are each guarded by the variable they themselves unset, so repeated calls are no-ops.
#

# Force sourcing instead of executing
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo 'Error: source ./deactivate.sh instead of executing it.' >&2
    exit 1
fi

echo 'Unsetting Environment Variables'
unset SNOWFLAKE_LOGIN_EMAIL
unset PIP_TRUSTED_HOST
unset PIP_CERT
unset REQUEST_CA_BUNDLE

echo 'Deactivating Virtual Environment'
if [ -n "$VIRTUAL_ENV" ];
then
    deactivate
fi

echo 'Stopping SSH Agent'
if [ -n "$SSH_AGENT_PID" ];
then
    eval "$(ssh-agent -k)"
fi

echo "Cleaning log files"
rm "${local_logs_dir%/}/"*

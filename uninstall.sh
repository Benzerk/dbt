#!/bin/bash
#
# uninstall.sh - Remove the local Python virtual environment and generated logs.
#
# Usage:
#   bash ./uninstall.sh
#

# Prevent sourcing instead of executing.
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
	printf 'Error: run this script with bash ./uninstall.sh; do not source it.\n' >&2
	return 1
fi

set -euo pipefail

local_root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
local_virtual_env_dir="${local_root_dir%/}/.virtualenv"
local_logs_dir="${local_root_dir%/}/logs"

if [[ -n "${VIRTUAL_ENV:-}" && -d "$local_virtual_env_dir" ]]; then
	if active_venv_path="$(cd -- "$VIRTUAL_ENV" 2>/dev/null && pwd -P)" &&
		target_venv_path="$(cd -- "$local_virtual_env_dir" 2>/dev/null && pwd -P)" &&
		[[ "$active_venv_path" == "$target_venv_path" ]]; then
		printf 'Error: deactivate this repository virtual environment before uninstalling.\n' >&2
		printf 'Run: source ./deactivate.sh\n' >&2
		exit 1
	fi
fi

printf 'This will permanently remove:\n  %s\n  %s\n' "$local_virtual_env_dir" "$local_logs_dir"
printf 'The certificate and SSH key will be kept.\n'
printf 'Continue? [y/N] '

if ! IFS= read -r confirmation; then
	printf '\nError: confirmation could not be read. No files were removed.\n' >&2
	exit 1
fi

case "$confirmation" in
	y|Y|yes|YES)
		;;
	*)
		printf 'Uninstallation cancelled.\n'
		exit 0
		;;
esac

for path in "$local_virtual_env_dir" "$local_logs_dir"; do
	if [[ -e "$path" || -L "$path" ]]; then
		rm -rf -- "$path"
		printf 'Removed %s\n' "$path"
	else
		printf 'Not found, skipping %s\n' "$path"
	fi
done

printf 'Uninstallation complete.\n'
#
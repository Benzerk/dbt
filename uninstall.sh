#!/bin/bash
#
# uninstall.sh - Remove the local Python virtual environment and generated logs.
#
# Usage:
#   bash ./uninstall.sh
#

# Prevent sourcing instead of executing.
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
	echo 'Error: run this script with bash ./uninstall.sh; do not source it.' >&2
	return 1
fi

set -euo pipefail

# Load the shared configuration settings for the dbt helper scripts.
source "$(dirname -- "${BASH_SOURCE[0]}")/config.sh"

if [[ -n "${VIRTUAL_ENV:-}" && -d "$local_virtual_env_dir" ]]; then
	if active_venv_path="$(cd -- "$VIRTUAL_ENV" 2>/dev/null && pwd -P)" &&
		target_venv_path="$(cd -- "$local_virtual_env_dir" 2>/dev/null && pwd -P)" &&
		[[ "$active_venv_path" == "$target_venv_path" ]]; then
		echo 'Error: deactivate this repository virtual environment before uninstalling.' >&2
		echo 'Run: source ./deactivate.sh' >&2
		exit 1
	fi
fi

echo "This will permanently remove:"
echo "  $local_virtual_env_dir"
echo "  $local_logs_dir"
echo "The certificate and SSH key will be kept."
echo -n "Continue? [y/N] "

if ! IFS= read -r confirmation; then
	echo 'Error: confirmation could not be read. No files were removed.' >&2
	exit 1
fi

case "$confirmation" in
	y|Y|yes|YES)
		;;
	*)
		echo 'Uninstallation cancelled.'
		exit 0
		;;
esac

for path in "$local_virtual_env_dir" "$local_logs_dir"; do
	if [[ -e "$path" || -L "$path" ]]; then
		rm -rf -- "$path"
		echo "Removed $path"
	else
		echo "Not found, skipping $path"
	fi
done

echo 'Uninstallation complete.'

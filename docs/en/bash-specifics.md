# Bash specifics used by this project

The scripts in this repository are written for **Bash** and are used from Git Bash on Windows. Some rely on Bash-specific features, so they are not necessarily compatible with `sh`, PowerShell, or other shells.

## Sourcing or executing a script

An executed script runs in a separate process. Its environment-variable changes cannot affect the calling shell. Scripts live in `scripts/`: from the repository root, run for example `bash ./scripts/install.sh`. For dbt, run `make.sh` by its absolute path from the target project, as shown in the [README](../../README.md#run-dbt).

By contrast, `source ./scripts/activate.sh` runs the file in the current shell. This is required for virtual-environment activation and the `export` operations in `config.sh` or `unset` operations in `deactivate.sh` to persist after the script returns. Therefore, `config/config.sh`, `scripts/activate.sh`, and `scripts/deactivate.sh` must be sourced. These relative paths assume the repository root; use their absolute paths from another directory.

The scripts detect this context by comparing `${BASH_SOURCE[0]}` with `$0`: when sourced, the current file differs from the launched program. They reject the wrong invocation mode. In a sourced script, `return` leaves the file without closing the shell; in an executed script, `exit` terminates the process.

## Finding the script directory

Scripts load the shared configuration with a command like this:

```bash
source "$(dirname -- "${BASH_SOURCE[0]}")/../config/config.sh"
```

`BASH_SOURCE[0]` identifies the current Bash file, `dirname` extracts its directory, and `$(...)` runs that command and inserts its output. From `scripts/`, `../config/config.sh` locates the configuration even when launched from another working directory. In `config/config.sh`, `cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P` then computes an absolute, physical path for the repository root, one level above `config/`.

Quoting expansions protects paths that contain spaces. The `--` argument tells commands such as `dirname` or `cd` that following arguments are not options.

## Variables and expansions

- `export NAME=value` defines a variable and passes it to subsequently launched programs. `unset NAME` removes it from the current shell.
- `${path%/}` removes a trailing `/`; `${version//./}` replaces every period. These Bash parameter expansions are used to construct the log and virtual-environment paths.
- `${VIRTUAL_ENV:-}` expands to an empty string when the variable is unset, preventing an error with `set -u`.
- `$(command)` captures a command's standard output, for example `$(date ...)` to timestamp logs or `$(ssh-agent -s)` to obtain the SSH agent's environment assignments.

Ordinary variables are almost always quoted, for example `"$local_root_dir"`, to prevent word splitting and wildcard expansion. Where possible, arguments are passed separately instead of being assembled into a string.

## Tests and options

`[[ ... ]]` is the Bash conditional used most often in these scripts. It can test strings and paths and combine expressions with `&&` or `||`. The `[ ... ]` forms also used in the scripts are shell tests, but have stricter syntax: spaces are required around the brackets and variables should be quoted.

Options are parsed with a `while` loop over `"$#"` (the number of arguments), a `case` statement on `"$1"` (the current argument), and `shift` or `shift 2` to consume arguments. This preserves values containing spaces when they are passed as a single argument, such as a dbt selection.

`make.sh` builds Bash arrays for optional arguments, for example `vars_arg=(--vars "$dbt_vars")`, and expands them with `"${vars_arg[@]}"`. An empty array adds no arguments; a non-empty array passes each item as a separate argument without reinterpreting spaces or JSON.

## Exit status, pipelines, and error handling

In `install.sh` and `uninstall.sh`, `set -euo pipefail` enables three safeguards: exit on certain failing commands (`-e`), report unset variables as errors (`-u`), and make a pipeline fail if any command in it fails (`pipefail`). These options are not enabled globally by the sourced scripts because that would change the user's shell behavior.

`make.sh` sends dbt command output through `tee` with a pipeline: `"$@" 2>&1 | tee "$logs_filepath"`. `PIPESTATUS[0]` is a Bash array element that retains the exit status of the first command in the pipeline. The script uses it to detect dbt failures even when `tee` succeeds.

## Commands used in this repository

- `source` loads another script into the current shell; `eval` interprets a string as a command. `eval "$(ssh-agent -s)"` applies the environment assignments printed by `ssh-agent` to the current shell.
- `read -r` reads input without treating backslashes specially; `case` handles the responses accepted by the uninstaller.
- `2>&1` redirects standard error to standard output so that `tee` logs both streams.
- `"${array[@]}"` passes array elements as separate arguments; `"$@"` does the same for the arguments received by a function.

When changing the scripts, keep their invocation contract (sourced or executed) in mind, quote path expansions, and preserve arguments as arrays or separate parameters.
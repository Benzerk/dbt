# dbt

Personal scripts for setting up a Python environment and running a dbt project with Snowflake.

## Prerequisites

- Windows with Git Bash (the scripts use commands and paths from this environment).
- Python installed and available through the `py` launcher.
- The repository's `requirements.txt` file.
- The company CA certificate `zscaler.pem` at the repository root.
- An accessible company proxy at `http://127.0.0.1:9000/`.
- An SSH key configured locally and added to GitHub for operations that require the SSH agent.

## Installation

Installation creates a Python virtual environment in `.virtualenv/`, installs the Python dependencies listed in `requirements.txt`, and creates the `logs/` directory. It uses the certificate and proxy configured in `config.sh`. Run `install.sh` in a subprocess; the virtual environment will not remain active in the current shell. Activate it with `activate.sh` after installation.

From Git Bash at the repository root:

```bash
bash ./install.sh
```

The certificate stays at the repository root, and pip uses it through `PIP_CERT`. Installation does not copy the certificate or modify pip's global configuration.

## Activate the environment

After installation, activate the environment and configure environment variables and the SSH agent in each new shell:

```bash
source ./activate.sh
```

To display the help:

```bash
source ./activate.sh --help
```

To check Python and dbt versions during activation:

```bash
source ./activate.sh --update
```

Activation loads the configuration and activates the virtual environment if it is not already active. It then starts an SSH agent and adds the configured key if no key is already loaded. It also removes existing files from `logs` at the start of activation.

Shared variables are defined in `config.sh`, which is loaded automatically by `install.sh` and `activate.sh`. You can also load it directly in a shell:

```bash
source ./config.sh
```

`config.sh` derives the repository, virtual environment, logs, and certificate paths from the script location. Configure the SSH key path locally in this file. It exports `HTTP_PROXY`, `HTTPS_PROXY`, `REQUEST_CA_BUNDLE`, `PIP_CERT`, `PIP_TRUSTED_HOST`, and `SNOWFLAKE_LOGIN_EMAIL`. Values set in this file override any values already present in the shell.

## Run dbt

`make.sh` runs dbt commands and saves each command's output to a timestamped file in the `logs` directory at the repository root. Run this script; do not source it.

The default mode is a full rebuild. It runs `dbt clean`, `dbt deps --upgrade`, `dbt parse`, `dbt compile`, `dbt run --full-refresh`, and then `dbt test`:

```bash
bash ./make.sh
```

The other modes are:

- `build`: skips cleaning, dependency updates, parsing, and compilation; runs a standard `dbt run` followed by tests.
- `run`: performs the same standard run as `build` without running `dbt test`.

In `build` and `run` modes, `dbt run` excludes view-materialized models. The `rebuild` mode runs `dbt run --full-refresh`.

Examples with a mode, node selection, or dbt variables:

```bash
bash ./make.sh --mode build
bash ./make.sh --mode run --select "staging.my_model marts.my_other_model"
bash ./make.sh --vars '{"variable": "value"}'
bash ./make.sh --strict
bash ./make.sh --help
```

The `--strict` option treats warnings as errors for every dbt command that runs, including `test`. It also disables partial parsing (`--no-partial-parse`) for `parse`, `compile`, `run`, and `test`, and shows all deprecations (`--show-all-deprecations`) for `parse` and `compile`. Strict mode does not change the selected execution mode.

Node selection is passed to `dbt compile` in `rebuild` mode, and to `dbt run` and `dbt test` when those commands run. JSON variables are passed only to `dbt run`.

## Deactivate the environment

In the shell where the environment was activated:

```bash
source ./deactivate.sh
```

This unsets `SNOWFLAKE_LOGIN_EMAIL` and the pip/certificate variables, deactivates the virtual environment, stops the SSH agent if `SSH_AGENT_PID` is set, and removes files from `logs`. The `HTTP_PROXY` and `HTTPS_PROXY` variables are not unset.

## Uninstall

Run the uninstaller from the repository root:

```bash
bash ./uninstall.sh
```

After confirmation, it removes `.virtualenv/` and `logs/`. It keeps the certificate and SSH key. If this repository's virtual environment is active, deactivate it first with `source ./deactivate.sh`.

## Path configuration

The scripts derive repository paths from their own locations. The example commands assume they are run from the repository root.

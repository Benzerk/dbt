# dbt

Personal scripts for setting up a Python environment and running a dbt project with Snowflake.

## Prerequisites

- Windows with Git Bash (the scripts use commands and paths from this environment).
- Python 3.14 installed and available through the `py` launcher. Change `local_python_version` in `config/config.sh` to select another installed version.
- The repository Python requirement file `config/requirements.txt`.
- The company CA certificate `config/zscaler.pem` (not tracked by Git).
- An accessible company proxy at `http://127.0.0.1:9000/`.
- An SSH key configured locally and added to GitHub for operations that require the SSH agent.

## Installation

Installation creates a Python virtual environment in a version-specific `.virtualenv_<version>` directory, installs the Python dependencies listed in `config/requirements.txt`, and creates the `logs/` directory. It uses the certificate and proxy configured in `config/config.sh`. Run `scripts/install.sh` in a subprocess; the virtual environment will not remain active in the current shell. Activate it with `scripts/activate.sh` after installation.

**Warning:** installation deletes the configured virtual environment, including any manually installed packages, before recreating it. This also applies to reinstallation and happens without confirmation. Deactivate the environment first if it is active.

From Git Bash at the repository root:

```bash
bash ./scripts/install.sh
```

The certificate stays in `config/`, and pip uses it through `PIP_CERT`. Installation does not copy the certificate or modify pip's global configuration.

## Activate the environment

After installation, activate the environment and configure environment variables and the SSH agent in each new shell:

```bash
source ./scripts/activate.sh
```

To display the help:

```bash
source ./scripts/activate.sh --help
```

To check Python and dbt versions during activation:

```bash
source ./scripts/activate.sh --update
```

Activation loads the configuration and activates the virtual environment if it is not already active. It then starts an SSH agent and adds the configured key if no key is already loaded. It also removes existing files from `logs` at the start of activation.

Shared variables are defined in `config/config.sh`, which is loaded automatically by the scripts that need it. You can also load it directly in a shell:

```bash
source ./config/config.sh
```

`config/config.sh` derives the repository, virtual environment, logs, and certificate paths from the configuration file location. Set `local_python_version` there to select the Python version used to create the virtual environment. Configure the SSH key path locally in this file. It exports `HTTP_PROXY`, `HTTPS_PROXY`, `REQUEST_CA_BUNDLE`, `PIP_CERT`, `PIP_TRUSTED_HOST`, and `SNOWFLAKE_LOGIN_EMAIL`. Values set in this file override any values already present in the shell.

## Run dbt

`scripts/make.sh` runs dbt commands and saves each command's output to a timestamped file in the `logs` directory at the scripts repository root. Run this script; do not source it. It uses the current working directory as the dbt project directory; it does not change directories or pass `--project-dir`.

The default mode is a full rebuild. It runs `dbt debug`, `dbt clean`, `dbt deps --upgrade`, `dbt parse`, `dbt compile`, `dbt run --full-refresh`, and then `dbt test`:

Replace the example paths below with the absolute Git Bash paths to this scripts repository and your target dbt project (the directory containing `dbt_project.yml`). Activate the environment in the same shell, then run dbt from the target project:

```bash
source ~/workspace/personal/dbt/scripts/activate.sh
bash ~/workspace/personal/dbt/scripts/make.sh
```

The other modes are:

- `build`: skips cleaning, dependency updates, parsing, and compilation; runs a standard `dbt run` followed by tests.
- `run`: performs the same standard run as `build` without running `dbt test`.

In `build` and `run` modes, `dbt run` excludes view-materialized models. The `rebuild` mode runs `dbt run --full-refresh`.

All modes run `dbt debug` first. To use Snowflake SSO, configure the active output in `profiles.yml` with `authenticator: externalbrowser`. `dbt debug` then tests the connection and starts the browser-based Snowflake sign-in when needed. This is separate from `dbt login`, which authenticates to dbt Platform.

Examples with a mode, node selection, or dbt variables, from the same target project directory.

```bash
bash ~/workspace/personal/scripts/make.sh --mode build
bash ~/workspace/personal/scripts/make.sh --mode run --select "staging.my_model marts.my_other_model"
bash ~/workspace/personal/scripts/make.sh --vars '{"variable": "value"}'
bash ~/workspace/personal/scripts/make.sh --strict
bash ~/workspace/personal/scripts/make.sh --help
```

The `--strict` option treats warnings as errors for every dbt command that runs, including `test`. It also disables partial parsing (`--no-partial-parse`) for `parse`, `compile`, `run`, and `test`, and shows all deprecations (`--show-all-deprecations`) for `parse` and `compile`. Strict mode does not change the selected execution mode.

Node selection is passed to `dbt compile` in `rebuild` mode, and to `dbt run` and `dbt test` when those commands run. JSON variables are passed only to `dbt run`.

## Deactivate the environment

In the shell where the environment was activated, using the absolute path

```bash
source ~/workspace/personal/scripts/deactivate.sh
```

This unsets `SNOWFLAKE_LOGIN_EMAIL` and the pip/certificate variables, deactivates the virtual environment, stops the SSH agent if `SSH_AGENT_PID` is set, and removes files from `logs`. The `HTTP_PROXY` and `HTTPS_PROXY` variables are not unset.

## Uninstall

Run the uninstaller from the repository root:

```bash
bash ./scripts/uninstall.sh
```

After confirmation, it removes the configured `.virtualenv_<version>/` directory and `logs/`. It keeps the certificate and SSH key. If this repository's virtual environment is active, deactivate it first with `source ./scripts/deactivate.sh`.

## Path configuration

The scripts derive repository paths from their own locations. Installation, initial activation, configuration, and uninstall examples assume the scripts repository root. The dbt execution examples instead use the target dbt project as the working directory and an absolute path to the scripts repository. Logs and the virtual environment remain in the scripts repository.

## Developer documentation

- [Architecture and decisions (ADR, English)](docs/en/architecture.md)
- [Architecture et décisions (ADR, français)](docs/fr/architecture.md)
- [Bash specifics (English)](docs/en/bash-specifics.md)
- [Spécificités Bash (français)](docs/fr/bash-specifics.md)

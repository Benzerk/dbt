# Architecture and decisions (ADR)

[Version française](../fr/architecture.md)

## Scope

This repository provides local scripts to prepare a Python environment and run dbt with Snowflake from Git Bash on Windows. It does not describe the data model architecture of the dbt project being executed.

Shared configuration is loaded by the scripts that need it. The user activates the environment in the current shell, then runs `make.sh` from the target dbt project directory. Virtual environment, certificate, and log paths are computed relative to the scripts repository; the working directory remains that of the caller.

## Tracking convention

The ADRs below are retrospective observations of the code as of 2026-10-23, not evidence of historical approval. Their context and consequences explain the current behavior; the original motivations remain to be confirmed. The alternatives mentioned are options for comparison, not options known to have been evaluated in the past.

For a new decision, add a sequential identifier and use the template at the end of this file. Available statuses are **proposed**, **accepted**, **rejected**, **superseded**, or **observed** for existing decisions without known historical approval. When a decision is superseded, preserve its content and add a link to its successor.

## ADR-001: use Bash and separate sourcing from execution

- Status: observed.
- Documentation date: 2026-10-23.
- References: [activate.sh](../../activate.sh), [deactivate.sh](../../deactivate.sh), [make.sh](../../make.sh).

### Context

The target workstation uses Git Bash on Windows. Python activation and environment variables must persist in the user's shell, unlike installation or dbt processing operations.

### Observed decision

Use Bash. Source `config.sh`, `activate.sh`, and `deactivate.sh`; execute `install.sh`, `make.sh`, and `uninstall.sh` in separate processes. The scripts reject the wrong invocation mode.

### Consequences and alternatives

The activated environment remains available to subsequent commands. However, sourced scripts modify the current shell, and this solution is not directly portable to PowerShell or `sh`. Possible alternatives include native PowerShell scripts or a dedicated launcher. Bash idioms are detailed in the [French](../fr/bash-specifics.md) and [English](bash-specifics.md) guides.

## ADR-002: centralize local configuration

- Status: observed.
- Documentation date: 2026-10-23.
- Reference: [config.sh](../../config.sh).

### Context

Several scripts use the same paths, Python version, and workstation network settings.

### Observed decision

Group these values in `config.sh`. Compute paths relative to the configuration file rather than the current directory. Export proxy, certificate, and pip settings, along with the Snowflake login identifier, to child processes.

### Consequences and alternatives

Paths remain consistent regardless of the calling directory. Configuration remains workstation-specific, and exports overwrite existing values. This is not a secrets manager: do not add passwords, tokens, or private keys. Possible alternatives include an untracked local configuration file or values supplied through the environment.

## ADR-003: orchestrate dbt with explicit modes

- Status: observed.
- Documentation date: 2026-10-23.
- Reference: [make.sh](../../make.sh).

### Context

The required commands differ between a full rebuild, a regular run with tests, and a run without tests.

### Observed decision

Centralize the sequence in `make.sh`. The default `rebuild` mode performs cleaning, dependency upgrades, parsing, compilation, execution with `--full-refresh`, and then testing. `build` runs `dbt run` followed by `dbt test`; `run` skips tests. The latter two modes exclude models materialized as views. The script's `build` mode is therefore not the `dbt build` command.

The `--strict` option strengthens checks without changing the chosen mode. Selection is passed to the applicable compilation, execution, and test commands; JSON variables are passed only to `dbt run`.

### Consequences and alternatives

Sequences are explicit and reusable, but the default rebuild can be costly, and `deps --upgrade` can change dbt dependencies. Excluding views assumes they are already available and up to date. Possible alternatives include manual commands or orchestration based on `dbt build`, with behavioral differences to evaluate.

## ADR-004: log every dbt operation and stop on its failure

- Status: observed.
- Documentation date: 2026-10-23.
- References: [make.sh](../../make.sh), [activate.sh](../../activate.sh), [deactivate.sh](../../deactivate.sh).

### Context

A run includes several commands; their output must be visible live, and the failing command must be identifiable afterward.

### Observed decision

The `run_dbt_operation` function duplicates standard output and standard error to the terminal and a timestamped file using `tee`. It immediately checks dbt's exit status through `PIPESTATUS[0]`, waits for keyboard confirmation, and terminates the script on failure.

### Consequences and alternatives

Logs are available per operation without hiding a dbt failure behind a successful `tee` command. Failures of `tee` itself are not checked. Waiting for keyboard input makes this an interactive workflow rather than one suitable for CI without adaptation. Log files are deleted during activation and deactivation, so this is not durable archiving. One possible alternative is logging and exit-code handling tailored to a scheduler or CI.

## ADR-005: check the Snowflake connection before processing

- Status: observed.
- Documentation date: 2026-10-23.
- References: [make.sh](../../make.sh), [README](../../README.md).

### Context

Processing depends on a valid Snowflake connection. Snowflake authentication is separate from dbt Platform authentication and SSH operations to GitHub.

### Observed decision

Run `dbt debug` first in every mode. For browser-based SSO, the user configures `authenticator: externalbrowser` in the active output of their dbt profile. The script does not create this profile or replace this step with `dbt login`.

### Consequences and alternatives

A connection error interrupts the workflow before subsequent processing. SSO may require browser interaction; this method is not an automated authentication strategy for CI. One possible alternative is a non-interactive mechanism approved for the target environment.

## ADR-006: pin chardet to 5.2.0 to avoid a Requests warning

- Status: observed.
- Documentation date: 2026-10-23.
- References: [requirements.txt](../../requirements.txt), [Requests #7284](https://github.com/psf/requests/issues/7284).

### Context

Requests may use `chardet` as an optional encoding-detection dependency when it is installed. Issue #7284 describes a `RequestsDependencyWarning` when importing Requests with a `chardet` version outside the supported range. In the reported case, Requests 2.32.5 expects a `chardet` version below 6; this constraint should not be generalized to all future Requests versions.

### Observed decision

Explicitly pin `chardet==5.2.0` in `requirements.txt` to avoid this warning in the project environment rather than suppressing warnings. The dependency comment references the issue to preserve the reason for the pin.

### Consequences and alternatives

The installed `chardet` version is deterministic, but it no longer receives automatic updates. Reassess this pin when updating Requests or other dependencies, and verify that the warning is absent in a reinstalled environment before removing it. The issue explains the original problem; it does not by itself prove that the workaround remains necessary with every new Requests version.

Possible alternatives include using a newer compatible version combination, or removing `chardet` and letting Requests use `charset-normalizer` if no other dependency requires `chardet`. Globally suppressing warnings would hide other incompatibilities and is not the chosen solution.

## Template for a new decision

```markdown
## ADR-NNN: decision title

- Status: proposed.
- Date: YYYY-MM-DD.
- References: links to code, an issue, or a pull request.

### Context

Problem, constraints, and selection criteria.

### Decision

Chosen solution and scope.

### Consequences and alternatives

Benefits, costs, risks, and rejected options with their reasons.
```
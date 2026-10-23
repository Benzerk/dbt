#!/bin/bash
#
# make.sh - Clean, rebuild (optional), run and test a dbt project.
#
# Usage:
#   bash scripts/make.sh [-m rebuild|run] [-s "<dbt selection>"] [-v '<json>'] [--strict]
#
# Must be executed, not sourced (sourcing runs dbt in the calling shell and may exit that shell on help or error).
#
# Options:
#   -m, --mode <rebuild|build|run>      rebuild: dbt clean/deps/parse/compile, then dbt run --full-refresh (default), then dbt test
#                                       build: skip clean/deps/parse/compile, then standard incremental dbt run, then dbt test
#                                       run: skip clean/deps/parse/compile, then standard incremental dbt run, then skip dbt test
#   -s, --select "<dbt node selection>" Node selection passed to dbt run/test, without the --select flag itself 
#                                       (default: none, selects the whole project)
#   -v, --vars '<json>'                 JSON passed to the dbt run command via --vars
#                                       (default: none)
#       --strict                        Treat dbt warnings as errors and show all deprecations
#   -h, --help                          Show this help message and exit
#
# Examples:
#   bash scripts/make.sh
#   bash scripts/make.sh --mode run
#   bash scripts/make.sh --select "raw.raw_pi2 intermediate.int_product exposure.dp_product exposure.dp_product_legacy"
#   bash scripts/make.sh --vars '{"variable": "value"}'
#

# Prevent sourcing instead of executing
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    echo 'Error: run this script with bash scripts/make.sh; do not source it.' >&2
    return 1
fi
usage() {
    sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
}

# Load the shared configuration settings for the dbt helper scripts.
source "$(dirname -- "${BASH_SOURCE[0]}")/../config/config.sh"

mkdir -p "$local_logs_dir"
selected_nodes=''
mode='rebuild'
dbt_vars=''
strict=false

while [[ $# -gt 0 ]];
do
    case "$1" in
        -m|--mode)
            if [[ $# -lt 2 ]];
            then
                echo "Missing value for $1"
                usage
                exit 1
            fi
            mode="$2"
            shift 2
            ;;
        -s|--select)
            if [[ $# -lt 2 ]];
            then
                echo "Missing value for $1"
                usage
                exit 1
            fi
            selected_nodes="$2"
            shift 2
            ;;
        -v|--vars)
            if [[ $# -lt 2 ]];
            then
                echo "Missing value for $1"
                usage
                exit 1
            fi
            dbt_vars="$2"
            shift 2
            ;;
        --strict)
            strict=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ "$mode" != "rebuild" && "$mode" != "build" && "$mode" != "run" ]]; then
    echo "Invalid --mode: '$mode' (expected rebuild|build|run)"
    exit 1
fi

selection=''
if [[ -n "$selected_nodes" ]]; then
    selection="--select $selected_nodes"
fi

vars_arg=()
if [[ -n "$dbt_vars" ]]; then
    vars_arg=(--vars "$dbt_vars")
fi

strict_warning_args=()
strict_parse_args=()
strict_deprecation_args=()
if [[ "$strict" = true ]]; then
    strict_warning_args=(--warn-error)
    strict_parse_args=(--no-partial-parse)
    strict_deprecation_args=(--show-all-deprecations)
fi

# Runs a dbt command, streams its output live via tee while also saving it to a log file, and stops the whole script if the command fails.
run_dbt_operation() {
    local description="$1"
    local timestamp=$(date +"%Y%m%d%H%M%S")
    local dbt_command="$3"
    local logs_filepath="${local_logs_dir%/}/dbt_${dbt_command}_output_${timestamp}.log"
    shift 1
    
    echo "Starting action: ${description}"
    echo "Running dbt command: $@"
    "$@" 2>&1 | tee "$logs_filepath"
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        echo "Detected errors. Please check file ${logs_filepath} for details."
        read -p "Press enter to exit."
        exit 1;
    fi
}

# dbt debug triggers Snowflake SSO through the configured profile
run_dbt_operation "Snowflake SSO" dbt debug "${strict_warning_args[@]}"

# DBT Clean
if [[ "$mode" = "rebuild" ]]; then
    run_dbt_operation "Clean" dbt clean "${strict_warning_args[@]}"
elif [[ "$mode" = "build" ]] || [[ "$mode" = "run" ]]; then
    echo "Skipping action: Clean"
fi

# DBT Deps
if [[ "$mode" = "rebuild" ]]; then
    run_dbt_operation "Dependencies Upgrade" dbt deps --upgrade "${strict_warning_args[@]}"
elif [[ "$mode" = "build" ]] || [[ "$mode" = "run" ]]; then
    echo "Skipping action: Dependencies Upgrade"
fi

# DBT Parse
if [[ "$mode" = "rebuild" ]]; then
    run_dbt_operation "Parse" dbt parse "${strict_warning_args[@]}" "${strict_parse_args[@]}" "${strict_deprecation_args[@]}"
elif [[ "$mode" = "build" ]] || [[ "$mode" = "run" ]]; then
    echo "Skipping action: Parse"
fi

# DBT Compile
if [[ "$mode" = "rebuild" ]]; then
    run_dbt_operation "Compile" dbt compile $selection "${strict_warning_args[@]}" "${strict_parse_args[@]}" "${strict_deprecation_args[@]}"
elif [[ "$mode" = "build" ]] || [[ "$mode" = "run" ]]; then
    echo "Skipping action: Compile"
fi

# DBT Run
if [[ "$mode" = "rebuild" ]]; then
    run_dbt_operation "Run (Full Refresh)" dbt run $selection --full-refresh "${vars_arg[@]}" "${strict_warning_args[@]}" "${strict_parse_args[@]}"
elif [[ "$mode" = "build" ]] || [[ "$mode" = "run" ]]; then
    run_dbt_operation "Run (Standard)" dbt run $selection --exclude config.materialized:view "${vars_arg[@]}" "${strict_warning_args[@]}" "${strict_parse_args[@]}"
fi

# DBT Test
if [[ "$mode" = "rebuild" ]] || [[ "$mode" = "build" ]]; then
    run_dbt_operation "Test" dbt test $selection "${strict_warning_args[@]}" "${strict_parse_args[@]}"
elif [[ "$mode" = "run" ]]; then
    echo "Skipping action: Test"
fi

#!/usr/bin/env bash

check_requirements_changes() {
    if [[ -n "$TERM" && "$TERM" != "dumb" && "$TERM" != "unknown" ]]; then
        BOLD='\033[1m'
        BLINK='\033[5m'
        ORANGE='\033[38;5;214m'
        RESET='\033[0m'
    else
        BOLD=''
        BLINK=''
        ORANGE=''
        RESET=''
    fi
    changed_files=$(git diff --name-only -- '**requirements*.system' 2>/dev/null)

    if [ -n "$changed_files" ]; then
        printf "    ${BOLD}${BLINK}${ORANGE}WARNING:${RESET} Requirements file changes. Rebuild the ADORe CLI with 'make build_adore_cli' so that the changes take effect.\n"
        printf "    The following requirements files have changed:\n"
        echo "$changed_files" | sed 's/^/        /'
        printf "    Commit or discard changes to these files to clear this message.\n"
    fi

    
}


check_requirements_changes

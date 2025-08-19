#!/usr/bin/env bash

set -euo pipefail

# Tag History Management for ADORe CLI
# This script manages successful environment tags and provides simple storage/retrieval

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Color definitions - conservative detection
if [[ -n "${TERM:-}" && "$TERM" != "dumb" && "$TERM" != "unknown" ]] && [[ -z "${NO_COLOR:-}" ]] && { [[ -t 1 ]] || [[ -t 2 ]]; }; then
    BOLD='\033[1m'
    RED='\033[31m'
    GREEN='\033[32m'
    YELLOW='\033[33m'
    BLUE='\033[34m'
    CYAN='\033[36m'
    RESET='\033[0m'
else
    BOLD='' RED='' GREEN='' YELLOW='' BLUE='' CYAN='' RESET=''
fi

# Configuration
SOURCE_DIRECTORY="${SOURCE_DIRECTORY:-$(realpath "${SCRIPT_DIRECTORY}/..")}"
TAG_HISTORY_FILE="${SOURCE_DIRECTORY}/.log/.adore_cli/tag_history"
LAST_SUCCESSFUL_FILE="${SOURCE_DIRECTORY}/.log/.adore_cli/last_successful_env"

# Ensure directories exist
mkdir -p "$(dirname "${TAG_HISTORY_FILE}")"
mkdir -p "$(dirname "${LAST_SUCCESSFUL_FILE}")"

# Function to log messages
log_info() {
    printf "${BLUE}INFO:${RESET} %s\n" "$*" >&2
}

log_warn() {
    printf "${YELLOW}WARNING:${RESET} %s\n" "$*" >&2
}

log_error() {
    printf "${RED}ERROR:${RESET} %s\n" "$*" >&2
}

log_success() {
    printf "${GREEN}SUCCESS:${RESET} %s\n" "$*" >&2
}

log_debug() {
    if [[ "${DEBUG:-}" == "1" ]]; then
        printf "${CYAN}DEBUG:${RESET} %s\n" "$*" >&2
    fi
}

# Function to save successful environment
# Function to save successful environment
save_successful_environment() {
    local base_tag="$1"
    local core_tag="$2" 
    local user_tag="$3"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    log_debug "Saving successful environment: $user_tag"
    
    # Append to history file
    printf "%s|%s|%s|%s|%s\n" "$timestamp" "$base_tag" "$core_tag" "$user_tag" "SUCCESS" >> "$TAG_HISTORY_FILE"
    
    # Save as last successful
    cat > "$LAST_SUCCESSFUL_FILE" << EOL
# Last successful ADORe CLI environment
# Generated: $timestamp
LAST_BASE_TAG="$base_tag"
LAST_CORE_TAG="$core_tag" 
LAST_USER_TAG="$user_tag"
LAST_SUCCESS_TIME="$timestamp"
EOL
    
    log_success "Environment saved successfully: $user_tag"
}

# Function to get last successful core tag
get_last_successful_core() {
    if [[ -f "$LAST_SUCCESSFUL_FILE" ]]; then
        if LAST_CORE_TAG=$(source "$LAST_SUCCESSFUL_FILE" 2>/dev/null && echo "${LAST_CORE_TAG:-}"); then
            if [[ -n "$LAST_CORE_TAG" ]]; then
                echo "$LAST_CORE_TAG"
                return 0
            fi
        fi
    fi
    return 1
}

# Function to get last successful environment
get_last_successful_environment() {
    if [[ -f "$LAST_SUCCESSFUL_FILE" ]]; then
        # Source the file and extract the user tag
        if LAST_USER_TAG=$(source "$LAST_SUCCESSFUL_FILE" 2>/dev/null && echo "${LAST_USER_TAG:-}"); then
            if [[ -n "$LAST_USER_TAG" ]]; then
                echo "$LAST_USER_TAG"
                return 0
            fi
        fi
    fi
    return 1
}

# Function to check if environment exists
check_environment_exists() {
    local user_tag="$1"
    
    log_debug "Checking if environment exists: adore_cli:$user_tag"
    
    if docker image inspect "adore_cli:$user_tag" >/dev/null 2>&1; then
        log_debug "Environment exists: adore_cli:$user_tag"
        return 0
    fi
    
    log_debug "Environment does not exist: adore_cli:$user_tag"
    return 1
}

# Function to show tag history
show_history() {
    if [[ -f "$TAG_HISTORY_FILE" ]]; then
        echo "=== Tag History ==="
        echo "Timestamp                | Base Tag                  | Core Tag                  | User Tag                  | Status"
        echo "-------------------------|---------------------------|---------------------------|---------------------------|--------"
        tail -10 "$TAG_HISTORY_FILE" | while IFS='|' read -r timestamp base core user status; do
            printf "%-24s | %-25s | %-25s | %-25s | %s\n" \
                "$timestamp" \
                "$(echo "$base" | cut -c1-25)" \
                "$(echo "$core" | cut -c1-25)" \
                "$(echo "$user" | cut -c1-25)" \
                "$status"
        done
    else
        echo "No tag history found"
    fi
}

# Function to clean old history entries (keep last 50)
clean_history() {
    if [[ -f "$TAG_HISTORY_FILE" ]]; then
        local temp_file="${TAG_HISTORY_FILE}.tmp"
        tail -50 "$TAG_HISTORY_FILE" > "$temp_file"
        mv "$temp_file" "$TAG_HISTORY_FILE"
        log_info "Cleaned old history entries, kept last 50"
    fi
}

# Main entry point
main() {
    local command="${1:-}"
    
    log_debug "Main called with command: $command, args: $*"
    
    case "$command" in
        save)
            if [[ $# -ne 4 ]]; then
                log_error "Save command requires 3 arguments: base_tag core_tag user_tag"
                exit 1
            fi
            save_successful_environment "$2" "$3" "$4"
            ;;
        get_last)
            get_last_successful_environment
            ;;
        get_last_core)
            get_last_successful_core
            ;;
        check_exists)
            if [[ $# -ne 2 ]]; then
                log_error "Check_exists command requires 1 argument: user_tag"
                exit 1
            fi
            check_environment_exists "$2"
            ;;
        show|history)
            show_history
            ;;
        clean)
            clean_history
            ;;
        *)
            log_error "Unknown command: $command"
            printf "Usage: %s {save|get_last|check_exists|show|clean}\n" "$0" >&2
            printf "\n"
            printf "Commands:\n"
            printf "  save <base> <core> <user>  Save successful environment\n"
            printf "  get_last                   Get last successful user tag\n"
            printf "  check_exists <user>        Check if environment exists\n"
            printf "  show                       Show tag history\n"
            printf "  clean                      Clean old history entries\n"
            exit 1
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

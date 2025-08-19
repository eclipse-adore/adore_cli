#!/usr/bin/env bash

set -euo pipefail

# Tag History Management for ADORe CLI
# This script manages successful environment tags and handles change detection

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Color definitions - be more conservative about color detection
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
ACTION_FILE="${SOURCE_DIRECTORY}/.log/.adore_cli/temp/user_action"

# Ensure directories exist
mkdir -p "$(dirname "${TAG_HISTORY_FILE}")"
mkdir -p "$(dirname "${LAST_SUCCESSFUL_FILE}")"
mkdir -p "$(dirname "${ACTION_FILE}")"

# Function to detect if we're in interactive mode
# Function to detect if we're in interactive mode
is_interactive() {
    # Allow explicit override
    if [[ "${FORCE_INTERACTIVE:-}" == "true" ]]; then
        return 0
    fi
    
    if [[ "${FORCE_NON_INTERACTIVE:-}" == "true" ]] || [[ -n "${CI:-}" ]] || [[ -n "${NON_INTERACTIVE:-}" ]] || [[ -n "${ADORE_CLI_NON_INTERACTIVE:-}" ]]; then
        return 1
    fi
    
    # Special case: if we're being called from make cli, we want to be interactive
    # Check if we have a controlling terminal and TERM is set
    if [[ -n "${TERM:-}" ]] && [[ "$TERM" != "dumb" ]]; then
        # Check if stderr is a terminal (make usually preserves this)
        if [[ -t 2 ]]; then
            return 0
        fi
        # Check if we can access the controlling terminal
        if [[ -c /dev/tty ]] && exec 3< /dev/tty 2>/dev/null; then
            exec 3<&-
            return 0
        fi
    fi
    
    # Fallback: check standard TTY detection
    if [[ -t 0 ]] && [[ -t 1 ]]; then
        return 0
    fi
    
    return 1
}

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

# Function to validate user input
validate_choice() {
    local choice="$1"
    case "${choice,,}" in
        c|continue|keep) echo "keep" ;;
        b|build) echo "build" ;;
        a|abort) echo "abort" ;;
        "") echo "keep" ;;
        *) echo "invalid" ;;
    esac
}

# Function to prompt user for action
prompt_user_action() {
    local change_type="$1"
    local old_tag="$2"
    local new_tag="$3"
    
    log_debug "Prompting user for action. Interactive: $(is_interactive && echo "true" || echo "false")"
    
    # Ensure we're writing to the terminal and reading from it
    exec 1>&2  # Redirect stdout to stderr so all output goes to terminal
    
    printf "\n${BOLD}${YELLOW}=== DEVELOPMENT ENVIRONMENT CHANGE DETECTED ===${RESET}\n"
    printf "\n"
    printf "Detected change: ${CYAN}%s${RESET}\n" "$change_type"
    printf "\n"
    printf "Your current working environment ID:\n"
    printf "  ${GREEN}%s${RESET}\n" "$(echo "$old_tag" | sed 's/_/ /g' | cut -c1-60)..."
    printf "\n"
    printf "New calculated environment ID:\n"
    printf "  ${YELLOW}%s${RESET}\n" "$(echo "$new_tag" | sed 's/_/ /g' | cut -c1-60)..."
    printf "\n"
    
    printf "${BOLD}What would you like to do?${RESET}\n"
    printf "\n"
    printf "  ${GREEN}[C] Continue${RESET}\n"
    printf "      → Keep using your current working environment\n"
    printf "      → Ignore the detected changes for now\n"
    printf "      → Your development work continues uninterrupted\n"
    printf "\n"
    printf "  ${YELLOW}[B] Build${RESET}\n"
    printf "      → Build a new environment with your current changes\n"
    printf "      → Takes time but ensures latest dependencies\n"
    printf "      → Recommended if you need the changes to work\n"
    printf "\n"
    printf "  ${RED}[A] Abort${RESET}\n"
    printf "      → Cancel this operation and exit\n"
    printf "      → Nothing will be changed or started\n"
    printf "\n"
    printf "${BOLD}💡 Recommendation:${RESET} Choose [C] to continue with your working environment\n"
    printf "\n"
    
    local choice=""
    local attempts=0
    local max_attempts=3
    
    while [[ $attempts -lt $max_attempts ]]; do
        printf "What action would you like to take? [c] Continue, [b] Build, [a] Abort > "
        
        # Try to read from /dev/tty if available, otherwise from stdin
        if [[ -r /dev/tty ]]; then
            read -r choice < /dev/tty || {
                log_error "Failed to read user input from /dev/tty"
                echo "abort"
                return 1
            }
        else
            read -r choice || {
                log_error "Failed to read user input from stdin"
                echo "abort"
                return 1
            }
        fi
        
        local validated_choice
        validated_choice=$(validate_choice "$choice")
        
        case "$validated_choice" in
            keep)
                printf "${GREEN}→ Continuing with your current working environment${RESET}\n"
                echo "keep"
                return 0
                ;;
            build)
                printf "${YELLOW}→ Building new environment with current changes${RESET}\n"
                echo "build"
                return 0
                ;;
            abort)
                printf "${RED}→ Aborting operation${RESET}\n"
                echo "abort"
                return 0
                ;;
            invalid)
                printf "${RED}Invalid choice. Please enter c, b, or a${RESET}\n"
                ((attempts++))
                if [[ $attempts -ge $max_attempts ]]; then
                    log_error "Too many invalid attempts, aborting"
                    echo "abort"
                    return 1
                fi
                ;;
        esac
    done
    
    log_error "Unexpected exit from prompt loop"
    echo "abort"
    return 1
}


# Function to save successful environment
save_successful_environment() {
    local base_tag="$1"
    local core_tag="$2" 
    local user_tag="$3"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    log_debug "Saving successful environment: $user_tag"
    
    printf "%s|%s|%s|%s|%s\n" "$timestamp" "$base_tag" "$core_tag" "$user_tag" "SUCCESS" >> "$TAG_HISTORY_FILE"
    
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

# Function to get last successful environment
get_last_successful_environment() {
    if [[ -f "$LAST_SUCCESSFUL_FILE" ]]; then
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

# Function to extract hash components from tags for better comparison
extract_tag_components() {
    local tag="$1"
    local -A components=()
    
    # Extract various hash types (case insensitive)
    if [[ "$tag" =~ [Rr][Hh]([a-f0-9]{7}) ]]; then
        components[requirements_hash]="${BASH_REMATCH[1],,}"
    fi
    
    if [[ "$tag" =~ [Pp][Hh]([a-f0-9]{7}) ]]; then
        components[packages_hash]="${BASH_REMATCH[1],,}"
    fi
    
    # Extract git hashes (typically 7 character hex after branch name)
    local parts=($(echo "$tag" | tr '_' ' '))
    if [[ ${#parts[@]} -ge 3 ]]; then
        # Look for git hash patterns
        for part in "${parts[@]}"; do
            if [[ "$part" =~ ^[a-f0-9]{7}$ ]]; then
                if [[ -z "${components[git_hash1]:-}" ]]; then
                    components[git_hash1]="$part"
                elif [[ -z "${components[git_hash2]:-}" ]]; then
                    components[git_hash2]="$part"
                fi
            fi
        done
    fi
    
    # Return as space-separated key=value pairs for easy parsing
    printf "requirements_hash=%s packages_hash=%s git_hash1=%s git_hash2=%s" \
        "${components[requirements_hash]:-}" \
        "${components[packages_hash]:-}" \
        "${components[git_hash1]:-}" \
        "${components[git_hash2]:-}"
}

# Function to determine change reason with better logic
determine_change_reason() {
    local old_tag="$1"
    local new_tag="$2"
    
    log_debug "Analyzing changes between tags:"
    log_debug "  Old: $old_tag"
    log_debug "  New: $new_tag"
    
    local old_components new_components
    old_components=$(extract_tag_components "$old_tag")
    new_components=$(extract_tag_components "$new_tag")
    
    log_debug "  Old components: $old_components"
    log_debug "  New components: $new_components"
    
    # Parse components into arrays
    declare -A old_comp new_comp
    eval "$(echo "$old_components" | tr ' ' '\n' | while IFS='=' read -r key value; do
        echo "old_comp[$key]='$value'"
    done)"
    eval "$(echo "$new_components" | tr ' ' '\n' | while IFS='=' read -r key value; do
        echo "new_comp[$key]='$value'"
    done)"
    
    # Check what changed
    if [[ "${old_comp[requirements_hash]:-}" != "${new_comp[requirements_hash]:-}" ]] && [[ -n "${new_comp[requirements_hash]:-}" ]]; then
        echo "Requirements files changed"
    elif [[ "${old_comp[packages_hash]:-}" != "${new_comp[packages_hash]:-}" ]] && [[ -n "${new_comp[packages_hash]:-}" ]]; then
        echo "Package dependencies changed"
    elif [[ "${old_comp[git_hash1]:-}" != "${new_comp[git_hash1]:-}" ]] || [[ "${old_comp[git_hash2]:-}" != "${new_comp[git_hash2]:-}" ]]; then
        echo "Git repository state changed"
    else
        echo "Environment configuration changed"
    fi
}

# Enhanced function to handle tag changes with better logic
handle_tag_changes() {
    local last_successful_tag="${1:-}"
    local calculated_tag="${2:-}"
    
    log_debug "Handling tag changes: last_successful='$last_successful_tag' calculated='$calculated_tag'"
    
    # If no last successful tag, need to build
    if [[ -z "$last_successful_tag" ]]; then
        log_debug "No last successful environment found, need to build"
        echo "build_new"
        return 0
    fi
    
    # If tags are identical, check if environment exists
    if [[ "$last_successful_tag" == "$calculated_tag" ]]; then
        log_debug "Tags are identical"
        if check_environment_exists "$calculated_tag"; then
            log_debug "Environment exists, using current"
            echo "use_current"
            return 0
        else
            log_debug "Environment missing, need to build"
            echo "build_missing"
            return 0
        fi
    fi
    
    log_debug "Tags are different, analyzing changes"
    
    # Check if calculated environment already exists
    if check_environment_exists "$calculated_tag"; then
        log_debug "Calculated environment already exists, using it"
        echo "use_current"
        return 0
    fi
    
    # Determine what changed
    local change_reason
    change_reason=$(determine_change_reason "$last_successful_tag" "$calculated_tag")
    log_debug "Change reason: $change_reason"
    
    # Check if the last successful environment still exists
    local last_successful_exists=false
    if check_environment_exists "$last_successful_tag"; then
        last_successful_exists=true
        log_debug "Last successful environment still exists"
    else
        log_debug "Last successful environment no longer exists"
    fi
    
    # For non-interactive mode, make intelligent decisions
    if ! is_interactive; then
        log_debug "Non-interactive mode, making automatic decision"
        
        case "$change_reason" in
            "Requirements files changed"|"Package dependencies changed")
                log_info "Dependencies changed - building new environment (non-interactive)"
                echo "build_new"
                ;;
            *)
                if [[ "$last_successful_exists" == "true" ]]; then
                    log_info "Configuration changed - keeping last successful environment (non-interactive)"
                    echo "use_last_successful"
                else
                    log_info "Last successful environment missing - building new one (non-interactive)"
                    echo "build_new"
                fi
                ;;
        esac
        return 0
    fi
    
    # Interactive mode - prompt user
    log_debug "Interactive mode, prompting user"
    local action
    action=$(prompt_user_action "$change_reason" "$last_successful_tag" "$calculated_tag")
    local prompt_exit_code=$?
    
    log_debug "User action: '$action' (exit code: $prompt_exit_code)"
    
    if [[ $prompt_exit_code -ne 0 ]] || [[ -z "$action" ]]; then
        log_error "Failed to get user action or empty action returned"
        echo "abort"
        return 1
    fi
    
    case "$action" in
        keep)
            log_debug "User chose to keep current environment"
            if [[ "$last_successful_exists" == "true" ]]; then
                echo "use_last_successful"
            else
                log_warn "Last successful environment no longer exists, building new one"
                echo "build_new"
            fi
            ;;
        build)
            log_debug "User chose to build new environment"
            echo "build_new"
            ;;
        abort)
            log_debug "User chose to abort"
            echo "abort"
            ;;
        *)
            log_error "Invalid action returned: '$action'"
            echo "abort"
            ;;
    esac
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
        check_changes)
            if [[ $# -ne 3 ]]; then
                log_error "Check_changes command requires 2 arguments: last_successful_tag calculated_tag"
                exit 1
            fi
            handle_tag_changes "$2" "$3"
            ;;
        check_exists)
            if [[ $# -ne 2 ]]; then
                log_error "Check_exists command requires 1 argument: user_tag"
                exit 1
            fi
            check_environment_exists "$2"
            ;;
        *)
            log_error "Unknown command: $command"
            printf "Usage: %s {save|get_last|check_changes|check_exists}\n" "$0" >&2
            exit 1
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

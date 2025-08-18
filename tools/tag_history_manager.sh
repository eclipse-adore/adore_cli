#!/usr/bin/env bash

set -euo pipefail

# Tag History Management for ADORe CLI
# This script manages successful environment tags and handles change detection

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Color definitions
if [[ -n "$TERM" && "$TERM" != "dumb" && "$TERM" != "unknown" ]] && [[ -z "${NO_COLOR:-}" ]]; then
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

# Function to detect if we're in interactive mode
is_interactive() {
    # Check if stdin is a terminal and we're not in CI or explicitly non-interactive
    [[ -t 0 ]] && [[ -z "${CI:-}" ]] && [[ -z "${NON_INTERACTIVE:-}" ]] && [[ -z "${ADORE_CLI_NON_INTERACTIVE:-}" ]]
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

# Function to validate user input
validate_choice() {
    local choice="$1"
    case "$choice" in
        [Cc]|[Cc][Oo][Nn][Tt][Ii][Nn][Uu][Ee]) echo "continue" ;;
        [Bb]|[Bb][Uu][Ii][Ll][Dd]) echo "build" ;;
        [Aa]|[Aa][Bb][Oo][Rr][Tt]) echo "abort" ;;
        *) echo "invalid" ;;
    esac
}

# Function to prompt user for action
prompt_user_action() {
    local change_type="$1"
    local old_tag="$2"
    local new_tag="$3"
    local available_envs="$4"
    
    # In non-interactive mode (like make run), always continue
    if ! is_interactive; then
        log_info "Non-interactive mode detected - continuing with existing environment"
        echo "continue"
        return 0
    fi
    
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
    
    while true; do
        read -p "Your choice [C/b/a]: " -r choice
        printf "\n"
        
        # Default to continue if user just presses enter
        if [[ -z "$choice" ]]; then
            choice="c"
        fi
        
        local validated_choice
        validated_choice=$(validate_choice "$choice")
        
        case "$validated_choice" in
            continue)
                printf "${GREEN}→ Continuing with your current working environment${RESET}\n"
                echo "continue"
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
                printf "${RED}Invalid choice. Please enter C, B, or A (or just press Enter for C).${RESET}\n"
                ;;
        esac
    done
}

# Function to save successful environment
save_successful_environment() {
    local base_tag="$1"
    local core_tag="$2" 
    local user_tag="$3"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Save to history file
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
    
    log_success "Environment saved successfully"
}

# Function to get last successful environment
get_last_successful_environment() {
    if [[ -f "$LAST_SUCCESSFUL_FILE" ]]; then
        source "$LAST_SUCCESSFUL_FILE" 2>/dev/null || true
        if [[ -n "${LAST_USER_TAG:-}" ]]; then
            echo "$LAST_USER_TAG"
            return 0
        fi
    fi
    return 1
}

# Function to get available environments
get_available_environments() {
    local environments=""
    
    # Check Docker images
    if command -v docker >/dev/null 2>&1; then
        environments=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^adore_cli:" | head -10)
    fi
    
    echo -e "$environments"
}

# Function to check if environment exists
check_environment_exists() {
    local user_tag="$1"
    
    # Check if Docker image exists
    if docker image inspect "adore_cli:$user_tag" >/dev/null 2>&1; then
        return 0
    fi
    
    # Check if container exists
    if docker ps -a --format "{{.Names}}" | grep -q "^adore_cli_${user_tag}$"; then
        return 0  
    fi
    
    return 1
}

# Main function to handle tag changes
handle_tag_changes() {
    local current_base_tag="$1"
    local current_core_tag="$2"
    local current_user_tag="$3"
    local calculated_base_tag="$4"
    local calculated_core_tag="$5"
    local calculated_user_tag="$6"
    local change_reason="$7"
    
    # If tags are identical, no action needed
    if [[ "$current_user_tag" == "$calculated_user_tag" ]]; then
        if check_environment_exists "$current_user_tag"; then
            echo "use_current"
            return 0
        else
            echo "build_missing"
            return 0
        fi
    fi
    
    # Check if last successful environment is still available
    local last_successful=""
    if last_successful=$(get_last_successful_environment); then
        if check_environment_exists "$last_successful"; then
            # If calculated tag matches last successful, use it
            if [[ "$calculated_user_tag" == "$last_successful" ]]; then
                echo "use_current"
                return 0
            fi
        fi
    fi
    
    # Get available environments
    local available_envs
    available_envs=$(get_available_environments)
    
    # Prompt user for action
    local action
    action=$(prompt_user_action "$change_reason" "$current_user_tag" "$calculated_user_tag" "$available_envs")
    
    case "$action" in
        continue)
            if check_environment_exists "$current_user_tag"; then
                echo "use_current"
            else
                log_warn "Current environment no longer exists, building new one"
                echo "build_new"
            fi
            ;;
        build)
            echo "build_new"
            ;;
        abort)
            echo "abort"
            ;;
        *)
            log_error "Unknown action returned: $action"
            echo "abort"
            ;;
    esac
}

# Main entry point
main() {
    local command="${1:-}"
    
    case "$command" in
        save)
            save_successful_environment "$2" "$3" "$4"
            ;;
        get_last)
            get_last_successful_environment
            ;;
        check_changes)
            handle_tag_changes "$2" "$3" "$4" "$5" "$6" "$7" "$8"
            ;;
        list_available)
            get_available_environments
            ;;
        check_exists)
            check_environment_exists "$2"
            ;;
        *)
            log_error "Unknown command: $command"
            printf "Usage: %s {save|get_last|check_changes|list_available|check_exists}\n" "$0"
            exit 1
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

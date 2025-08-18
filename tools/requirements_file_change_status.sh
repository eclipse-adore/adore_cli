#!/usr/bin/env bash
check_requirements_changes() {
    if [[ -n "$TERM" && "$TERM" != "dumb" && "$TERM" != "unknown" ]]; then
        BOLD='\033[1m'
        BLINK='\033[5m'
        ORANGE='\033[38;5;214m'
        GREEN='\033[32m'
        RESET='\033[0m'
    else
        BOLD=''
        BLINK=''
        ORANGE=''
        GREEN=''
        RESET=''
    fi
    
    # Calculate current requirements hash using same method as adore_cli.mk
    current_requirements_hash=""
    if [ -n "${SOURCE_DIRECTORY}" ] && [ -d "${SOURCE_DIRECTORY}" ]; then
        # Find all requirements files and calculate hash
        current_requirements_hash=$(find "${SOURCE_DIRECTORY}" -type f \( -name "*.system" -o -name "*.pip3" -o -name "*.ppa" \) \
            ! -path "*/ros_translator/*" \
            ! -path "*/.log/*" \
            ! -path "*/.git/*" \
            ! -path "*/build/*" \
            ! -path "*/.tmp/*" \
            2>/dev/null | \
            xargs -r cat 2>/dev/null | \
            sha256sum | cut -c1-7)
    fi
    
    # Get container requirements hash from CORE image tag (not user image tag)
    container_requirements_hash=""
    
    # Look for RH hash in the CORE image tag (requirements hash is in core layer)
    if [ -n "${ADORE_CLI_CORE_IMAGE}" ]; then
        # Extract requirements hash from core tag like: adore_cli_core:x86_64_main_abc1234_parent_def5678_RH9876543
        container_requirements_hash=$(echo "${ADORE_CLI_CORE_IMAGE}" | grep -o 'RH[a-f0-9]\{7\}' | cut -c3-)
    fi
    
    # If no hash in core image tag, check built tags file
    if [ -z "$container_requirements_hash" ] && [ -n "${SOURCE_DIRECTORY}" ]; then
        built_tags_file="${SOURCE_DIRECTORY}/.log/.adore_cli/built_tags"
        if [ -f "$built_tags_file" ]; then
            # Try to extract from CORE tag which should contain requirements hash
            core_tag=$(grep "^CORE=" "$built_tags_file" 2>/dev/null | cut -d'=' -f2)
            if [ -n "$core_tag" ]; then
                container_requirements_hash=$(echo "$core_tag" | grep -o 'RH[a-f0-9]\{7\}' | cut -c3-)
            fi
        fi
    fi
    
    # Compare hashes and show status
    if [ -z "$current_requirements_hash" ]; then
        printf "    ${ORANGE}INFO:${RESET} No requirements files found in project\n"
        return 0
    fi
    
    if [ -z "$container_requirements_hash" ]; then
        printf "    ${ORANGE}INFO:${RESET} Unable to determine container requirements hash\n"
        printf "    Current calculated requirements hash: ${current_requirements_hash}\n"
        printf "    Core image: ${ADORE_CLI_CORE_IMAGE:-NOT_SET}\n"
        return 0
    fi
    
    if [ "$current_requirements_hash" != "$container_requirements_hash" ]; then
        printf "    ${BOLD}${BLINK}${ORANGE}WARNING:${RESET} Requirements have changed since container was built!\n"
        printf "    Current requirements hash:   ${current_requirements_hash}\n"
        printf "    Container requirements hash: ${container_requirements_hash}\n"
        printf "\n"
        printf "    This means your requirements files (.system, .pip3, .ppa) have changed\n"
        printf "    since the ADORe CLI container was last built.\n"
        printf "\n"
        printf "    ${BOLD}How to resolve:${RESET}\n"
        printf "    1. Rebuild the ADORe CLI: ${GREEN}make build${RESET}\n"
        printf "    2. Or rebuild from core layer: ${GREEN}make rebuild_from_layer LAYER=core${RESET}\n"
        printf "    3. Then restart: ${GREEN}make cli${RESET}\n"
        printf "\n"
        printf "    ${BOLD}What changed:${RESET}\n"
        # Show which requirements files have uncommitted changes
        changed_files=$(git diff --name-only -- '**requirements*.system' '**requirements*.pip3' '**requirements*.ppa' 2>/dev/null)
        if [ -n "$changed_files" ]; then
            printf "    Uncommitted changes in:\n"
            echo "$changed_files" | sed 's/^/        /'
            printf "    Commit or discard these changes to clear git-related warnings.\n"
        else
            printf "    Requirements files may have been modified since last container build.\n"
        fi
    else
        printf "    ${GREEN}✓${RESET} Requirements are up to date (hash: ${current_requirements_hash})\n"
    fi
}

check_requirements_changes

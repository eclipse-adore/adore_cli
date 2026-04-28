#!/usr/bin/env bash
# ********************************************************************************
# Copyright (c) 2025 Contributors to the Eclipse Foundation
#
# See the NOTICE file(s) distributed with this work for additional
# information regarding copyright ownership.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# https://www.eclipse.org/legal/epl-2.0
#
# SPDX-License-Identifier: EPL-2.0
# ********************************************************************************


set -euo pipefail

LAST_TAG="$1"
CALCULATED_TAG="$2"
MAKEFILE_PATH="$3"

BOLD='\033[1m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
DIM='\033[2m'
RESET='\033[0m'

# Helper function to get image details (Tag, Age, Size)
get_image_info() {
    local tag="$1"
    docker images --format "{{.Tag}}|{{.CreatedSince}}|{{.Size}}" "adore_cli:$tag" 2>/dev/null | head -n 1
}

LAST_IMAGE_INFO=""
if [[ -n "$LAST_TAG" ]]; then
    LAST_IMAGE_INFO=$(get_image_info "$LAST_TAG")
fi

printf "\n${BOLD}${YELLOW}=== DEVELOPMENT ENVIRONMENT CHANGE DETECTED ===${RESET}\n"
printf "\n"

if [[ -n "$LAST_IMAGE_INFO" ]]; then
    IFS="|" read -r L_TAG L_AGE L_SIZE <<< "$LAST_IMAGE_INFO"
    printf "Last successful environment:\n"
    printf "  ${GREEN}%-40s${RESET} ${DIM}(%s, %s)${RESET}\n" "$(echo "$L_TAG" | cut -c1-40)" "$L_AGE" "$L_SIZE"
    printf "\n"
fi

printf "Calculated environment (no image present):\n"
printf "  ${YELLOW}%s${RESET}\n" "$(echo "$CALCULATED_TAG" | cut -c1-72)"
printf "\n"

printf "${BOLD}What would you like to do?${RESET}\n"
printf "\n"

if [[ -n "$LAST_IMAGE_INFO" ]]; then
    printf "  ${GREEN}[C] Continue${RESET}\n"
    printf "      → Run your last successful environment without rebuilding\n"
    printf "\n"
fi

printf "  ${YELLOW}[B] Build${RESET}\n"
printf "      → Build a new environment for the current state\n"
printf "\n"
printf "  ${BLUE}[S] Select${RESET}\n"
printf "      → Choose any local adore_cli image interactively\n"
printf "\n"
printf "  ${RED}[A] Abort${RESET}\n"
printf "      → Cancel and exit\n"
printf "\n"

if [[ -n "$LAST_IMAGE_INFO" ]]; then
    printf "${BOLD}💡 Recommendation:${RESET} Choose [C] to continue with your last working environment\n"
    printf "\n"
    printf "What action? [c] Continue, [b] Build, [s] Select, [a] Abort > "
else
    printf "${BOLD}💡 Recommendation:${RESET} Choose [B] to build a new environment\n"
    printf "\n"
    printf "What action? [b] Build, [s] Select, [a] Abort > "
fi

read -r USER_CHOICE < /dev/tty
printf "\n"

case "${USER_CHOICE,,}" in
    c|continue|"")
        if [[ -z "$LAST_IMAGE_INFO" ]]; then
            printf "${RED}No last successful environment is available. Use [b] to build or [s] to select.${RESET}\n"
            exit 1
        fi
        printf "${GREEN}→ Continuing with last successful environment${RESET}\n"
        exec make --file="$MAKEFILE_PATH/adore_cli.mk" _execute_environment_action \
            ADORE_CLI_USER_TAG="$LAST_TAG" \
            ADORE_CLI_IMAGE="adore_cli:$LAST_TAG" \
            ADORE_CLI_CONTAINER_NAME="adore_cli_${LAST_TAG}_$(whoami)"
        ;;
    b|build)
        printf "${YELLOW}→ Building new environment${RESET}\n"
        make --file="$MAKEFILE_PATH/adore_cli.mk" build_adore_cli
        exec make --file="$MAKEFILE_PATH/adore_cli.mk" _execute_environment_action
        ;;
    s|select)
        # Fetch Tag, CreatedSince, and Size
        mapfile -t RAW_IMAGES < <(docker images --format "{{.Tag}}|{{.CreatedSince}}|{{.Size}}" adore_cli 2>/dev/null | grep -v '^<none>' | sort -r || true)
        
        if [[ ${#RAW_IMAGES[@]} -eq 0 ]]; then
            printf "${RED}No local adore_cli images found.${RESET}\n"
            exit 1
        fi

        printf "${YELLOW}⚠  WARNING: Selected image may have incompatible dependencies.${RESET}\n\n"
        printf "${BOLD}%-4s %-45s %-20s %-10s${RESET}\n" "ID" "TAG" "CREATED" "SIZE"
        printf "%s\n" "--------------------------------------------------------------------------------------------"
        
        for i in "${!RAW_IMAGES[@]}"; do
            IFS="|" read -r T_TAG T_AGE T_SIZE <<< "${RAW_IMAGES[$i]}"
            printf " [%d] %-45s %-20s %-10s\n" "$((i+1))" "$(echo "$T_TAG" | cut -c1-45)" "$T_AGE" "$T_SIZE"
        done

        printf "\nSelect image [1-%d]: " "${#RAW_IMAGES[@]}"
        read -r SELECTION < /dev/tty
        printf "\n"

        if [[ ! "$SELECTION" =~ ^[0-9]+$ ]] || [[ "$SELECTION" -lt 1 ]] || [[ "$SELECTION" -gt ${#RAW_IMAGES[@]} ]]; then
            printf "${RED}Invalid selection, aborting.${RESET}\n"
            exit 1
        fi

        # Extract just the tag from the selected line
        SELECTED_RAW="${RAW_IMAGES[$((SELECTION-1))]}"
        SELECTED_TAG="${SELECTED_RAW%%|*}"

        printf "${BLUE}→ Using adore_cli:%s${RESET}\n" "$SELECTED_TAG"
        exec make --file="$MAKEFILE_PATH/adore_cli.mk" _execute_environment_action \
            ADORE_CLI_USER_TAG="$SELECTED_TAG" \
            ADORE_CLI_IMAGE="adore_cli:$SELECTED_TAG" \
            ADORE_CLI_CONTAINER_NAME="adore_cli_${SELECTED_TAG}_$(whoami)"
        ;;
    a|abort)
        printf "${RED}→ Aborted by user${RESET}\n"
        exit 1
        ;;
    *)
        printf "${RED}Invalid choice, aborting${RESET}\n"
        exit 1
        ;;
esac

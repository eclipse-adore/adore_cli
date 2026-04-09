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
RESET='\033[0m'

LAST_IMAGE_EXISTS="false"
if [[ -n "$LAST_TAG" ]] && docker image inspect "adore_cli:$LAST_TAG" >/dev/null 2>&1; then
    LAST_IMAGE_EXISTS="true"
fi

printf "\n${BOLD}${YELLOW}=== DEVELOPMENT ENVIRONMENT CHANGE DETECTED ===${RESET}\n"
printf "\n"

if [[ "$LAST_IMAGE_EXISTS" = "true" ]]; then
    printf "Last successful environment:\n"
    printf "  ${GREEN}%s${RESET}\n" "$(echo "$LAST_TAG" | cut -c1-72)"
    printf "\n"
fi

printf "Calculated environment (no image present):\n"
printf "  ${YELLOW}%s${RESET}\n" "$(echo "$CALCULATED_TAG" | cut -c1-72)"
printf "\n"
printf "${BOLD}What would you like to do?${RESET}\n"
printf "\n"

if [[ "$LAST_IMAGE_EXISTS" = "true" ]]; then
    printf "  ${GREEN}[C] Continue${RESET}\n"
    printf "      → Run your last successful environment without rebuilding\n"
    printf "\n"
fi

printf "  ${YELLOW}[B] Build${RESET}\n"
printf "      → Build a new environment for the current state\n"
printf "      → Takes time but ensures the latest dependencies\n"
printf "\n"
printf "  ${BLUE}[S] Select${RESET}\n"
printf "      → Choose any local adore_cli image interactively\n"
printf "      → ${YELLOW}⚠  Selected image may have missing or incompatible dependencies${RESET}\n"
printf "\n"
printf "  ${RED}[A] Abort${RESET}\n"
printf "      → Cancel and exit\n"
printf "\n"

if [[ "$LAST_IMAGE_EXISTS" = "true" ]]; then
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
        if [[ "$LAST_IMAGE_EXISTS" != "true" ]]; then
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
        mapfile -t AVAILABLE_IMAGES < <(docker images --format "{{.Tag}}" adore_cli 2>/dev/null | grep -v '^<none>$' | sort -r || true)
        if [[ ${#AVAILABLE_IMAGES[@]} -eq 0 ]]; then
            printf "${RED}No local adore_cli images found.${RESET}\n"
            exit 1
        fi
        printf "${YELLOW}⚠  WARNING: Running an image other than the one built for your current${RESET}\n"
        printf "${YELLOW}   environment may have missing packages or incompatible dependencies.${RESET}\n"
        printf "\n"
        printf "Available images:\n"
        for i in "${!AVAILABLE_IMAGES[@]}"; do
            printf "  [%d] adore_cli:%s\n" "$((i+1))" "${AVAILABLE_IMAGES[$i]}"
        done
        printf "\n"
        printf "Select image [1-%d]: " "${#AVAILABLE_IMAGES[@]}"
        read -r SELECTION < /dev/tty
        printf "\n"
        if [[ ! "$SELECTION" =~ ^[0-9]+$ ]] || \
           [[ "$SELECTION" -lt 1 ]] || \
           [[ "$SELECTION" -gt ${#AVAILABLE_IMAGES[@]} ]]; then
            printf "${RED}Invalid selection, aborting.${RESET}\n"
            exit 1
        fi
        SELECTED_TAG="${AVAILABLE_IMAGES[$((SELECTION-1))]}"
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

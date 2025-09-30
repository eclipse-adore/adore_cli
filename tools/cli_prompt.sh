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

# Simple CLI prompt script
LAST_TAG="$1"
CALCULATED_TAG="$2"
MAKEFILE_PATH="$3"

# Colors
BOLD='\033[1m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'

printf "\n${BOLD}${YELLOW}=== DEVELOPMENT ENVIRONMENT CHANGE DETECTED ===${RESET}\n"
printf "\n"
printf "Your current working environment:\n"
printf "  ${GREEN}$(echo "$LAST_TAG" | sed 's/_/ /g' | cut -c1-60)...${RESET}\n"
printf "\n"
printf "New calculated environment:\n"
printf "  ${YELLOW}$(echo "$CALCULATED_TAG" | sed 's/_/ /g' | cut -c1-60)...${RESET}\n"
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
printf "What action would you like to take? [c] Continue, [b] Build, [a] Abort > "

read -r USER_CHOICE < /dev/tty
printf "\n"

case "${USER_CHOICE,,}" in
    c|continue|"")
        printf "${GREEN}→ Continuing with your current working environment${RESET}\n"
        if docker image inspect "adore_cli:$LAST_TAG" >/dev/null 2>&1; then
            # Extract core tag
            LAST_CORE_TAG=$(echo "$LAST_TAG" | sed -E 's/^(.+)_PH[a-f0-9]{7}_.*$/\1/')
            if [[ "$LAST_CORE_TAG" == "$LAST_TAG" ]]; then
                LAST_CORE_TAG=$(echo "$LAST_TAG" | sed -E 's/^(.+)_[^_]+_UID.*$/\1/')
            fi
            echo "Using core tag: $LAST_CORE_TAG"
            
            # Call make with overridden variables
            exec make --file="$MAKEFILE_PATH/adore_cli.mk" _execute_environment_action \
                ADORE_CLI_TAG="$LAST_TAG" \
                ADORE_CLI_IMAGE="adore_cli:$LAST_TAG" \
                ADORE_CLI_CONTAINER_NAME="adore_cli_$LAST_TAG" \
                ADORE_CLI_CORE_IMAGE="adore_cli_core:$LAST_CORE_TAG"
        else
            printf "${YELLOW}Last successful environment no longer exists, building new one...${RESET}\n"
            make --file="$MAKEFILE_PATH/adore_cli.mk" _build_adore_cli_layers
            bash "$MAKEFILE_PATH/tools/tag_history_manager.sh" save "${ADORE_CLI_BASE_TAG}" "${ADORE_CLI_CORE_TAG}" "${ADORE_CLI_TAG}" 2>/dev/null || true
            exec make --file="$MAKEFILE_PATH/adore_cli.mk" _execute_environment_action
        fi
        ;;
    b|build)
        printf "${YELLOW}→ Building new environment with current changes${RESET}\n"
        make --file="$MAKEFILE_PATH/adore_cli.mk" _build_adore_cli_layers
        bash "$MAKEFILE_PATH/tools/tag_history_manager.sh" save "${ADORE_CLI_BASE_TAG}" "${ADORE_CLI_CORE_TAG}" "${ADORE_CLI_TAG}" 2>/dev/null || true
        exec make --file="$MAKEFILE_PATH/adore_cli.mk" _execute_environment_action
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

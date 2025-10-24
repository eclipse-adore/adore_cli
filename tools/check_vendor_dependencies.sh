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

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

GREEN="\033[0;32m"
NC="\033[0m"
CHECKMARK="${GREEN}✔${NC}"

VENDOR_BUILD_DIR="${SOURCE_DIRECTORY}/vendor/build"

check_vendor_dependencies() {
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
    
    current_package_hash=""
    if [ -n "${SOURCE_DIRECTORY}" ] && [ -d "${VENDOR_BUILD_DIR}" ]; then
        current_package_hash=$(find "$VENDOR_BUILD_DIR" -type f -name "*.deb" 2>/dev/null | \
            sort | xargs -r -I {} basename {} 2>/dev/null | \
            sort | sha256sum 2>/dev/null | cut -d' ' -f1 2>/dev/null | cut -c1-7 || echo "0000000")
    else
        current_package_hash="0000000"
    fi
    
    container_package_hash=""
    
    if [ -n "${ADORE_CLI_IMAGE}" ]; then
        container_package_hash=$(echo "${ADORE_CLI_IMAGE}" | grep -o 'PH[a-f0-9]\{7\}' | cut -c3-)
    fi
    
    if [ -z "$container_package_hash" ] && [ -n "${SOURCE_DIRECTORY}" ]; then
        built_tags_file="${SOURCE_DIRECTORY}/.log/.adore_cli/built_tags"
        if [ -f "$built_tags_file" ]; then
            user_tag=$(grep "^USER=" "$built_tags_file" 2>/dev/null | cut -d'=' -f2)
            if [ -n "$user_tag" ]; then
                container_package_hash=$(echo "$user_tag" | grep -o 'PH[a-f0-9]\{7\}' | cut -c3-)
            fi
        fi
    fi
   
    printf "    === Installed Packages(.deb) ===\n"

    deb_count=0
    if [ -d "${VENDOR_BUILD_DIR}" ]; then
        deb_count=$(find "${VENDOR_BUILD_DIR}" -name "*.deb" -type f 2>/dev/null | wc -l)
    fi
    
    if [ "$deb_count" -lt 1 ]; then
        printf "    ${BOLD}${BLINK}${ORANGE}WARNING:${RESET} No vendor dependency packages found!\n" 
        printf "        This may result in missing dependencies when building nodes or libraries.\n"  
        printf "        Build the vendor libraries with 'make build' and try again.\n"
        printf "        Expected location: ${VENDOR_BUILD_DIR}/*.deb\n"
        return
    fi
    
    if [ -z "$container_package_hash" ]; then
        printf "    ${ORANGE}INFO:${RESET} Unable to determine container package hash\n"
        printf "    Found $deb_count vendor dependency packages\n"
        printf "    User image: ${ADORE_CLI_IMAGE:-NOT_SET}\n"
        return
    fi
    
    if [ "$current_package_hash" != "$container_package_hash" ]; then
        printf "    ${BOLD}${BLINK}${ORANGE}WARNING:${RESET} Vendor packages have changed since container was built!\n"
        printf "    Container package hash: ${container_package_hash}\n"
        printf "    Current package hash:   ${current_package_hash}\n"
        printf "\n"
        printf "    This means your vendor .deb packages have changed since the ADORe CLI\n"
        printf "    container was last built. The container may be missing updated dependencies.\n"
        printf "\n"
        printf "    ${BOLD}How to resolve:${RESET}\n"
        printf "    1. Rebuild the ADORe CLI: ${GREEN}make build${RESET}\n"
        printf "    2. Or rebuild from user layer: ${GREEN}make rebuild_from_layer LAYER=user${RESET}\n"
        printf "    3. Then restart: ${GREEN}make cli${RESET}\n"
        printf "\n"
        printf "    ${BOLD}Current vendor packages (${deb_count} total):${RESET}\n"
        if [ -d "${VENDOR_BUILD_DIR}" ]; then
            find "${VENDOR_BUILD_DIR}" -name "*.deb" -type f 2>/dev/null | \
                head -5 | while read -r deb_file; do
                printf "        $(basename "$deb_file")\n"
            done
            if [ "$deb_count" -gt 5 ]; then
                printf "        ... and $((deb_count - 5)) more\n"
            fi
        fi
    else
        printf "    ${CHECKMARK} Found $deb_count vendor dependency packages (hash: ${current_package_hash})\n"
    fi
}

check_vendor_dependencies

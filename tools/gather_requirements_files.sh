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

# Global configuration
REQUIREMENT_EXTENSIONS=(".pip3" ".system" ".ppa")
EXCLUDED_DIRECTORIES=(".log" ".git" "build" ".tmp")
SOURCE_DIRECTORY="${SOURCE_DIRECTORY:-$(pwd)}"

build_find_exclude_args() {
    local exclude_args=()
    for dir in "${EXCLUDED_DIRECTORIES[@]}"; do
        exclude_args+=("!" "-path" "*/$dir/*")
    done
    echo "${exclude_args[@]}"
}

hash_requirements() {
    local source_dir="${1:-$SOURCE_DIRECTORY}"
    local combined_requirements=""
    local exclude_args=($(build_find_exclude_args))
    
    for ext in "${REQUIREMENT_EXTENSIONS[@]}"; do
        local pattern="*$ext"
        if [[ "$ext" == ".ppa" ]]; then
            pattern="requirements.ppa"
        fi
        
        while IFS= read -r -d '' file; do
            local content
            content=$(grep -v '^[[:space:]]*#' "$file" | grep -v '^[[:space:]]*$')
            
            if [[ "$ext" == ".ppa" ]] && [[ -n "$content" ]]; then
                content=$(echo "$content" | grep '^ppa:' || true)
            fi
            
            if [[ -n "$content" ]]; then
                combined_requirements+="$content"$'\n'
            fi
        done < <(find "$source_dir" -type f -name "$pattern" "${exclude_args[@]}" -print0 2>/dev/null)
    done
    
    echo "$combined_requirements" | sort -u | grep -v '^$' | sha256sum | cut -d' ' -f1
}

generate_combine_requirements() {
    local requirements_dir="$1"
    local extension="$2"
    local output_file="$requirements_dir/combined_requirements.$extension"
    local combined_requirements=""
    local exclude_args=($(build_find_exclude_args))
    
    mkdir -p "$requirements_dir"
    
    local pattern="*.$extension"
    if [[ "$extension" == "ppa" ]]; then
        pattern="requirements.ppa"
    fi
    
    while IFS= read -r -d '' file; do
        local content
        content=$(grep -v '^[[:space:]]*#' "$file" | grep -v '^[[:space:]]*$')
        
        if [[ "$extension" == "ppa" ]] && [[ -n "$content" ]]; then
            content=$(echo "$content" | grep '^ppa:' || true)
        fi
        
        if [[ -n "$content" ]]; then
            combined_requirements+="$content"$'\n'
        fi
    done < <(find "$SOURCE_DIRECTORY" -type f -name "$pattern" "${exclude_args[@]}" -print0 2>/dev/null)
    
    echo "$combined_requirements" | sort -u | grep -v '^$' > "$output_file"
}

generate_requirements_manifest() {
    local source_dir="$1"
    local requirements_dir="$2"
    local manifest_file="$requirements_dir/requirements_manifest.sha256"
    local exclude_args=($(build_find_exclude_args))
    
    mkdir -p "$requirements_dir"
    rm -f "$manifest_file".* 2>/dev/null || true
    
    local manifest_content
    manifest_content=$(cd "$source_dir" && \
        find . -type f \( -name "*.system" -o -name "*.pip3" -o -name "*.ppa" \) \
        "${exclude_args[@]}" \
        2>/dev/null | \
        LC_ALL=C sort | \
        xargs -r sha256sum 2>/dev/null | \
        sed 's|  \./|  |g' | \
        LC_ALL=C sort)
    
    echo "$manifest_content" > "$manifest_file"
    
    if [[ -s "$manifest_file" ]]; then
        local requirements_hash
        requirements_hash=$(cat "$manifest_file" | sha256sum | cut -d' ' -f1)
        local hash_file="$manifest_file.$requirements_hash"
        echo "$requirements_hash" > "$hash_file"
        echo "$requirements_hash"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        "hash")
            hash_requirements "${2:-}"
            ;;
        "combine")
            generate_combine_requirements "$2" "$3"
            ;;
        "manifest")
            generate_requirements_manifest "$2" "$3"
            ;;
        *)
            echo "Usage: $0 {hash [source_dir]|combine <req_dir> <ext>|manifest <source_dir> <req_dir>}"
            exit 1
            ;;
    esac
fi

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

REQUIREMENT_EXTENSIONS=(".pip3" ".system" ".ppa")
EXCLUDED_DIRECTORIES=(".log" ".git" "build" ".tmp" "adore_cli_base" "adore_cli_core" "context")
SOURCE_DIRECTORY="${SOURCE_DIRECTORY:-$(pwd)}"

find_requirements() {
    local source_dir="$1"
    local pattern="$2"
    local result
    result=$(find "$source_dir" -type f -name "$pattern" 2>/dev/null | LC_ALL=C sort || true)
    for dir in "${EXCLUDED_DIRECTORIES[@]}"; do
        result=$(echo "$result" | grep -v "/${dir}/" || true)
    done
    echo "$result"
}

hash_requirements() {
    local source_dir="${1:-$SOURCE_DIRECTORY}"
    local combined_requirements=""

    for ext in "${REQUIREMENT_EXTENSIONS[@]}"; do
        local pattern="*$ext"
        [[ "$ext" == ".ppa" ]] && pattern="requirements.ppa"

        local found_files
        found_files=$(find_requirements "$source_dir" "$pattern")

        if [[ -n "$found_files" ]]; then
            while IFS= read -r file; do
                [[ -f "$file" ]] || continue
                local content
                content=$(grep -v '^[[:space:]]*#' "$file" 2>/dev/null | grep -v '^[[:space:]]*$' || true)
                [[ "$ext" == ".ppa" ]] && [[ -n "$content" ]] && content=$(echo "$content" | grep '^ppa:' || true)
                [[ -n "$content" ]] && combined_requirements+="$content"$'\n'
            done <<< "$found_files"
        fi
    done

    if [[ -n "$combined_requirements" ]]; then
        echo "$combined_requirements" | LC_ALL=C sort -u | grep -v '^$' | sha256sum | cut -d' ' -f1
    else
        echo ""
    fi
}

debug_hash_requirements() {
    local source_dir="${1:-$SOURCE_DIRECTORY}"

    echo "=== DEBUG HASH REQUIREMENTS ==="
    echo "Source directory: $source_dir"
    echo "Excluded directories: ${EXCLUDED_DIRECTORIES[*]}"
    echo ""

    local combined_requirements=""

    for ext in "${REQUIREMENT_EXTENSIONS[@]}"; do
        local pattern="*$ext"
        [[ "$ext" == ".ppa" ]] && pattern="requirements.ppa"

        echo "=== Processing extension: $ext ==="
        local found_files
        found_files=$(find_requirements "$source_dir" "$pattern")

        if [[ -n "$found_files" ]]; then
            echo "$found_files" | sed 's/^/  /'
            while IFS= read -r file; do
                [[ -f "$file" ]] || continue
                local content
                content=$(grep -v '^[[:space:]]*#' "$file" 2>/dev/null | grep -v '^[[:space:]]*$' || true)
                [[ "$ext" == ".ppa" ]] && [[ -n "$content" ]] && content=$(echo "$content" | grep '^ppa:' || true)
                [[ -n "$content" ]] && combined_requirements+="$content"$'\n'
            done <<< "$found_files"
        else
            echo "  No files found"
        fi
        echo ""
    done

    if [[ -n "$combined_requirements" ]]; then
        local sorted
        sorted=$(echo "$combined_requirements" | LC_ALL=C sort -u | grep -v '^$')
        echo "Combined (sorted):"
        echo "$sorted" | sed 's/^/  /'
        echo ""
        echo "Final hash: $(echo "$sorted" | sha256sum | cut -d' ' -f1)"
    else
        echo "No requirements found"
    fi
    echo "=== DEBUG COMPLETE ==="
}

generate_combine_requirements() {
    local extension="$1"
    local source_dir="$2"
    local requirements_dir="$source_dir/.log/.adore_cli/requirements"
    local output_file="$requirements_dir/combined_requirements.$extension"

    mkdir -p "$requirements_dir"

    local pattern="*.$extension"
    [[ "$extension" == "ppa" ]] && pattern="requirements.ppa"

    local found_files
    found_files=$(find_requirements "$source_dir" "$pattern")

    if [[ -z "$found_files" ]]; then
        touch "$output_file"
        return
    fi

    local combined_requirements=""
    while IFS= read -r file; do
        [[ -f "$file" ]] || continue
        local content
        content=$(grep -v '^[[:space:]]*#' "$file" 2>/dev/null | grep -v '^[[:space:]]*$' || true)
        [[ "$extension" == "ppa" ]] && [[ -n "$content" ]] && content=$(echo "$content" | grep '^ppa:' || true)
        [[ -n "$content" ]] && combined_requirements+="$content"$'\n'
    done <<< "$found_files"

    if [[ -n "$combined_requirements" ]]; then
        echo "$combined_requirements" | LC_ALL=C sort -u | grep -v '^$' > "$output_file"
    else
        touch "$output_file"
    fi

    echo "  Generated $output_file ($(wc -l < "$output_file") lines)"
}

generate_all_requirements() {
    local source_dir="$1"
    echo "Generating all requirements from: $source_dir"
    for ext in "${REQUIREMENT_EXTENSIONS[@]}"; do
        generate_combine_requirements "${ext#.}" "$source_dir"
    done
}

generate_requirements_manifest() {
    local source_dir="${1:-$SOURCE_DIRECTORY}"
    local requirements_dir="$source_dir/.log/.adore_cli/requirements"
    local manifest_file="$requirements_dir/requirements_manifest.sha256"

    mkdir -p "$requirements_dir"
    rm -f "$manifest_file".* 2>/dev/null || true

    local all_files
    all_files=$(find "$source_dir" -type f \( -name "*.system" -o -name "*.pip3" -o -name "*.ppa" \) 2>/dev/null | LC_ALL=C sort || true)
    for dir in "${EXCLUDED_DIRECTORIES[@]}"; do
        all_files=$(echo "$all_files" | grep -v "/${dir}/" || true)
    done

    local manifest_content
    manifest_content=$(echo "$all_files" | xargs -r sha256sum 2>/dev/null | sed 's|  \./|  |g' | LC_ALL=C sort || true)

    echo "$manifest_content" > "$manifest_file"

    if [[ -s "$manifest_file" ]]; then
        local requirements_hash
        requirements_hash=$(sha256sum < "$manifest_file" | cut -d' ' -f1)
        echo "$requirements_hash" > "$manifest_file.$requirements_hash"
        echo "$requirements_hash"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        "hash")     hash_requirements "${2:-$SOURCE_DIRECTORY}" ;;
        "debug"|"debug-hash") debug_hash_requirements "${2:-$SOURCE_DIRECTORY}" ;;
        "combine")
            if [[ -n "${2:-}" && -d "${2}" ]]; then
                generate_all_requirements "$2"
            elif [[ -n "${2:-}" ]]; then
                generate_combine_requirements "$2" "${3:-$SOURCE_DIRECTORY}"
            else
                generate_all_requirements "$SOURCE_DIRECTORY"
            fi ;;
        "manifest") generate_requirements_manifest "${2:-$SOURCE_DIRECTORY}" ;;
        *) echo "Usage: $0 {hash [source_dir]|debug [source_dir]|combine [source_dir|ext] [source_dir]|manifest [source_dir]}"
           exit 1 ;;
    esac
fi

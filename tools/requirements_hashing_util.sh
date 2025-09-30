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
EXCLUDED_DIRECTORIES=(".log" ".git" "build" ".tmp")
SOURCE_DIRECTORY="${SOURCE_DIRECTORY:-$(pwd)}"

build_find_exclude_args() {
    local exclude_args=()
    for dir in "${EXCLUDED_DIRECTORIES[@]}"; do
        exclude_args+=("!" "-path" "*/$dir/*")
    done
    printf '%q ' "${exclude_args[@]}"
}

hash_requirements() {
    local source_dir="${1:-$SOURCE_DIRECTORY}"
    local combined_requirements=""
    
    local exclude_args_str
    exclude_args_str=$(build_find_exclude_args)
    
    for ext in "${REQUIREMENT_EXTENSIONS[@]}"; do
        local pattern="*$ext"
        if [[ "$ext" == ".ppa" ]]; then
            pattern="requirements.ppa"
        fi
        
        local found_files
        eval "found_files=\$(find \"$source_dir\" -type f -name \"$pattern\" $exclude_args_str 2>/dev/null | LC_ALL=C sort)"
        
        if [[ -n "$found_files" ]]; then
            while IFS= read -r file; do
                if [[ -f "$file" ]]; then
                    local content
                    content=$(grep -v '^[[:space:]]*#' "$file" 2>/dev/null | grep -v '^[[:space:]]*$' || true)
                    
                    if [[ "$ext" == ".ppa" ]] && [[ -n "$content" ]]; then
                        content=$(echo "$content" | grep '^ppa:' || true)
                    fi
                    
                    if [[ -n "$content" ]]; then
                        combined_requirements+="$content"$'\n'
                    fi
                fi
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
    echo "Environment info:"
    echo "  - Current working directory: $(pwd)"
    echo "  - Source directory: $source_dir"
    echo "  - Script location: ${BASH_SOURCE[0]}"
    echo "  - Hostname: $(hostname 2>/dev/null || echo 'unknown')"
    echo "  - User: $(whoami 2>/dev/null || echo 'unknown')"
    echo ""
    
    echo "Locale info:"
    locale 2>/dev/null || echo "  locale command failed"
    echo ""
    
    echo "Environment variables affecting sorting:"
    echo "  LANG=${LANG:-<unset>}"
    echo "  LC_ALL=${LC_ALL:-<unset>}"
    echo "  LC_COLLATE=${LC_COLLATE:-<unset>}"
    echo ""
    
    local exclude_args_str
    exclude_args_str=$(build_find_exclude_args)
    echo "Exclude arguments: $exclude_args_str"
    echo ""
    
    local combined_requirements=""
    local total_files_found=0
    
    for ext in "${REQUIREMENT_EXTENSIONS[@]}"; do
        local pattern="*$ext"
        if [[ "$ext" == ".ppa" ]]; then
            pattern="requirements.ppa"
        fi
        
        echo "=== Processing extension: $ext ==="
        echo "Pattern: $pattern"
        
        local found_files
        eval "found_files=\$(find \"$source_dir\" -type f -name \"$pattern\" $exclude_args_str 2>/dev/null | LC_ALL=C sort)"
        
        if [[ -n "$found_files" ]]; then
            local file_count=$(echo "$found_files" | wc -l)
            total_files_found=$((total_files_found + file_count))
            echo "Found $file_count files:"
            echo "$found_files" | sed 's/^/  /'
            echo ""
            
            while IFS= read -r file; do
                if [[ -f "$file" ]]; then
                    echo "Processing file: $file"
                    
                    # Show file metadata
                    echo "  File info:"
                    ls -la "$file" 2>/dev/null | sed 's/^/    /' || echo "    ls failed"
                    
                    # Show raw file content
                    echo "  Raw content:"
                    cat "$file" 2>/dev/null | sed 's/^/    |/' || echo "    cat failed"
                    
                    # Show processed content
                    local content
                    content=$(grep -v '^[[:space:]]*#' "$file" 2>/dev/null | grep -v '^[[:space:]]*$' || true)
                    
                    if [[ "$ext" == ".ppa" ]] && [[ -n "$content" ]]; then
                        content=$(echo "$content" | grep '^ppa:' || true)
                    fi
                    
                    echo "  Processed content:"
                    if [[ -n "$content" ]]; then
                        echo "$content" | sed 's/^/    |/'
                        combined_requirements+="$content"$'\n'
                    else
                        echo "    (empty after processing)"
                    fi
                    echo ""
                fi
            done <<< "$found_files"
        else
            echo "No files found for extension $ext"
        fi
        echo ""
    done
    
    echo "=== FINAL PROCESSING ==="
    echo "Total files processed: $total_files_found"
    echo ""
    
    if [[ -n "$combined_requirements" ]]; then
        echo "Combined requirements (before final sort):"
        echo "$combined_requirements" | sed 's/^/  |/'
        echo ""
        
        echo "Combined requirements (after LC_ALL=C sort -u):"
        local sorted_requirements
        sorted_requirements=$(echo "$combined_requirements" | LC_ALL=C sort -u | grep -v '^$')
        echo "$sorted_requirements" | sed 's/^/  |/'
        echo ""
        
        echo "Requirements for hashing (hex dump):"
        #echo "$sorted_requirements" | xxd | sed 's/^/  /'
        echo ""
        
        local hash
        hash=$(echo "$sorted_requirements" | sha256sum | cut -d' ' -f1)
        echo "Final hash: $hash"
    else
        echo "No combined requirements found"
        echo "Final hash: (empty)"
    fi
    echo ""
    
    echo "=== DEBUG COMPLETE ==="
}

generate_combine_requirements() {
    local extension="$1"
    local source_dir="$2"
    local requirements_dir="$source_dir/.log/.adore_cli/requirements"
    local output_file="$requirements_dir/combined_requirements.$extension"
    
    echo "Processing extension: $extension"
    
    mkdir -p "$requirements_dir"
    
    local pattern="*.$extension"
    if [[ "$extension" == "ppa" ]]; then
        pattern="requirements.ppa"
    fi
    
    echo "  Searching for pattern: $pattern"
    
    local exclude_args_str
    exclude_args_str=$(build_find_exclude_args)
    
    local found_files
    eval "found_files=\$(find \"$source_dir\" -type f -name \"$pattern\" $exclude_args_str 2>/dev/null | LC_ALL=C sort)"
    
    local file_count=$(echo "$found_files" | grep -c . || echo "0")
    echo "  Found $file_count files"
    
    if [[ -z "$found_files" ]]; then
        echo "  Creating empty file: $output_file"
        touch "$output_file"
        return
    fi
    
    local combined_requirements=""
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            echo "    Processing: $file"
            local content
            content=$(grep -v '^[[:space:]]*#' "$file" 2>/dev/null | grep -v '^[[:space:]]*$' || true)
            
            if [[ "$extension" == "ppa" ]] && [[ -n "$content" ]]; then
                content=$(echo "$content" | grep '^ppa:' || true)
            fi
            
            if [[ -n "$content" ]]; then
                combined_requirements+="$content"$'\n'
            fi
        fi
    done <<< "$found_files"
    
    if [[ -n "$combined_requirements" ]]; then
        echo "$combined_requirements" | LC_ALL=C sort -u | grep -v '^$' > "$output_file"
    else
        touch "$output_file"
    fi
    
    local line_count=$(wc -l < "$output_file" 2>/dev/null || echo "0")
    echo "  Generated $output_file with $line_count lines"
}

generate_all_requirements() {
    local source_dir="$1"
    
    echo "Generating all requirements from: $source_dir"
    echo "Output directory: $source_dir/.log/.adore_cli/requirements"
    
    for ext in "${REQUIREMENT_EXTENSIONS[@]}"; do
        local clean_ext="${ext#.}"
        generate_combine_requirements "$clean_ext" "$source_dir"
    done
    
    echo ""
    echo "Final output:"
    ls -la "$source_dir/.log/.adore_cli/requirements/" 2>/dev/null || echo "No files generated"
}

generate_requirements_manifest() {
    local source_dir="${1:-$SOURCE_DIRECTORY}"
    local requirements_dir="$source_dir/.log/.adore_cli/requirements"
    local manifest_file="$requirements_dir/requirements_manifest.sha256"
    
    mkdir -p "$requirements_dir"
    rm -f "$manifest_file".* 2>/dev/null || true
    
    local exclude_args_str
    exclude_args_str=$(build_find_exclude_args)
    
    local manifest_content
    eval "manifest_content=\$(cd \"$source_dir\" && \
        find . -type f \\( -name \"*.system\" -o -name \"*.pip3\" -o -name \"*.ppa\" \\) \
        $exclude_args_str \
        2>/dev/null | \
        LC_ALL=C sort | \
        xargs -r sha256sum 2>/dev/null | \
        sed 's|  \\./|  |g' | \
        LC_ALL=C sort)"
    
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
            hash_requirements "${2:-$SOURCE_DIRECTORY}"
            ;;
        "debug"|"debug-hash")
            debug_hash_requirements "${2:-$SOURCE_DIRECTORY}"
            ;;
        "combine")
            if [[ -n "${2:-}" && -d "${2}" ]]; then
                generate_all_requirements "$2"
            elif [[ -n "${2:-}" ]]; then
                generate_combine_requirements "$2" "${3:-$SOURCE_DIRECTORY}"
            else
                generate_all_requirements "$SOURCE_DIRECTORY"
            fi
            ;;
        "manifest")
            generate_requirements_manifest "${2:-$SOURCE_DIRECTORY}"
            ;;
        *)
            echo "Usage: $0 {hash [source_dir]|debug [source_dir]|combine [source_dir|ext] [source_dir]|manifest [source_dir]}"
            exit 1
            ;;
    esac
fi

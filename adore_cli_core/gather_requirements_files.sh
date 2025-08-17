#!/usr/bin/env bash

set -euo pipefail

echoerr (){ printf "%s" "$@" >&2;}
exiterr (){ printf "%s\n" "$@" >&2; exit 1;}

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "=== DEBUG: Gather script starting ==="
echo "Script directory: ${SCRIPT_DIRECTORY}"
echo "SOURCE_DIRECTORY from env: ${SOURCE_DIRECTORY:-NOT SET}"
echo "Args: $@"
echo "======================================"

# Determine the source directory to search
if [ -n "${SOURCE_DIRECTORY:-}" ] && [ "${SOURCE_DIRECTORY}" != "${SCRIPT_DIRECTORY}" ]; then
    SEARCH_DIR="${SOURCE_DIRECTORY}"
    echo "Using SOURCE_DIRECTORY: ${SEARCH_DIR}"
else
    # Default to parent of adore_cli (../../ from adore_cli_core)
    SEARCH_DIR="$(realpath "${SCRIPT_DIRECTORY}/../..")"
    echo "Using default (parent of adore_cli): ${SEARCH_DIR}"
fi

# Requirements will always be stored in SEARCH_DIR/.log/.adore_cli/requirements
REQUIREMENTS_DIR="${SEARCH_DIR}/.log/.adore_cli/requirements"

echo "Searching for requirements in: ${SEARCH_DIR}"
echo "Storing requirements in: ${REQUIREMENTS_DIR}"

# Verify search directory exists and has content
if [ ! -d "${SEARCH_DIR}" ]; then
    echo "ERROR: Search directory does not exist: ${SEARCH_DIR}"
    exit 1
fi

echo "Search directory contents (first 10 items):"
ls -la "${SEARCH_DIR}" | head -10

# Create the requirements directory
mkdir -p "${REQUIREMENTS_DIR}"

# Initialize empty files
echo "Creating requirement files..."
> "${REQUIREMENTS_DIR}/combined_requirements.system"
> "${REQUIREMENTS_DIR}/combined_requirements.pip3"
> "${REQUIREMENTS_DIR}/combined_requirements.ppa"

# Function to search and process files
search_and_process() {
    local file_pattern="$1"
    local output_file="$2"
    local description="$3"
    
    echo "Searching for ${description} files..."
    
    # Find files matching pattern, excluding certain directories
    local found_files
    found_files=$(find "${SEARCH_DIR}" -type f -name "${file_pattern}" \
        ! -path "*/ros_translator/*" \
        ! -path "*/.log/*" \
        ! -path "*/.git/*" \
        ! -path "*/build/*" \
        ! -path "*/.tmp/*" \
        2>/dev/null || true)
    
    if [ -n "$found_files" ]; then
        echo "Found ${description} files:"
        echo "$found_files" | while read -r file; do
            echo "  Processing: $file"
        done
        
        # Process all found files
        echo "$found_files" | while read -r file; do
            if [ -f "$file" ]; then
                echo "# From: $file" >> "${output_file}"
                cat "$file" >> "${output_file}"
                echo "" >> "${output_file}"
            fi
        done
        
        # Clean up the output: remove comments, empty lines, and duplicates
        local temp_file="${output_file}.tmp"
        sed '/^#/d' "${output_file}" | sed '/^$/d' | sort -u > "${temp_file}"
        mv "${temp_file}" "${output_file}"
        
        local count=$(wc -l < "${output_file}" 2>/dev/null || echo "0")
        echo "Processed ${count} unique ${description} entries"
    else
        echo "No ${description} files found"
        touch "${output_file}"
    fi
}

# Search for different types of requirement files
search_and_process "*.system" "${REQUIREMENTS_DIR}/combined_requirements.system" "system package"
search_and_process "*.pip3" "${REQUIREMENTS_DIR}/combined_requirements.pip3" "Python pip3"
search_and_process "requirements.ppa" "${REQUIREMENTS_DIR}/combined_requirements.ppa" "PPA"

# Special handling for .ppa files (only include lines starting with 'ppa:')
if [ -s "${REQUIREMENTS_DIR}/combined_requirements.ppa" ]; then
    echo "Filtering PPA entries to only include 'ppa:' lines..."
    grep '^ppa:' "${REQUIREMENTS_DIR}/combined_requirements.ppa" > "${REQUIREMENTS_DIR}/combined_requirements.ppa.tmp" || touch "${REQUIREMENTS_DIR}/combined_requirements.ppa.tmp"
    mv "${REQUIREMENTS_DIR}/combined_requirements.ppa.tmp" "${REQUIREMENTS_DIR}/combined_requirements.ppa"
fi

echo "Requirements stored in: ${REQUIREMENTS_DIR}"
echo "Contents:"
ls -la "${REQUIREMENTS_DIR}"
echo "File line counts:"
wc -l "${REQUIREMENTS_DIR}"/* 2>/dev/null || true

# Generate a manifest of the requirements for change detection
echo "=== Generating requirements manifest ==="
MANIFEST_FILE="${REQUIREMENTS_DIR}/requirements_manifest.sha256"

# Find all requirement files that were used to generate the combined files
find "${SEARCH_DIR}" -type f \( -name "*.system" -o -name "*.pip3" -o -name "*.ppa" \) \
    ! -path "*/ros_translator/*" \
    ! -path "*/.log/*" \
    ! -path "*/.git/*" \
    ! -path "*/build/*" \
    ! -path "*/.tmp/*" \
    2>/dev/null | \
    xargs -r sha256sum 2>/dev/null | sort > "${MANIFEST_FILE}" || touch "${MANIFEST_FILE}"

echo "Requirements manifest created with $(wc -l < "${MANIFEST_FILE}" 2>/dev/null || echo "0") entries"

# Also create manifests of the combined files themselves
echo "=== Creating combined file manifests ==="
find "${REQUIREMENTS_DIR}" -name "combined_requirements.*" -type f 2>/dev/null | \
    xargs -r sha256sum 2>/dev/null | sort >> "${MANIFEST_FILE}" || true

echo "Final manifest:"
cat "${MANIFEST_FILE}" 2>/dev/null || echo "Empty manifest"

echo "=== Requirements gathering complete ==="

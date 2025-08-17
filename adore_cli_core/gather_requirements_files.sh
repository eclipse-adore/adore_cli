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

echo "Search directory contents:"
ls -la "${SEARCH_DIR}" | head -10

# Create the requirements directory
mkdir -p "${REQUIREMENTS_DIR}"

# Initialize empty files
echo "Creating requirement files..."
> "${REQUIREMENTS_DIR}/combined_requirements.system"
> "${REQUIREMENTS_DIR}/combined_requirements.pip3"
> "${REQUIREMENTS_DIR}/combined_requirements.ppa"

echo "Searching for .system files..."
find "${SEARCH_DIR}" -type f -name "*.system" ! -path "*/ros_translator/*" 2>/dev/null | while read -r file; do
    echo "Found .system file: $file"
done

SYSTEM_FILES=$(find "${SEARCH_DIR}" -type f -name "*.system" ! -path "*/ros_translator/*" 2>/dev/null)
if [ -n "$SYSTEM_FILES" ]; then
    echo "$SYSTEM_FILES" | while read -r file; do
        echo "Processing: $file"
        cat "$file"
    done | sed '/^#/d' | sed '/^$/d' | sort -u > "${REQUIREMENTS_DIR}/combined_requirements.system"
fi

echo "Searching for .pip3 files..."
PIP3_FILES=$(find "${SEARCH_DIR}" -type f -name "*.pip3" 2>/dev/null)
if [ -n "$PIP3_FILES" ]; then
    echo "$PIP3_FILES" | while read -r file; do
        echo "Processing: $file"
        cat "$file"
    done | sed '/^#/d' | sed '/^$/d' | sort -u > "${REQUIREMENTS_DIR}/combined_requirements.pip3"
fi

echo "Searching for .ppa files..."
PPA_FILES=$(find "${SEARCH_DIR}" -type f -name "requirements.ppa" 2>/dev/null)
if [ -n "$PPA_FILES" ]; then
    echo "$PPA_FILES" | while read -r file; do
        echo "Processing: $file"
        cat "$file"
    done | sed '/^#/d' | sed '/^$/d' | grep '^ppa:' | sort -u > "${REQUIREMENTS_DIR}/combined_requirements.ppa"
fi

echo "Requirements stored in: ${REQUIREMENTS_DIR}"
echo "Contents:"
ls -la "${REQUIREMENTS_DIR}"
echo "File line counts:"
wc -l "${REQUIREMENTS_DIR}"/* 2>/dev/null || true

# Copy to local build context for Docker
LOCAL_REQUIREMENTS_DIR="${SCRIPT_DIRECTORY}/.log/.adore_cli/requirements"
echo "Copying to local build context: ${LOCAL_REQUIREMENTS_DIR}"
mkdir -p "${LOCAL_REQUIREMENTS_DIR}"
cp "${REQUIREMENTS_DIR}"/* "${LOCAL_REQUIREMENTS_DIR}/" 2>/dev/null || true

echo "Build context verification:"
ls -la "${LOCAL_REQUIREMENTS_DIR}" 2>/dev/null || echo "No files in build context"

echo "=== Requirements gathering complete ==="

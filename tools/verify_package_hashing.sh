#!/usr/bin/env bash

set -euo pipefail

echoerr() { printf "%s\n" "$@" >&2; }
exiterr() { echoerr "$@"; exit 1; }

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Test the package hashing logic
test_package_hashing() {
    echo "=== Testing Package Hashing Logic ==="
    
    # Get SOURCE_DIRECTORY from environment or default
    SOURCE_DIRECTORY="${SOURCE_DIRECTORY:-$(realpath "${SCRIPT_DIRECTORY}/..")}"
    VENDOR_PATH="${SOURCE_DIRECTORY}/vendor"
    
    echo "SOURCE_DIRECTORY: ${SOURCE_DIRECTORY}"
    echo "VENDOR_PATH: ${VENDOR_PATH}"
    
    if [ ! -d "${VENDOR_PATH}" ]; then
        echo "VENDOR_PATH does not exist: ${VENDOR_PATH}"
        echo "Creating test directory with sample packages..."
        mkdir -p "${VENDOR_PATH}"
        
        # Create some test .deb files for demonstration
        touch "${VENDOR_PATH}/test-package-1.0.0_amd64.deb"
        touch "${VENDOR_PATH}/another-lib-2.1.0_amd64.deb"
        touch "${VENDOR_PATH}/subdir/nested-pkg-1.5.0_amd64.deb"
        mkdir -p "${VENDOR_PATH}/subdir"
        touch "${VENDOR_PATH}/subdir/nested-pkg-1.5.0_amd64.deb"
        
        echo "Created test packages for demonstration"
    fi
    
    echo ""
    echo "Found .deb packages:"
    find "${VENDOR_PATH}" -name "*.deb" -type f 2>/dev/null | while read -r pkg; do
        echo "  $(basename "$pkg")"
    done
    
    echo ""
    echo "=== Testing Hash Calculation Methods ==="
    
    # Method 1: Hash file contents (old method)
    echo "Old method (file contents hash):"
    OLD_HASH=$(find "${VENDOR_PATH}" -type f -name "*.deb" 2>/dev/null | \
        sort | xargs -r sha256sum 2>/dev/null | \
        sha256sum 2>/dev/null | cut -d' ' -f1 2>/dev/null | cut -c1-7 || echo "0000000")
    echo "  Hash: ${OLD_HASH}"
    
    # Method 2: Hash package names only (new method)
    echo "New method (package names hash):"
    NEW_HASH=$(find "${VENDOR_PATH}" -type f -name "*.deb" 2>/dev/null | \
        sort | xargs -r -I {} basename {} 2>/dev/null | \
        sort | sha256sum 2>/dev/null | cut -d' ' -f1 2>/dev/null | cut -c1-7 || echo "0000000")
    echo "  Hash: ${NEW_HASH}"
    
    echo ""
    echo "=== Hash Comparison ==="
    if [ "${OLD_HASH}" != "${NEW_HASH}" ]; then
        echo "✓ Hashes are different (expected for different methods)"
        echo "  Old: ${OLD_HASH}"
        echo "  New: ${NEW_HASH}"
    else
        echo "⚠ Hashes are the same (unexpected)"
    fi
    
    echo ""
    echo "=== Testing Hash Stability ==="
    
    # Test that package name hash is stable
    HASH1=$(find "${VENDOR_PATH}" -type f -name "*.deb" 2>/dev/null | \
        sort | xargs -r -I {} basename {} 2>/dev/null | \
        sort | sha256sum 2>/dev/null | cut -d' ' -f1 2>/dev/null | cut -c1-7 || echo "0000000")
    
    HASH2=$(find "${VENDOR_PATH}" -type f -name "*.deb" 2>/dev/null | \
        sort | xargs -r -I {} basename {} 2>/dev/null | \
        sort | sha256sum 2>/dev/null | cut -d' ' -f1 2>/dev/null | cut -c1-7 || echo "0000000")
    
    if [ "${HASH1}" = "${HASH2}" ]; then
        echo "✓ Package name hash is stable across multiple calculations"
        echo "  Hash: ${HASH1}"
    else
        echo "✗ Package name hash is not stable"
        echo "  Hash1: ${HASH1}"
        echo "  Hash2: ${HASH2}"
    fi
    
    echo ""
    echo "=== Testing Tag Format ==="
    
    # Simulate tag creation
    ARCH="x86_64"
    ADORE_CLI_BRANCH="main"
    ADORE_CLI_SHORT_HASH="abc1234"
    PARENT_BRANCH="feature"
    PARENT_SHORT_HASH="def5678"
    USER="testuser"
    UID="1000"
    GID="1000"
    
    # Core tag with RH (requirements hash)
    REQUIREMENTS_HASH="9876543"
    CORE_TAG="${ARCH}_${ADORE_CLI_BRANCH}_${ADORE_CLI_SHORT_HASH}_${PARENT_BRANCH}_${PARENT_SHORT_HASH}_RH${REQUIREMENTS_HASH}"
    echo "Core tag example: adore_cli_core:${CORE_TAG}"
    
    # User tag with PH (package hash)
    USER_TAG="${ARCH}_${ADORE_CLI_BRANCH}_${ADORE_CLI_SHORT_HASH}_${PARENT_BRANCH}_${PARENT_SHORT_HASH}_PH${NEW_HASH}_${USER}_UID${UID}GID${GID}"
    echo "User tag example: adore_cli:${USER_TAG}"
    
    echo ""
    echo "=== Testing Hash Extraction ==="
    
    # Test extracting RH hash from core tag
    EXTRACTED_RH=$(echo "adore_cli_core:${CORE_TAG}" | grep -o 'RH[a-f0-9]\{7\}' | cut -c3-)
    echo "Extracted RH hash: ${EXTRACTED_RH}"
    if [ "${EXTRACTED_RH}" = "${REQUIREMENTS_HASH}" ]; then
        echo "✓ RH hash extraction works correctly"
    else
        echo "✗ RH hash extraction failed"
    fi
    
    # Test extracting PH hash from user tag
    EXTRACTED_PH=$(echo "adore_cli:${USER_TAG}" | grep -o 'PH[a-f0-9]\{7\}' | cut -c3-)
    echo "Extracted PH hash: ${EXTRACTED_PH}"
    if [ "${EXTRACTED_PH}" = "${NEW_HASH}" ]; then
        echo "✓ PH hash extraction works correctly"
    else
        echo "✗ PH hash extraction failed"
    fi
    
    echo ""
    echo "=== Test Complete ==="
}

# Run the test
test_package_hashing

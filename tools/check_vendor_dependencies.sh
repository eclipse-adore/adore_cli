#!/usr/bin/env bash
SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# The vendor dependency directory should be in the SOURCE_DIRECTORY/.log/.adore_cli/packages
# since that's where the build process places the package info
VENDOR_DEPENDENCY_DIRECTORY="${SOURCE_DIRECTORY}/.log/.adore_cli/packages"

check_vendor_dependencies() {
    if [[ -n "$TERM" && "$TERM" != "dumb" && "$TERM" != "unknown" ]]; then
        BOLD='\033[1m'
        BLINK='\033[5m'
        ORANGE='\033[38;5;214m'
        RESET='\033[0m'
    else
        BOLD=''
        BLINK=''
        ORANGE=''
        RESET=''
    fi
    
    if [[ ! -d "$VENDOR_DEPENDENCY_DIRECTORY" ]]; then
        printf "    ${BOLD}${BLINK}${ORANGE}WARNING:${RESET} Vendor dependencies not found. Build the vendor libraries with 'make build' and try again.\n"
        printf "    Directory $VENDOR_DEPENDENCY_DIRECTORY does not exist\n"
        return
    fi
    
    deb_count=$(find "$VENDOR_DEPENDENCY_DIRECTORY" -name "*.deb" -type f 2>/dev/null | wc -l)
    
    if [ "$deb_count" -lt 1 ]; then
        printf "\n" 
        printf "    ${BOLD}${BLINK}${ORANGE}WARNING:${RESET} Vendor dependencies not found!\n" 
        printf "        This may result in missing dependencies when building nodes or libraries.\n"  
        printf "        Build the vendor libraries with 'make build' and try again.\n"
    else
        printf "    ✓ Found $deb_count vendor dependency packages\n"
    fi
}
check_vendor_dependencies

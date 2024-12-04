#!/usr/bin/env bash

set -euo pipefail
#set -euxo pipefail #debug mode

echoerr (){ printf "%s" "$@" >&2;}
exiterr (){ printf "%s\n" "$@" >&2; exit 1;}

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"


gather_requirements_files() {
    local base_directory="$1"
    local requirements_temp_dir="${SCRIPT_DIRECTORY}/.tmp/requirements"

    echo "Gathering APT *.system requirements files starting in: ${ADORE_DIRECTORY}"
    echo "Gathering pythong *.pip3 requirements files starting in: ${ADORE_DIRECTORY}"


mkdir -p "$requirements_temp_dir/"
find "$base_directory" -type f -name "*.system" ! -path "*/ros_translator/*" | while read -r file; do
    cat "$file" | \
    sed '/^#/d' | \
    cut -d "#" -f1 | \
    sed 's/[ \t]*$//' | \
    sed '/^$/d'
    echo ""
done | sort | uniq | grep -v ".system" > "$requirements_temp_dir/combined_requirements.system"


find "$base_directory" -type f -name "*.pip3" | while read -r file; do
    cat "$file" | \
    sed '/^#/d' | \
    cut -d "#" -f1 | \
    sed 's/[ \t]*$//' | \
    sed '/^$/d'
    echo ""
done | sort | uniq > "$requirements_temp_dir/combined_requirements.pip3"

}

gather_requirements_files "${ADORE_DIRECTORY}"

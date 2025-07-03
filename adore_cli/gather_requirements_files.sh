#!/usr/bin/env bash

set -euo pipefail
# set -euxo pipefail # debug mode

echoerr (){ printf "%s" "$@" >&2;}
exiterr (){ printf "%s\n" "$@" >&2; exit 1;}

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

gather_requirements_files() {
    local base_directory="$1"
    local requirements_temp_dir="${SCRIPT_DIRECTORY}/.tmp/requirements"

    echo "Gathering APT *.system requirements files starting in: ${base_directory}"
    echo "Gathering Python *.pip3 requirements files starting in: ${base_directory}"
    echo "Gathering APT PPA requirements files starting in: ${base_directory}"

    mkdir -p "$requirements_temp_dir/"

    # Gather *.system files (APT packages)
    mapfile -d '' files < <(find "$base_directory" -type f -name "*.system" ! -path "*/ros_translator/*" -print0)
    if (( ${#files[@]} )); then
        printf '%s\0' "${files[@]}" | xargs -0 -I{} bash -c '
        sed "/^#/d" "{}" | cut -d "#" -f1 | sed "s/[ \t]*$//" | sed "/^$/d"
        echo ""
        ' | sort -u | grep -v ".system" > "$requirements_temp_dir/combined_requirements.system"
    else
        echo "No *.system files found, skipping."
    fi
    
    # Gather *.pip3 files (Python packages)
    mapfile -d '' files < <(find "$base_directory" -type f -name "*.pip3" -print0)
    if (( ${#files[@]} )); then
        printf '%s\0' "${files[@]}" | xargs -0 -I{} bash -c '
        sed "/^#/d" "{}" | cut -d "#" -f1 | sed "s/[ \t]*$//" | sed "/^$/d"
        echo ""
        ' | sort -u > "$requirements_temp_dir/combined_requirements.pip3"
    else
        echo "No *.pip3 files found, skipping."
    fi
    
    # Gather requirements.ppa files (PPAs)
    mapfile -d '' files < <(find "$base_directory" -type f -name "requirements.ppa" -print0)
    if (( ${#files[@]} )); then
        printf '%s\0' "${files[@]}" | xargs -0 -I{} bash -c '
        sed "/^#/d" "{}" | cut -d "#" -f1 | sed "s/[ \t]*$//" | sed "/^$/d"
        echo ""
        ' | sort -u | grep '^ppa:' > "$requirements_temp_dir/combined_requirements.ppa"
    else
        echo "No requirements.ppa files found, skipping."
    fi



}

# Example usage:
# You must set ADORE_DIRECTORY in your environment or script before calling
# export ADORE_DIRECTORY="/path/to/search"
gather_requirements_files "${ADORE_DIRECTORY}"


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

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echoerr (){ printf "%s" "$@" >&2;}
exiterr (){ echoerr "$@"; exit 1;}
SCRIPT_DIRECTORY="/tmp/adore/tools/adore_cli/tools"
if pgrep -f "Xvfb.*:99" > /dev/null 2>&1; then
    export DISPLAY=:99
else
    export DISPLAY=${DISPLAY:-:0}
fi


#SOURCE_DIRECTORY=${SOURCE_DIRECTORY:-/tmp/adore}
ADORE_CLI_DIRECTORY=${ADORE_CLI_DIRECTORY:-/tmp/adore_cli}
#ADORE_CLI_WORKING_DIRECTORY=${SOURCE_DIRECTORY:-/tmp/adore}

if [[ -z ${SOURCE_DIRECTORY+x} ]]; then
    echoerr "ERROR: The environmental variable SOURCE_DIRECTORY is empty, SOURCE_DIRECTORY must be supplied."
    echoerr "  The SOURCE_DIRECTORY is an absolute path containing catkin packages that will be soft linked into the catkin workspace."
    echo ""
    exit 1
fi

if [[ -z ${ADORE_CLI_WORKING_DIRECTORY+x} ]]; then
    echoerr "ERROR: The environmental variable ADORE_CLI_WORKING_DIRECTORY is empty, ADORE_CLI_WORKING_DIRECTORY must be supplied."
    echoerr "  The ADORE_CLI_WORKING_DIRECTORY is an absolute path where the ADORe cli will start as an initial working directory"
    echo ""
    exit 1
fi

clear

cd "${ADORE_CLI_WORKING_DIRECTORY}"
bash "/tmp/adore_cli/tools/adore_cli_motd.sh"
printf "\n"
bash "/tmp/adore_cli/tools/git_repo_status.sh"

echo "=== Environment Status ==="
bash "/tmp/adore_cli/tools/requirements_file_change_status.sh"
bash "/tmp/adore_cli/tools/check_vendor_dependencies.sh"

printf "\n"

# HISTFILE lives inside the directory-mounted /tmp/adore_cli so that zsh's
# atomic rename(.zsh_history.new -> .zsh_history) succeeds on exit.
# A file bind-mount at $HOME/.zsh_history would block that rename syscall.
export HISTFILE="/tmp/adore_cli/.zsh_history"
exec zsh -l

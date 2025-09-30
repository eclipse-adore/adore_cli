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

echoerr (){ printf "%s" "$@" >&2;}
exiterr (){ printf "%s\n" "$@" >&2; exit 1;}

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
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
 

(
cd ${SCRIPT_DIRECTORY}
if [ ! -z "$(git status --porcelain 2>/dev/null)" ]; then
    printf "    ${BOLD}${BLINK}${ORANGE}WARNING:${RESET} The ${BOLD}adore_cli${RESET} repo has changes. \n  Rebuild the adore_cli with 'make build_adore_cli' for new changes to take effect.\n"
    printf "  Commit or discard changes to the adore_cli repo to clear this message.\n"
    #git status
    echo ""
fi
)

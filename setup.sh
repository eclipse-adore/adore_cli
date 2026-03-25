#!/bin/bash
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


SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROS2_WORKSPACE_DIRECTORY="$(realpath "${SCRIPT_DIRECTORY}/ros2_workspace")"

if [ -z "${DISPLAY:-}" ] && [ -f /tmp/.adore_display ]; then
    source /tmp/.adore_display 2>/dev/null || true
fi

if [[ -z "$ROS_SETUP_SOURCED" ]]; then
    case "$SHELL" in
        */zsh)
            source /opt/ros/${ROS_DISTRO}/setup.zsh
            ;;
        */bash)
            source /opt/ros/${ROS_DISTRO}/setup.bash
            ;;
        */sh)
            # fallback, most setups provide setup.sh
            . /opt/ros/${ROS_DISTRO}/setup.sh
            ;;
        *)
            # default fallback
            . /opt/ros/${ROS_DISTRO}/setup.sh
            ;;
    esac
    export ROS_SETUP_SOURCED=1
fi
source /opt/adore_venv/bin/activate

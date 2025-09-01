#!/bin/bash

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROS2_WORKSPACE_DIRECTORY="$(realpath "${SCRIPT_DIRECTORY}/ros2_workspace")"

if pgrep -f "Xvfb.*:99" > /dev/null 2>&1; then
    DISPLAY=:99
else
    DISPLAY=${DISPLAY:-:0}
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


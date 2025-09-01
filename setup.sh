#!/usr/bin/env bash

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROS2_WORKSPACE_DIRECTORY="$(realpath "${SCRIPT_DIRECTORY}/ros2_workspace")"

if pgrep -f "Xvfb.*:99" > /dev/null 2>&1; then
    DISPLAY=:99
else
    DISPLAY=${DISPLAY:-:0}
fi

source /opt/ros/${ROS_DISTRO}/setup.bash

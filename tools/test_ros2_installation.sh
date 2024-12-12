#!/usr/bin/env bash

set -euo pipefail

echoerr() { printf "%b" "$*\n" >&2;}
exiterr (){ printf "%s\n" "$@" >&2; exit 1;}

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"


if ! command -v ros2 &> /dev/null; then
    exiterr "ERROR: ROS 2 is not installed or not in PATH"
fi

ros_version=$(ros2 pkg prefix ros2cli)
echo "ROS 2 Version: $ros_version"
if [[ -z "$ros_version" ]]; then
    exiterr "ERROR: Failed to get ROS 2 version"
fi

if [[ -z "$ROS_DISTRO" ]]; then
    exiterr "ERROR ROS_DISTRO environment variable is not set"
fi
echo "ROS_DISTRO is set to: $ROS_DISTRO"

echo "Testing 'ros2 topic list' command..."
if ! ros2 topic list; then
    exiterr "ERROR: Failed to run 'ros2 topic list'"
else
    echo "'ros2 topic list' command succeeded"
fi

echo "ROS 2 is installed correctly"


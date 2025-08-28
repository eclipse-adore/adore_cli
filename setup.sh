#!/usr/bin/env sh
SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROS2_WORKSPACE_DIRECTORY="$(realpath "${SCRIPT_DIRECTORY}/ros2_workspace")"

# Source ADORe CLI environment variables if available
if [ -f "${SCRIPT_DIRECTORY}/adore_cli.env" ]; then
    . "${SCRIPT_DIRECTORY}/adore_cli.env"
elif [ -f "${SCRIPT_DIRECTORY}/.env" ]; then
    . "${SCRIPT_DIRECTORY}/.env"
fi

shell_name=$(ps -p $$ -o comm=)
case "$shell_name" in
    bash)
        . /opt/ros/${ROS_DISTRO}/setup.bash
        ;;
    zsh)
        . /opt/ros/${ROS_DISTRO}/setup.zsh
        ;;
    sh)
        . /opt/ros/${ROS_DISTRO}/setup.sh
        ;;
    *)
        echo "Unknown shell: $shell_name, defaulting to setup.sh"
        . /opt/ros/${ROS_DISTRO}/setup.sh
        ;;
esac

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



echoerr (){ printf "%s" "$@" >&2;}
exiterr (){ echoerr "$@"; exit 1;}

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

printf "ADORe CLI Help\n"
printf "  At any time you can run 'make help' to get a list of available make targets.\n"
printf "\n"
printf "  Environment: \n"
printf "    %-50s %s\n" "OS:" "$(grep '^VERSION=' /etc/os-release | tr -d '"' | cut -d "=" -f2)"
printf "    %-50s %s\n" "ADORE_SOURCE_DIRECTORY:" "${SOURCE_DIRECTORY}"
printf "    %-50s %s\n" "ROS_VERSION:" "${ROS_VERSION}"
printf "    %-50s %s\n" "ROS_DISTRO:" "${ROS_DISTRO}"
printf "    %-50s %s\n" "ROS_HOME:" "${ROS_HOME}"
printf "    %-50s %s\n" "SHELL:" "/usr/bin/zsh"
printf "    %-50s %s\n" "Docker Image Tag (ADORE_CLI_IMAGE):" "${ADORE_CLI_IMAGE}"
printf "    %-50s %s\n" "Docker Container Name (ADORE_CLI_CONTAINER_NAME):" "${ADORE_CLI_CONTAINER_NAME}"
printf "\n"
available_ram=$(free -m | awk '/^Mem/ {print $7 / 1024}')
free_ram=$(free -m | awk '/^Mem/ {print $4 / 1024}')
available_ram_rounded=$(printf "%.2f" "$available_ram")
free_ram_rounded=$(printf "%.2f" "$free_ram")
printf "    %-50s %s\n" "Available RAM:" "${available_ram_rounded} GB"
printf "    %-50s %s\n" "Free RAM:" "${free_ram_rounded} GB"
printf "\n"
total_storage=$(df -h / | awk 'NR==2 {print $2}')
available_storage=$(df -h / | awk 'NR==2 {print $4}')
printf "    %-50s %s\n" "Total Storage:" "${total_storage}"
printf "    %-50s %s\n" "Available Storage:" "${available_storage}"
printf "\n"
cpu_cores=$(nproc --all)
printf "    %-50s %s\n" "Number of CPU Cores:" "${cpu_cores}"
printf "\n"


printf "  Getting Started:\n"
printf "    To attach another termanal session run: \n"
printf "      'make cli' \n"
printf "    To exit the ADORe CLI type 'exit' \n"
printf "    To terminate the ADORe CLI type 'make stop' \n"
printf "    All Make commands must be run from the ADORe source directory: %s\n" "${SOURCE_DIRECTORY}"
printf "%b" "    \e[1;31mWARNING: All file system changes made OUTSIDE of the ADORe source directory will NOT persist!\e[0m\n\n"

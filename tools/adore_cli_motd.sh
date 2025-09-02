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


printf "Welcome to the ADORe Development CLI %s (%s %s %s)\n\n" "$(lsb_release -a 2>/dev/null | grep Description | cut -d: -f2 | xargs)" "$(uname -o)" "$(uname -r)" "$(uname -m)"

printf "    _    ____   ___  ____                              \n"
printf "   / \  |  _ \ / _ \|  _ \ ___            ____        \n"
printf "  / _ \ | | | | | | | |_) / _ \        __/  |_\__     \n"
printf " / ___ \| |_| | |_| |  _ <  __/       |           -.  \n"
printf " \_/  \_\____/ \___/|_| \_\___| ......'-(_)---(_)--'  \n"


printf "\n"
printf "  Type 'help' for more information.\n"

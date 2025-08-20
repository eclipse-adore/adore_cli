#!/usr/bin/env bash

printf "Welcome to the ADORe Development CLI %s (%s %s %s)\n\n" "$(lsb_release -a 2>/dev/null | grep Description | cut -d: -f2 | xargs)" "$(uname -o)" "$(uname -r)" "$(uname -m)"

printf "            ____                       _    ____   ___  ____      \n"
printf "         __/  |_\__                   / \  |  _ \ / _ \|  _ \ ___ \n"
printf '        |           -.               / _ \ | | | | | | | |_) / _ \\\n'
printf "  ......'-(_)---(_)--'              / ___ \| |_| | |_| |  _ <  __/\n"
printf "                                    \_/  \_\____/ \___/|_| \_\___|\n"
printf "\n"
printf "  Type 'help' for more information.\n"

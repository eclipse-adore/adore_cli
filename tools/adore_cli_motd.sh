#!/usr/bin/env bash

printf "Welcome to the ADORe Development CLI %s (%s %s %s)\n\n" "$(lsb_release -a 2>/dev/null | grep Description | cut -d: -f2 | xargs)" "$(uname -o)" "$(uname -r)" "$(uname -m)"

printf "    _    ____   ___  ____                              \n"
printf "   / \  |  _ \ / _ \|  _ \ ___            ____        \n"
printf "  / _ \ | | | | | | | |_) / _ \        __/  |_\__     \n"
printf " / ___ \| |_| | |_| |  _ <  __/       |           -.  \n"
printf " \_/  \_\____/ \___/|_| \_\___| ......'-(_)---(_)--'  \n"


printf "\n"
printf "  Type 'help' for more information.\n"

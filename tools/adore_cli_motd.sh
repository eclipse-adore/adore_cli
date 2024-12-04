#!/usr/bin/env bash

printf "Welcome to the ADORe Development CLI %s (%s %s %s)\n\n" "$(lsb_release -a 2>/dev/null | grep Description | cut -d: -f2 | xargs)" "$(uname -o)" "$(uname -r)" "$(uname -m)"

printf "            ____ \n"
printf "         __/  |_\__\n"
printf '        |           -. \n'
printf "  ......'-(_)---(_)--' \n" 


printf "  Type 'help' for more information.\n"


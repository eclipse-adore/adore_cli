# === IMMEDIATE NON-INTERACTIVE EXIT ===
if [[ $- != *i* ]] || [[ -z "$PS1" ]] || [[ -n "$DOCKER_EXEC_NON_INTERACTIVE" ]]; then
    source /opt/ros/${ROS_DISTRO}/setup.zsh 2>/dev/null
    if [ -f /tmp/adore/setup.sh ]; then
        source /tmp/adore/setup.sh 2>/dev/null
    fi
    return 0
fi

# === DISABLE ALL ZSH SECURITY AND INTERACTIVE FEATURES ===
export ZSH_DISABLE_COMPFIX="true"
export ZSH_COMPDUMP="${HOME}/.zcompdump"
skip_global_compinit=1

# === OPTIMIZED HISTORY CONFIGURATION ===
setopt INC_APPEND_HISTORY 2>/dev/null
setopt SHARE_HISTORY 2>/dev/null  
setopt EXTENDED_HISTORY 2>/dev/null
export HISTFILESIZE=50000
export HISTSIZE=10000
export HISTTIMEFORMAT="%Y-%m-%dT%H:%M:%S%z "

# === LOAD COLORS FIRST ===
autoload -U colors && colors 2>/dev/null
setopt prompt_subst 2>/dev/null

# === OH-MY-ZSH CONFIGURATION ===
if [ -d "/usr/share/oh-my-zsh" ]; then
    export ZSH="/usr/share/oh-my-zsh"
elif [ -d "${HOME}/.oh-my-zsh" ]; then
    export ZSH="${HOME}/.oh-my-zsh"
else
    export ZSH=""
fi

ZSH_THEME="robbyrussell"
plugins=(git)

# Source oh-my-zsh only if found
if [ -n "$ZSH" ] && [ -f "$ZSH/oh-my-zsh.sh" ]; then
    source $ZSH/oh-my-zsh.sh 2>/dev/null
    OMZ_LOADED=true
else
    OMZ_LOADED=false
fi

# === SIMPLIFIED PROMPT ===
PROMPT='%B%F{cyan}ADORe CLI:%f %F{cyan}%c%f %(?.%F{green}.%F{red})>%f%b '

# === ALIASES ===
alias help='bash /tmp/adore_cli/tools/adore_cli_help.sh'

# === ROS2 SETUP ===
if [[ -z "$ROS_SETUP_SOURCED" ]]; then
    source /opt/ros/${ROS_DISTRO}/setup.zsh 2>/dev/null
    export ROS_SETUP_SOURCED=1
fi

# === ADORE SETUP ===
if [[ -z "$ADORE_SETUP_SOURCED" ]] && [ -f /tmp/adore/setup.sh ]; then
    export SHELL=zsh
    source /tmp/adore/setup.sh 2>/dev/null
    export ADORE_SETUP_SOURCED=1
fi

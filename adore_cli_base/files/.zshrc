# === IMMEDIATE NON-INTERACTIVE EXIT ===
# Exit immediately if not interactive to prevent any prompts
if [[ $- != *i* ]] || [[ -z "$PS1" ]] || [[ -n "$DOCKER_EXEC_NON_INTERACTIVE" ]]; then
    # Minimal non-interactive setup
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

# === OH-MY-ZSH CONFIGURATION WITH EXPLICIT PATHS ===
# Set explicit path to avoid variable corruption
if [ -d "/usr/share/oh-my-zsh" ]; then
    export ZSH="/usr/share/oh-my-zsh"
elif [ -d "${HOME}/.oh-my-zsh" ]; then
    export ZSH="${HOME}/.oh-my-zsh"
else
    export ZSH=""
fi

ZSH_THEME="robbyrussell"
plugins=(git)

# === HISTORY CONFIGURATION ===
setopt INC_APPEND_HISTORY 2>/dev/null
setopt SHARE_HISTORY 2>/dev/null  
setopt EXTENDED_HISTORY 2>/dev/null
export HISTFILESIZE=10000000000000
export HISTSIZE=100000000000000
export HISTTIMEFORMAT="%Y-%m-%dT%H:%M:%S%z "

function history_iso() {
    awk -F';' "{print strftime(\"${HISTTIMEFORMAT}\", $1), $2}" ~/.zsh_history
}
alias history="history_iso"

# === LOAD COLORS FIRST ===
autoload -U colors && colors 2>/dev/null
setopt prompt_subst 2>/dev/null

# === SOURCE OH-MY-ZSH ===
if [ -n "$ZSH" ] && [ -f "$ZSH/oh-my-zsh.sh" ]; then
    source $ZSH/oh-my-zsh.sh 2>/dev/null
    OMZ_LOADED=true
else
    echo "Oh-my-zsh not found, using fallback configuration"
    echo "Checked paths:"
    echo "  - /usr/share/oh-my-zsh/oh-my-zsh.sh"
    echo "  - ${HOME}/.oh-my-zsh/oh-my-zsh.sh"
    OMZ_LOADED=false
fi

# === CUSTOM PROMPT CONFIGURATION ===
BLUE='%F{blue}'
RED='%F{red}'
RESET='%f'

git_prompt_info_all() {
  local branch
  local commit
  
  # Use oh-my-zsh colors if available, otherwise use fallback
  if [[ "$OMZ_LOADED" == "true" ]] && [[ -n "$fg_bold" ]]; then
    local blue="%{$fg_bold[blue]%}"
    local red="%{$fg_bold[red]%}"
    local reset="%{$reset_color%}"
  else
    local blue="%F{blue}"
    local red="%F{red}"  
    local reset="%f"
  fi
  
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null)
    commit=$(git rev-parse --short HEAD 2>/dev/null)
    
    if [ -z "$branch" ]; then
        source_branch=$(git name-rev --name-only HEAD 2>/dev/null)
        if [ ! -z "$source_branch" ]; then
            branch="${source_branch}:detached"
        fi
    fi
    
    if [ -z "$branch" ]; then
        branch="NOT ON BRANCH"
    fi
    
    if [ -z "$commit" ]; then
        commit="INITIAL COMMIT"
    fi
    
    echo "${blue}(${red}${branch}:${commit}${blue})${reset}"
  fi
}

# === PROMPT SETUP WITH OMZ DETECTION ===
if [[ "$OMZ_LOADED" == "true" ]] && [[ -n "$fg_bold" ]]; then
    # Oh-my-zsh loaded successfully - use rich colors
    PROMPT='%B%F{grey}%F{cyan}ADORe CLI:%F %{$fg_bold[cyan]%}%c%{$reset_color%}$(git_prompt_info_all)%{$fg[green]%}%(?:%{%}:%{%}) %(?.%F{green}.%F{red})(%?)%b%f> %{%}'
else
    # Fallback - use basic colors
    PROMPT='%B%F{blue}ADORe CLI:%f %F{cyan}%c%f$(git_prompt_info_all)%F{green}%(?:%f:%f) %(?.%F{green}.%F{red})(%?)%b%f> %f'
fi

# === ALIASES ===
alias help='bash /tmp/adore_cli/tools/adore_cli_help.sh'

# === ROS2 SETUP ===
source /opt/ros/${ROS_DISTRO}/setup.zsh 2>/dev/null

# === ADORE SETUP ===
if [ -f /tmp/adore/setup.sh ]; then
    export SHELL=zsh
    source /tmp/adore/setup.sh 2>/dev/null
fi




# === IMMEDIATE NON-INTERACTIVE EXIT ===
if [[ $- != *i* ]] || [[ -z "$PS1" ]] || [[ -n "$DOCKER_EXEC_NON_INTERACTIVE" ]]; then
    source /opt/ros/${ROS_DISTRO}/setup.zsh 2>/dev/null
    if [ -f /tmp/adore/setup.sh ]; then
        source /tmp/adore/setup.sh 2>/dev/null
    fi
    if [[ -z "${DISPLAY}" ]]; then
        [ -f /tmp/.adore_display ] && source /tmp/.adore_display 2>/dev/null || true
    fi
    return 0
fi

# === DISABLE ALL ZSH SECURITY AND INTERACTIVE FEATURES ===
export ZSH_DISABLE_COMPFIX="true"
export ZSH_COMPDUMP="${HOME}/.zcompdump"
skip_global_compinit=1

# === HISTORY CONFIGURATION ===
export HISTFILESIZE=50000
export HISTSIZE=10000

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




# === PROMPT ===
autoload -U colors && colors
_git_repo_name() { 
    gittopdir=$(git rev-parse --git-dir 2> /dev/null)
    if [[ "foo$gittopdir" == "foo.git" ]]; then
        echo `basename $(pwd)`
    elif [[ "foo$gittopdir" != "foo" ]]; then
        # Check if it's a submodule (git dir contains .git/modules)
        if [[ "$gittopdir" == *".git/modules/"* ]]; then
            # For submodules, get the actual repo name from the submodule path
            echo `basename $(git rev-parse --show-toplevel)`
        else
            echo `dirname $gittopdir | xargs basename`
        fi
    fi
}
_git_branch_name() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null
}
_git_hash() {
    git rev-parse --short HEAD 2>/dev/null
}
_git_is_dirty() { 
   git diff --quiet 2> /dev/null || echo '*'
}
git_prompt_info_all() {
    local branch=$(_git_branch_name)
    if [[ -n $branch ]]; then
        local hash=$(_git_hash)
        local dirty=$(_git_is_dirty)
        echo "%{$fg_bold[blue]%}(%{$fg_bold[red]%}$branch:$hash$dirty%{$fg[blue]%})"
    fi
}
setopt prompt_subst
PROMPT='%B%F{cyan}ADORe CLI:%f %{$fg_bold[cyan]%}%c%{$reset_color%}$(git_prompt_info_all)%{$fg[green]%}' 
PROMPT+="%(?:%{$fg_bold[green]%}:%{$fg_bold[red]%}) > %{$reset_color%}%b" 
ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}(%{$fg_bold[red]%}" 
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}" 
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}✗" 
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"
RPROMPT=""


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

# === HISTORY - forced last, overrides everything including oh-my-zsh and setup.sh ===
HISTFILE="${HISTFILE:-/tmp/adore_cli/.zsh_history}"
setopt EXTENDED_HISTORY          2>/dev/null
setopt INC_APPEND_HISTORY_TIME   2>/dev/null
setopt SHARE_HISTORY             2>/dev/null

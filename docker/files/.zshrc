export ZSH="${HOME}/.oh-my-zsh"

ZSH_THEME="robbyrussell"

setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY
setopt EXTENDED_HISTORY

export HISTFILESIZE=10000000000000
export HISTSIZE=100000000000000
export HISTTIMEFORMAT="%Y-%m-%dT%H:%M:%S%z "

function history_iso() {
    awk -F';' "{print strftime(\"${HISTTIMEFORMAT}\", $1), $2}" ~/.zsh_history
}
alias history="history_iso"

BLUE='%F{blue}'
RED='%F{red}'
RESET='%f'

git_prompt_info_all() {
  local branch
  local commit
  local blue="%{$fg_bold[blue]%}"
  local red="%{$fg_bold[red]%}"
  local reset="%{$reset_color%}"

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






plugins=(git)
source $ZSH/oh-my-zsh.sh
autoload -U colors && colors
_git_repo_name() { 
    gittopdir=$(git rev-parse --git-dir 2> /dev/null)
    if [[ "foo$gittopdir" == "foo.git" ]]; then
        echo `basename $(pwd)`
    elif [[ "foo$gittopdir" != "foo" ]]; then
        echo `dirname $gittopdir | xargs basename`
    fi
}
_git_branch_name() {    
    git branch 2>/dev/null | awk '/^\*/ { print $2 }'
}    
 _git_is_dirty() { 
   git diff --quiet 2> /dev/null || echo '*'
 }

setopt prompt_subst




#PROMPT='%B%F{grey}[%F{cyan}ADORe CLI %F %F{magenta}%~%F{grey} %(?.%F{green}.%F{red})=>(%?) %b%f] $ '
#PROMPT='%B%F{grey}%F{cyan}ADORe CLI:%F %{$fg_bold[green]%}%c %{$reset_color%}$(git_prompt_info)%{$fg[green]%}%(?:%{%}:%{%}) %(?.%F{green}.%F{red})(%?)%b%f> %{%} '
#RPROMPT=$(git_prompt_info)
PROMPT='%B%F{grey}%F{cyan}ADORe CLI:%F %{$fg_bold[cyan]%}%c%{$reset_color%}$(git_prompt_info_all)%{$fg[green]%}%(?:%{%}:%{%}) %(?.%F{green}.%F{red})(%?)%b%f> %{%}'


alias help='bash /tmp/adore_cli/tools/adore_cli_help.sh'
source /opt/ros/${ROS_DISTRO}/setup.zsh
if [ -f /tmp/adore/setup.sh ]; then
    export SHELL=zsh
    source /tmp/adore/setup.sh 
fi

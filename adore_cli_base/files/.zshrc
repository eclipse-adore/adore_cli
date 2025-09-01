# === TIMING DEBUG VERSION OF .zshrc WITH LOGGING ===

# Create log directory and file
mkdir -p "${HOME}/.log" 2>/dev/null || mkdir -p "/tmp/adore/.log" 2>/dev/null
LOG_FILE="${HOME}/.log/zsh.log"
if [[ ! -w "$(dirname "$LOG_FILE")" ]]; then
    LOG_FILE="/tmp/adore/.log/zsh.log"
fi

debug_time() {
    local timestamp=$(date +%s.%3N)
    local elapsed=$(echo "$timestamp - ${START_TIME:-$timestamp}" | bc -l 2>/dev/null || echo "0")
    local message="DEBUG: $1 at $timestamp (${elapsed}s elapsed)"
    echo "$message" >> "$LOG_FILE"
    echo "$message" >&2  # Also output to stderr for immediate feedback
}

START_TIME=$(date +%s.%3N)

# Initialize log file
echo "=== ZSH STARTUP LOG $(date) ===" > "$LOG_FILE"
echo "User: $(whoami)" >> "$LOG_FILE"
echo "PWD: $(pwd)" >> "$LOG_FILE"
echo "Shell: $0" >> "$LOG_FILE"
echo "=================================" >> "$LOG_FILE"

debug_time "Starting .zshrc"

# === IMMEDIATE NON-INTERACTIVE EXIT ===
if [[ $- != *i* ]] || [[ -z "$PS1" ]] || [[ -n "$DOCKER_EXEC_NON_INTERACTIVE" ]]; then
    debug_time "Non-interactive mode detected"
    source /opt/ros/${ROS_DISTRO}/setup.zsh 2>/dev/null
    debug_time "ROS setup sourced (non-interactive)"
    if [ -f /tmp/adore/setup.sh ]; then
        source /tmp/adore/setup.sh 2>/dev/null
        debug_time "ADORE setup sourced (non-interactive)"
    fi
    debug_time "Exiting non-interactive mode"
    return 0
fi

debug_time "Interactive mode confirmed"

# === DISABLE ALL ZSH SECURITY AND INTERACTIVE FEATURES ===
export ZSH_DISABLE_COMPFIX="true"
export ZSH_COMPDUMP="${HOME}/.zcompdump"
skip_global_compinit=1
debug_time "ZSH security settings configured"

# === OPTIMIZED HISTORY CONFIGURATION ===
setopt INC_APPEND_HISTORY 2>/dev/null
setopt SHARE_HISTORY 2>/dev/null  
setopt EXTENDED_HISTORY 2>/dev/null
export HISTFILESIZE=50000
export HISTSIZE=10000
export HISTTIMEFORMAT="%Y-%m-%dT%H:%M:%S%z "
debug_time "History configuration set"

# === LOAD COLORS FIRST ===
debug_time "Starting to load colors"
autoload -U colors && colors 2>/dev/null
debug_time "Colors autoloaded"
setopt prompt_subst 2>/dev/null
debug_time "Prompt substitution enabled"

# === OH-MY-ZSH CHECK ===
debug_time "Checking for oh-my-zsh directories"
if [ -d "/usr/share/oh-my-zsh" ]; then
    export ZSH="/usr/share/oh-my-zsh"
    debug_time "Found oh-my-zsh at /usr/share/oh-my-zsh"
elif [ -d "${HOME}/.oh-my-zsh" ]; then
    export ZSH="${HOME}/.oh-my-zsh"
    debug_time "Found oh-my-zsh at ${HOME}/.oh-my-zsh"
else
    export ZSH=""
    debug_time "oh-my-zsh not found"
fi

debug_time "Setting oh-my-zsh theme and plugins"
ZSH_THEME="robbyrussell"
plugins=()  # Disable all plugins temporarily
debug_time "Theme and plugins configured"

# Source oh-my-zsh only if found
if [ -n "$ZSH" ] && [ -f "$ZSH/oh-my-zsh.sh" ]; then
    debug_time "Starting to source oh-my-zsh from $ZSH/oh-my-zsh.sh"
    source $ZSH/oh-my-zsh.sh 2>/dev/null
    debug_time "oh-my-zsh sourced successfully"
    OMZ_LOADED=true
else
    debug_time "Skipping oh-my-zsh (not found at $ZSH/oh-my-zsh.sh)"
    OMZ_LOADED=false
fi

# === SIMPLIFIED PROMPT (no git for now) ===
debug_time "Configuring prompt"
PROMPT='%B%F{cyan}ADORe CLI:%f %F{cyan}%c%f %(?.%F{green}.%F{red})>%f%b '
debug_time "Prompt configured"

# === ALIASES ===
debug_time "Setting aliases"
alias help='bash /tmp/adore_cli/tools/adore_cli_help.sh'
debug_time "Aliases set"

# === ROS2 SETUP ===
if [[ -z "$ROS_SETUP_SOURCED" ]]; then
    debug_time "Starting ROS setup from /opt/ros/${ROS_DISTRO}/setup.zsh"
    if [ -f "/opt/ros/${ROS_DISTRO}/setup.zsh" ]; then
        source /opt/ros/${ROS_DISTRO}/setup.zsh 2>/dev/null
        debug_time "ROS setup completed successfully"
    else
        debug_time "ROS setup file not found at /opt/ros/${ROS_DISTRO}/setup.zsh"
    fi
    export ROS_SETUP_SOURCED=1
    debug_time "ROS_SETUP_SOURCED flag set"
else
    debug_time "ROS setup skipped (already sourced)"
fi

# === ADORE SETUP ===
if [[ -z "$ADORE_SETUP_SOURCED" ]] && [ -f /tmp/adore/setup.sh ]; then
    debug_time "Starting ADORE setup from /tmp/adore/setup.sh"
    export SHELL=zsh
    debug_time "SHELL set to zsh for ADORE setup"
    source /tmp/adore/setup.sh 2>/dev/null
    debug_time "ADORE setup completed"
    export ADORE_SETUP_SOURCED=1
    debug_time "ADORE_SETUP_SOURCED flag set"
elif [[ -n "$ADORE_SETUP_SOURCED" ]]; then
    debug_time "ADORE setup skipped (already sourced)"
else
    debug_time "ADORE setup skipped (no /tmp/adore/setup.sh found)"
fi

debug_time ".zshrc completed successfully"

# Final log entry
echo "=== ZSH STARTUP COMPLETED $(date) ===" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

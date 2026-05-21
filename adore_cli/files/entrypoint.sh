#!/bin/bash
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

# Do NOT use set -e here — this is PID 1. Any unhandled error would kill the
# container. Each section handles its own failures explicitly.
set -o pipefail

TARGET_USER="${USER:-adore}"
TARGET_UID="${UID:-1000}"
TARGET_GID="${GID:-1000}"

echo "Starting ADORe CLI entrypoint..."
echo "User: $TARGET_USER (UID=$TARGET_UID, GID=$TARGET_GID)"

# =========================
# ROOT PHASE
# =========================
if [ "${RUN_AS_USER:-0}" != "1" ]; then

    getent group "$TARGET_GID" >/dev/null 2>&1 || groupadd --gid "$TARGET_GID" "$TARGET_USER" 2>/dev/null || true

    if getent passwd "$TARGET_UID" >/dev/null 2>&1; then
        EXISTING_USER=$(getent passwd "$TARGET_UID" | cut -d: -f1)
        if [ "$EXISTING_USER" != "$TARGET_USER" ]; then
            usermod -l "$TARGET_USER" "$EXISTING_USER" 2>/dev/null || true
            usermod -d "/home/$TARGET_USER" -m "$TARGET_USER" 2>/dev/null || true
        fi
    else
        useradd --create-home --uid "$TARGET_UID" --gid "$TARGET_GID" --shell /bin/zsh "$TARGET_USER" 2>/dev/null || true
    fi

    if [ -n "${TZ:-}" ]; then
        ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime 2>/dev/null || true
        echo "${TZ}" > /etc/timezone 2>/dev/null || true
    fi

    HOME_DIR=$(getent passwd "$TARGET_UID" | cut -d: -f6)
    HOME_DIR="${HOME_DIR:-/home/$TARGET_USER}"
    mkdir -p "$HOME_DIR"
    [ ! -f "$HOME_DIR/.zshrc" ] && cp /etc/skel/.zshrc "$HOME_DIR/" 2>/dev/null || true
    chown -R "$TARGET_UID:$TARGET_GID" "$HOME_DIR" 2>/dev/null || true

    usermod -aG tracing "$TARGET_USER" 2>/dev/null || true
    usermod -aG syslog  "$TARGET_USER" 2>/dev/null || true

    echo "$TARGET_USER ALL = NOPASSWD : /usr/sbin/rsyslogd, /usr/bin/apt-get, /usr/bin/apt, /usr/bin/python3, /usr/bin/apt-file, /usr/bin/apt-cache, /usr/bin/aptitude" >> /etc/sudoers 2>/dev/null || true

    mkdir -p /tmp/adore /tmp/adore/.log/rsyslog /var/log/ros2/rsyslog /var/spool/rsyslog
    chown -R "$TARGET_UID:$TARGET_GID" /tmp/adore /var/log/ros2 /var/spool/rsyslog 2>/dev/null || true

    export RUN_AS_USER=1
    exec gosu "${TARGET_UID}:${TARGET_GID}" "$0" "$@"
fi

# =========================
# USER PHASE
# =========================

umask 002

if [ -f /tmp/adore/adore_cli.env ]; then
    set -a
    source /tmp/adore/adore_cli.env 2>/dev/null || true
    set +a
elif [ -f /tmp/adore/.env ]; then
    set -a
    source /tmp/adore/.env 2>/dev/null || true
    set +a
fi

# === DISPLAY SETUP ===
XVFB_PID=""

detect_host_display() {
    [ -z "${DISPLAY:-}" ] && return 1
    local display_num="${DISPLAY##*:}"
    display_num="${display_num%%.*}"
    [ -S "/tmp/.X11-unix/X${display_num}" ] && return 0
    return 1
}

if [ "${VIRTUAL_DISPLAY:-false}" = "true" ] || ! detect_host_display; then
    Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset >/dev/null 2>&1 &
    XVFB_PID=$!
    sleep 2
    export DISPLAY=":99"
fi

echo "export DISPLAY=${DISPLAY}" > /tmp/.adore_display

# === RSYSLOG SETUP ===
bash /etc/rsyslog_reload.sh 2>/dev/null || true

# === ROS / PROJECT SETUP ===
# setup.sh checks $SHELL to pick bash vs zsh scripts; source it as bash explicitly.
# It also launches services (adore_api, zenoh) via plain `bash` calls — those are
# fire-and-forget and return immediately, so sourcing here does not block.
if [ -f /tmp/adore/setup.sh ]; then
    set +u
    SHELL=/bin/bash source /opt/ros/${ROS_DISTRO}/setup.bash 2>/dev/null || true
    SHELL=/bin/bash source /tmp/adore/setup.sh 2>/dev/null || true
    set -u 2>/dev/null || true
fi

# =========================
# CLEAN SHUTDOWN
# =========================

shutdown() {
    echo "Shutting down services..."
    [ -n "$XVFB_PID" ] && kill "$XVFB_PID" 2>/dev/null || true
    exit 0
}
trap shutdown TERM INT

echo "ADORe CLI ready"

sleep infinity &
wait $!

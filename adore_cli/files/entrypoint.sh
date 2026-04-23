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
    echo "Running root phase..."

    # Create group if needed
    getent group "$TARGET_GID" >/dev/null 2>&1 || \
        groupadd --gid "$TARGET_GID" "$TARGET_USER" 2>/dev/null || true

    # Create or adapt user
    if getent passwd "$TARGET_UID" >/dev/null 2>&1; then
        EXISTING_USER=$(getent passwd "$TARGET_UID" | cut -d: -f1)
        if [ "$EXISTING_USER" != "$TARGET_USER" ]; then
            usermod -l "$TARGET_USER" "$EXISTING_USER" 2>/dev/null || true
            usermod -d "/home/$TARGET_USER" -m "$TARGET_USER" 2>/dev/null || true
        fi
    else
        useradd --create-home \
                --uid "$TARGET_UID" \
                --gid "$TARGET_GID" \
                --shell /bin/zsh \
                "$TARGET_USER" 2>/dev/null || true
    fi

    # Timezone
    if [ -n "${TZ:-}" ]; then
        ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime 2>/dev/null || true
        echo "${TZ}" > /etc/timezone 2>/dev/null || true
    fi

    HOME_DIR=$(getent passwd "$TARGET_UID" | cut -d: -f6)
    HOME_DIR="${HOME_DIR:-/home/$TARGET_USER}"

    mkdir -p "$HOME_DIR"
    chown -R "$TARGET_UID:$TARGET_GID" "$HOME_DIR" 2>/dev/null || true

    cp /etc/skel/.zshrc "$HOME_DIR/.zshrc" 2>/dev/null || true
    chown "$TARGET_UID:$TARGET_GID" "$HOME_DIR/.zshrc" 2>/dev/null || true

    usermod -aG tracing "$TARGET_USER" 2>/dev/null || true
    usermod -aG syslog  "$TARGET_USER" 2>/dev/null || true

    echo "$TARGET_USER ALL = NOPASSWD : /usr/sbin/rsyslogd, /usr/bin/apt-get, /usr/bin/apt, /usr/bin/python3" >> /etc/sudoers 2>/dev/null || true

    # Prepare directories BEFORE dropping privileges
    mkdir -p /tmp/adore /var/log/ros2
    chown -R "$TARGET_UID:$TARGET_GID" /tmp/adore /var/log/ros2 2>/dev/null || true

    export RUN_AS_USER=1

    echo "Switching to user phase..."
    exec gosu "${TARGET_UID}:${TARGET_GID}" "$0" "$@"
fi

# =========================
# USER PHASE
# =========================

echo "Running user phase as $(id)"

umask 002

# ROS setup
if [ -f /tmp/adore/setup.sh ]; then
    (
        set +u
        source /opt/ros/${ROS_DISTRO}/setup.bash 2>/dev/null || true
        source /tmp/adore/setup.sh 2>/dev/null || true
    ) || true
else
    (
        set +u
        source /opt/ros/${ROS_DISTRO}/setup.bash 2>/dev/null || true
    ) || true
fi

if [ -f /tmp/adore/adore_cli.env ]; then
    source /tmp/adore/adore_cli.env 2>/dev/null || true
elif [ -f /tmp/adore/.env ]; then
    source /tmp/adore/.env 2>/dev/null || true
fi

# Logging directories created as USER
mkdir -p /tmp/adore/.log/rsyslog
mkdir -p /var/log/ros2/rsyslog

# =========================
# DISPLAY SETUP
# =========================

XVFB_PID=""

detect_host_display() {
    if [ -z "${DISPLAY:-}" ]; then
        echo "DISPLAY not set"
        return 1
    fi

    display_num="${DISPLAY##*:}"
    display_num="${display_num%%.*}"
    socket="/tmp/.X11-unix/X${display_num}"

    if [ ! -S "${socket}" ]; then
        echo "X11 socket not found: ${socket}"
        return 1
    fi

    return 0
}

ACTIVE_DISPLAY=""
USE_XVFB=0

if detect_host_display; then
    if [ "${VIRTUAL_DISPLAY:-false}" = "true" ]; then
        USE_XVFB=1
    else
        ACTIVE_DISPLAY="${DISPLAY}"
    fi
else
    USE_XVFB=1
fi

if [ "${USE_XVFB}" = "1" ]; then
    Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset >/dev/null 2>&1 &
    XVFB_PID=$!
    sleep 2
    ACTIVE_DISPLAY=":99"
fi

export DISPLAY="${ACTIVE_DISPLAY}"
echo "export DISPLAY=${ACTIVE_DISPLAY}" > /tmp/.adore_display

# =========================
# RSYSLOG SETUP (USER OWNED)
# =========================

RSYSLOG_PID=""
RSYSLOG_CONFIG="/var/log/ros2/rsyslog/rsyslog.conf"

if [ -f /etc/rsyslog.conf.template ]; then
    envsubst '${UID} ${GID} ${USER}' \
        < /etc/rsyslog.conf.template > "$RSYSLOG_CONFIG" 2>/dev/null || true

    chmod 644 "$RSYSLOG_CONFIG" 2>/dev/null || true

    rsyslogd -n -f "$RSYSLOG_CONFIG" >/var/log/ros2/rsyslog/rsyslogd.log 2>&1 &
    RSYSLOG_PID=$!
fi

# =========================
# CLEAN SHUTDOWN
# =========================

shutdown() {
    echo "Shutting down..."
    [ -n "$RSYSLOG_PID" ] && kill "$RSYSLOG_PID" 2>/dev/null || true
    [ -n "$XVFB_PID" ]   && kill "$XVFB_PID"   2>/dev/null || true
    exit 0
}

trap shutdown TERM INT

echo "ADORe CLI ready"

# =========================
# EXEC
# =========================

source ${SOURCE_DIRECTORY}/setup.sh

if [ "$#" -gt 0 ]; then
    exec "$@"
else
    exec sleep infinity
fi

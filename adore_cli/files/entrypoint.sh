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

# === DYNAMIC USER CREATION ===
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

HOME_DIR=$(getent passwd "$TARGET_UID" | cut -d: -f6)
HOME_DIR="${HOME_DIR:-/home/$TARGET_USER}"
mkdir -p "$HOME_DIR"
[ ! -f "$HOME_DIR/.zshrc" ] && cp /etc/skel/.zshrc "$HOME_DIR/" 2>/dev/null || true
chown -R "$TARGET_UID:$TARGET_GID" "$HOME_DIR" 2>/dev/null || true

usermod -aG tracing "$TARGET_USER" 2>/dev/null || true
usermod -aG syslog  "$TARGET_USER" 2>/dev/null || true

echo "$TARGET_USER ALL = NOPASSWD : /usr/sbin/rsyslogd, /usr/bin/apt-get, /usr/bin/apt, /usr/bin/python3, /usr/bin/apt-file, /usr/bin/apt-cache, /usr/bin/aptitude" >> /etc/sudoers 2>/dev/null || true

chown -R "$TARGET_UID:$TARGET_GID" /var/log/ros2 2>/dev/null || true
chown -R "$TARGET_UID:$TARGET_GID" /var/spool/rsyslog 2>/dev/null || true

# === ROS / PROJECT SETUP ===
if [ -f /tmp/adore/setup.sh ]; then
    echo "Found setup.sh, sourcing..."
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

# === DISPLAY SETUP ===
XVFB_PID=""
detect_display() {
    [ "${VIRTUAL_DISPLAY:-false}" = "true" ] && return 1
    if [ -d "/sys/class/drm" ]; then
        for status_file in /sys/class/drm/card*/status; do
            [ -f "$status_file" ] && [ "$(cat "$status_file" 2>/dev/null)" = "connected" ] && return 0
        done
    fi
    return 1
}

if ! detect_display; then
    echo "Starting virtual display on :99..."
    Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset >/dev/null 2>&1 &
    XVFB_PID=$!
    echo "Virtual display started (PID: $XVFB_PID)"
    sleep 2
    export DISPLAY=":99"
else
    export DISPLAY="${DISPLAY:-:0}"
fi

echo "export DISPLAY=${DISPLAY}" > /tmp/.adore_display

# === RSYSLOG SETUP ===
bash /etc/rsyslog_reload.sh 2>/dev/null || true

shutdown() {
    echo "Shutting down services..."
    if [ -f "/tmp/adore/.log/rsyslog/rsyslogd.pid" ]; then
        kill "$(cat /tmp/adore/.log/rsyslog/rsyslogd.pid 2>/dev/null)" 2>/dev/null || true
    fi
    [ -n "$XVFB_PID" ] && kill "$XVFB_PID" 2>/dev/null || true
    exit 0
}
trap shutdown TERM INT

echo "ADORe CLI ready"
[ -n "$XVFB_PID" ] && echo "Virtual display PID: $XVFB_PID"

# Keep container alive. Interactive sessions attach via:
#   docker exec --user <uid>:<gid> -it <container> /bin/zsh
sleep infinity &
wait $!

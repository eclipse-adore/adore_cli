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
chown -R "$TARGET_UID:$TARGET_GID" "$HOME_DIR" 2>/dev/null || true
cp /etc/skel/.zshrc "$HOME_DIR/.zshrc" 2>/dev/null || true
chown "$TARGET_UID:$TARGET_GID" "$HOME_DIR/.zshrc" 2>/dev/null || true


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

# Probes each component of the display stack and logs the result of each check.
# Returns 0 if a usable host X server is accessible, 1 if Xvfb is needed.
detect_host_display() {
    local display_num socket xhost_out xhost_rc

    if [ -d "/sys/class/drm" ]; then
        local connected
        connected=$(grep -rl "^connected$" /sys/class/drm/card*/status 2>/dev/null | head -1)
        if [ -n "$connected" ]; then
            echo "  DRM: physical output connected (${connected%/status})"
        else
            echo "  DRM: no physical output detected"
        fi
    fi

    if [ -z "${DISPLAY:-}" ]; then
        echo "  DISPLAY: not set — no host display was forwarded into the container"
        return 1
    fi
    echo "  DISPLAY: ${DISPLAY}"

    display_num="${DISPLAY##*:}"
    display_num="${display_num%%.*}"
    socket="/tmp/.X11-unix/X${display_num}"

    if [ ! -S "${socket}" ]; then
        echo "  X11 socket: ${socket} not found"
        return 1
    fi
    echo "  X11 socket: ${socket} found"

    if command -v xhost >/dev/null 2>&1; then
        xhost_out=$(DISPLAY="${DISPLAY}" xhost 2>&1)
        xhost_rc=$?
        if [ "${xhost_rc}" -ne 0 ]; then
            echo "  xhost: failed (rc=${xhost_rc}) — ${xhost_out}"
            return 1
        fi
        echo "  xhost: accessible"
    else
        echo "  xhost: not available, skipping access check"
    fi

    return 0
}

echo "Detecting display..."
ACTIVE_DISPLAY=""
USE_XVFB=0

if detect_host_display; then
    if [ "${VIRTUAL_DISPLAY:-false}" = "true" ]; then
        echo "  Host display available but VIRTUAL_DISPLAY=true — using Xvfb"
        USE_XVFB=1
    else
        ACTIVE_DISPLAY="${DISPLAY}"
        echo "  Using host display: DISPLAY=${ACTIVE_DISPLAY}"
    fi
else
    echo "  No usable host display — starting Xvfb on :99"
    USE_XVFB=1
fi

if [ "${USE_XVFB}" = "1" ]; then
    Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset >/dev/null 2>&1 &
    XVFB_PID=$!
    echo "Virtual display started (PID: ${XVFB_PID})"
    sleep 2
    ACTIVE_DISPLAY=":99"
fi

export DISPLAY="${ACTIVE_DISPLAY}"

# === RSYSLOG SETUP ===
export RSYSLOG_PROTOCOL="${RSYSLOG_PROTOCOL:-udp}"

if [ -n "${RSYSLOG_PORT:-}" ]; then
    if [ "$RSYSLOG_PROTOCOL" = "tcp" ]; then
        export UDP_INPUT_CONFIG=""
        export TCP_INPUT_CONFIG="module(load=\"imtcp\")
input(type=\"imtcp\" port=\"${RSYSLOG_PORT}\")"
    else
        export UDP_INPUT_CONFIG="module(load=\"imudp\")
input(type=\"imudp\" port=\"${RSYSLOG_PORT}\")"
        export TCP_INPUT_CONFIG=""
    fi
else
    export RSYSLOG_PORT=""
    export UDP_INPUT_CONFIG=""
    export TCP_INPUT_CONFIG=""
fi

mkdir -p /tmp/adore/.log/rsyslog /var/log/ros2/rsyslog

RSYSLOG_PID=""
RSYSLOG_CONFIG="/var/log/ros2/rsyslog/rsyslog.conf"
if [ -f /etc/rsyslog.conf.template ]; then
    envsubst '${UID} ${GID} ${USER} ${RSYSLOG_PORT} ${RSYSLOG_FORWARD_HOST} ${RSYSLOG_FORWARD_PORT} ${RSYSLOG_FORWARD_PROTOCOL} ${UDP_INPUT_CONFIG} ${TCP_INPUT_CONFIG}' \
        < /etc/rsyslog.conf.template > "$RSYSLOG_CONFIG" 2>/dev/null || true
    chmod 644 "$RSYSLOG_CONFIG" 2>/dev/null || true
    chown "$TARGET_UID:$TARGET_GID" "$RSYSLOG_CONFIG" 2>/dev/null || true
    touch /var/log/ros2/rsyslog/rsyslogd.log
    rsyslogd -n -f "$RSYSLOG_CONFIG" >/var/log/ros2/rsyslog/rsyslogd.log 2>&1 &
    RSYSLOG_PID=$!
    echo "Rsyslog started (PID: $RSYSLOG_PID)"
else
    echo "Warning: rsyslog template not found, skipping rsyslog"
fi

shutdown() {
    echo "Shutting down services..."
    [ -n "$RSYSLOG_PID" ] && kill "$RSYSLOG_PID" 2>/dev/null || true
    [ -n "$XVFB_PID" ]   && kill "$XVFB_PID"   2>/dev/null || true
    exit 0
}
trap shutdown TERM INT

echo "ADORe CLI ready"
[ -n "$XVFB_PID" ] && echo "Virtual display PID: $XVFB_PID"

# Activate adore venv for all processes in this container
if [ -f /opt/adore_venv/bin/activate ]; then
    source /opt/adore_venv/bin/activate
    export VIRTUAL_ENV=/opt/adore_venv
    export PATH="/opt/adore_venv/bin:$PATH"
    PYVER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    export PYTHONPATH="/opt/ros/${ROS_DISTRO}/lib/python${PYVER}/site-packages:/opt/adore_venv/lib/python${PYVER}/site-packages:${PYTHONPATH}"
fi

# Keep container alive. Interactive sessions attach via:
#   docker exec --user <uid>:<gid> -it <container> /bin/zsh
sleep infinity &
wait $!

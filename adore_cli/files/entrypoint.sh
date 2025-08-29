#!/bin/bash
set -eo pipefail
trap : TERM INT

echo "Starting ADORe CLI entrypoint..."

mkdir -p /var/log/ros2/rsyslog
chown -R ${UID:-1000}:${GID:-1000} /var/log/ros2

if [ -f /tmp/adore/setup.sh ]; then
    echo "Found setup.sh, sourcing..."
    export SHELL=/bin/bash
    (
        set +u
        source /opt/ros/${ROS_DISTRO}/setup.bash || echo "ROS setup failed"
        source /tmp/adore/setup.sh || echo "Project setup failed"
    ) || echo "Warning: Failed to source setup scripts"
else
    echo "No setup.sh found at /tmp/adore/setup.sh"
    (
        set +u
        source /opt/ros/${ROS_DISTRO}/setup.bash || echo "ROS setup failed"
    ) || echo "Warning: Failed to source ROS setup"
fi

if [ -f /tmp/adore/adore_cli.env ]; then
    echo "Loading ADORe CLI environment variables..."
    source /tmp/adore/adore_cli.env
elif [ -f /tmp/adore/.env ]; then
    echo "Loading environment variables from .env..."
    source /tmp/adore/.env
fi

echo "Starting rsyslog daemon..."
# Use consistent variable name
export RSYSLOG_PROTOCOL=${RSYSLOG_PROTOCOL:-udp}

if [ -n "${RSYSLOG_PORT:-}" ]; then
    export RSYSLOG_PORT="${RSYSLOG_PORT}"
    if [ "${RSYSLOG_PROTOCOL}" = "tcp" ]; then
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

echo "DEBUG: RSYSLOG_PORT='${RSYSLOG_PORT}'"
echo "DEBUG: RSYSLOG_PROTOCOL='${RSYSLOG_PROTOCOL}'"
echo "DEBUG: UDP_INPUT_CONFIG='${UDP_INPUT_CONFIG}'"
echo "DEBUG: TCP_INPUT_CONFIG='${TCP_INPUT_CONFIG}'"

envsubst '${UID} ${GID} ${USER} ${RSYSLOG_PORT} ${RSYSLOG_FORWARD_HOST} ${RSYSLOG_FORWARD_PORT} ${RSYSLOG_FORWARD_PROTOCOL} ${UDP_INPUT_CONFIG} ${TCP_INPUT_CONFIG}' < /etc/rsyslog.conf.template > /tmp/rsyslog.conf

chmod 644 /tmp/rsyslog.conf


sudo rsyslogd -n -f /tmp/rsyslog.conf > /var/log/ros2/rsyslog/rsyslogd.log 2>&1 &
RSYSLOG_PID=$!

shutdown() {
    echo "Shutting down rsyslog..."
    sudo kill $RSYSLOG_PID 2>/dev/null || true
    exit 0
}

trap shutdown TERM INT

echo "ADORe CLI ready"
echo "Rsyslog PID: $RSYSLOG_PID"
echo "Rsyslog logs: /var/log/ros2/rsyslog/rsyslogd.log"

wait $RSYSLOG_PID

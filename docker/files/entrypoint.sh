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

echo "Starting rsyslog daemon..."
export RSYSLOG_PORT=${RSYSLOG_PORT:-514}
export RSYSLOG_FORWARD_HOST=${RSYSLOG_FORWARD_HOST:-}
export RSYSLOG_FORWARD_PROTOCOL=${RSYSLOG_FORWARD_PROTOCOL:-udp}

envsubst '${USER} ${RSYSLOG_PORT} ${RSYSLOG_FORWARD_HOST} ${RSYSLOG_FORWARD_PROTOCOL}' < /etc/rsyslog.conf.template > /tmp/rsyslog.conf


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

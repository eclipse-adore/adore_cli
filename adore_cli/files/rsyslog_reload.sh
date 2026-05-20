#!/bin/bash
# Renders rsyslog.conf from the current environment and (re)starts rsyslogd.
# Safe to call multiple times — kills any existing rsyslogd before starting a new one.

RSYSLOG_CONFIG="/var/log/ros2/rsyslog/rsyslog.conf"
RSYSLOG_PID_FILE="/tmp/adore/.log/rsyslog/rsyslogd.pid"

[ -f /etc/rsyslog.conf.template ] || exit 0

if [ -f /tmp/adore/adore_cli.env ]; then
    set -a
    source /tmp/adore/adore_cli.env 2>/dev/null || true
    set +a
fi

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

if [ -f "$RSYSLOG_PID_FILE" ]; then
    OLD_PID=$(cat "$RSYSLOG_PID_FILE" 2>/dev/null)
    [ -n "$OLD_PID" ] && kill "$OLD_PID" 2>/dev/null || true
    rm -f "$RSYSLOG_PID_FILE"
fi

mkdir -p /tmp/adore/.log/rsyslog /var/log/ros2/rsyslog

envsubst '${USER} ${RSYSLOG_PORT} ${RSYSLOG_FORWARD_HOST} ${RSYSLOG_FORWARD_PORT} ${RSYSLOG_FORWARD_PROTOCOL} ${UDP_INPUT_CONFIG} ${TCP_INPUT_CONFIG}' \
    < /etc/rsyslog.conf.template > "$RSYSLOG_CONFIG" 2>/dev/null || true
chmod 644 "$RSYSLOG_CONFIG" 2>/dev/null || true

touch /var/log/ros2/rsyslog/rsyslogd.log
rsyslogd -n \
    -f "$RSYSLOG_CONFIG" \
    -i "$RSYSLOG_PID_FILE" \
    >>/var/log/ros2/rsyslog/rsyslogd.log 2>&1 &
RSYSLOG_PID=$!

if [ "${RSYSLOG_BANNER:-true}" = "true" ]; then
printf "\n"
printf "  ╔══════════════════════════════════════════════════╗\n"
printf "  ║              rsyslog                             ║\n"
printf "  ╠══════════════════════════════════════════════════╣\n"
printf "  ║  PID      : %-37s║\n" "$RSYSLOG_PID"
printf "  ║  Config   : %-37s║\n" "$RSYSLOG_CONFIG"
printf "  ║  Protocol : %-37s║\n" "$RSYSLOG_PROTOCOL"
if [ -n "${RSYSLOG_PORT:-}" ]; then
printf "  ║  Port     : %-37s║\n" "$RSYSLOG_PORT"
else
printf "  ║  Port     : %-37s║\n" "(disabled)"
fi
if [ -n "${RSYSLOG_FORWARD_HOST:-}" ]; then
printf "  ║  Forward  : %-37s║\n" "${RSYSLOG_FORWARD_HOST}:${RSYSLOG_FORWARD_PORT:-514} (${RSYSLOG_FORWARD_PROTOCOL:-udp})"
else
printf "  ║  Forward  : %-37s║\n" "(disabled)"
fi
printf "  ║  Log      : %-37s║\n" ".log/rsyslog/rsyslogd.log"
printf "  ╚══════════════════════════════════════════════════╝\n"
printf "\n"
fi

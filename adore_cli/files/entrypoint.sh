#!/bin/bash
trap : TERM INT

# Source setup script if it exists
if [ -f /tmp/adore/setup.sh ]; then
    echo "Found setup.sh, sourcing..."
    export SHELL=/bin/bash
    source /tmp/adore/setup.sh || echo "Warning: Failed to source setup.sh"
else
    echo "No setup.sh found at /tmp/adore/setup.sh"
fi

sudo rsyslogd -n &
sleep infinity &
wait

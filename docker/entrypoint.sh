#!/bin/bash

set -e

# Start Cron service
cron

# Keep the container running
exec tail -f /dev/null

#!/bin/bash

set -a
# shellcheck source=/dev/null
[ -f .env ] && . .env
set +a

echo "===================================="
echo " GL.iNet Firmware Monitor Test Run"
echo "===================================="
echo "Website: $WEBSITE"
echo "Dry run: $DRY_RUN"
echo "Crawl depth: $CRAWL_DEPTH"
echo "Check interval: $CHECK_INTERVAL"
echo "Log retention days: $LOG_RETENTION_DAYS"
echo

/app/monitor.sh

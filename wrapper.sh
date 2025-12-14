#!/bin/bash

set -a
[ -f .env ] && source .env
set +a

echo "===================================="
echo " GL.iNet Firmware Monitor Test Run"
echo "===================================="
echo "Website: $WEBSITE"
echo "Dry run: $DRY_RUN"
echo "Crawl depth: $CRAWL_DEPTH"
echo "Check interval: $CHECK_INTERVAL"
echo

/app/monitor.sh

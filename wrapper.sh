#!/bin/bash

export WEBSITE="https://fw.gl-inet.com"
export DISCORD_WEBHOOK="https://discord.com/api/webhooks/REPLACE_ME"

export DISCORD_TITLE="GL.iNet Firmware Monitor"
export DISCORD_PREFIX="Firmware change detected:"
export DISCORD_SUFFIX="Check compatibility before upgrading."
export DISCORD_EMOJI="📦"

export DRY_RUN=true

echo "===================================="
echo " GL.iNet Firmware Monitor Test Run"
echo "===================================="
echo "Website: $WEBSITE"
echo "Dry run: $DRY_RUN"
echo

/app/monitor.sh

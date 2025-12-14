#!/bin/bash
set -e

: "${DISCORD_WEBHOOK:?DISCORD_WEBHOOK is not set}"
: "${WEBSITE:?WEBSITE is not set}"

DRY_RUN="${DRY_RUN:-false}"

DISCORD_TITLE="${DISCORD_TITLE:-🚀 New GL.iNet Firmware Released}"
DISCORD_PREFIX="${DISCORD_PREFIX:-New firmware detected:}"
DISCORD_SUFFIX="${DISCORD_SUFFIX:-}"
DISCORD_EMOJI="${DISCORD_EMOJI:-📦}"

STATE_FILE="/data/versions.txt"
TMP_FILE="/tmp/files.txt"

touch "$STATE_FILE"

curl -s "$WEBSITE" | \
grep -oE 'href="[^"]+\.(bin|img|tar)"' | \
sed 's/href="//;s/"//' | \
sort -u > "$TMP_FILE"

declare -A STORED
declare -A CURRENT

while IFS="=" read -r model data; do
  STORED["$model"]="$data"
done < "$STATE_FILE"

MESSAGE="**$DISCORD_TITLE**\n$DISCORD_PREFIX\n\n"
POST=false

while read -r FILE; do
  if [[ "$FILE" =~ openwrt-([a-zA-Z0-9]+)-([0-9]+\.[0-9]+\.[0-9]+) ]]; then
    MODEL="${BASH_REMATCH[1]}"
    VERSION="${BASH_REMATCH[2]}"

    if [[ "$FILE" =~ [Bb][Ee][Tt][Aa] ]]; then
      CHANNEL="beta"
      LABEL="🧪 BETA"
    else
      CHANNEL="stable"
      LABEL="✅ STABLE"
    fi

    CURRENT["$MODEL"]="$VERSION:$CHANNEL"

    LAST="${STORED[$MODEL]}"
    LAST_VERSION="${LAST%%:*}"
    LAST_CHANNEL="${LAST##*:}"

    if [[ "$VERSION" != "$LAST_VERSION" || "$CHANNEL" != "$LAST_CHANNEL" ]]; then
      MESSAGE+="$DISCORD_EMOJI **$MODEL** → v$VERSION ($LABEL)\n"
      MESSAGE+="🔗 ${WEBSITE%/}/$FILE\n\n"
      POST=true
    fi
  fi
done < "$TMP_FILE"

if [ "$POST" = true ]; then
  [ -n "$DISCORD_SUFFIX" ] && MESSAGE+="\n$DISCORD_SUFFIX"

  if [ "$DRY_RUN" = true ]; then
    echo "----- DRY RUN MODE -----"
    echo "$MESSAGE"
    echo "------------------------"
  else
    curl -s -X POST \
      -H "Content-Type: application/json" \
      -d "{\"content\":\"$MESSAGE\"}" \
      "$DISCORD_WEBHOOK"
  fi

  > "$STATE_FILE"
  for MODEL in "${!CURRENT[@]}"; do
    echo "$MODEL=${CURRENT[$MODEL]}" >> "$STATE_FILE"
  done
fi

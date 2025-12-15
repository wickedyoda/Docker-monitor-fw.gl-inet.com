#!/bin/bash
set -e

: "${DISCORD_WEBHOOK:?DISCORD_WEBHOOK is not set}"
: "${WEBSITE:?WEBSITE is not set}"

DRY_RUN="${DRY_RUN:-false}"
CRAWL_DEPTH="${CRAWL_DEPTH:-5}"
LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-30}"

LOG_DIR="/data/logs"
LOG_FILE="$LOG_DIR/monitor.log"

mkdir -p "$LOG_DIR"

log() {
  local msg="$1"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$ts] $msg" | tee -a "$LOG_FILE"
}

log "Starting firmware check run"

DISCORD_TITLE="${DISCORD_TITLE:-🚀 New GL.iNet Firmware Released}"
DISCORD_PREFIX="${DISCORD_PREFIX:-New firmware detected:}"
DISCORD_SUFFIX="${DISCORD_SUFFIX:-}"
DISCORD_EMOJI="${DISCORD_EMOJI:-📦}"

STATE_FILE="/data/versions.txt"
TMP_DIR="/tmp/crawl"
mkdir -p "$TMP_DIR"

touch "$STATE_FILE"

# Clean old logs
find "$LOG_DIR" -type f -name "*.log" -mtime +"$LOG_RETENTION_DAYS" -delete
log "Old logs older than $LOG_RETENTION_DAYS days cleaned"

crawl() {
  local url="$1"
  local depth="$2"

  [ "$depth" -le 0 ] && return

  log "Crawling $url (depth $depth)"

  local safe_url
  safe_url="${url//[\/:]/_}"

  local file
  file="$TMP_DIR/${safe_url}.html"

  curl -fsS "$url" -o "$file" || return

  # Extract links without subshell recursion
  mapfile -t links < <(
    grep -oE 'href="[^"]+"' "$file" |
    sed 's/href="//;s/"//'
  )

  for link in "${links[@]}"; do
    local next

    if [[ "$link" =~ ^https?:// ]]; then
      next="$link"
    else
      next="${url%/}/$link"
    fi

    if [[ "$next" =~ \.(bin|img|tar)$ ]]; then
      echo "$next"
    elif [[ "$next" =~ /$ ]]; then
      crawl "$next" $((depth - 1))
    fi
  done
}

FIRMWARE_LIST="$TMP_DIR/firmware.txt"
: > "$FIRMWARE_LIST"

crawl "$WEBSITE" "$CRAWL_DEPTH" | sort -u > "$FIRMWARE_LIST"

log "Firmware files discovered: $(wc -l < "$FIRMWARE_LIST")"

declare -A STORED
declare -A CURRENT

while IFS="=" read -r model data; do
  STORED["$model"]="$data"
done < "$STATE_FILE"

MESSAGE="**$DISCORD_TITLE**\n$DISCORD_PREFIX\n\n"
POST=false

while read -r URL; do
  FILE="${URL##*/}"

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
      log "Detected change for $MODEL: $LAST → $VERSION ($CHANNEL)"
      MESSAGE+="$DISCORD_EMOJI **$MODEL** → v$VERSION ($LABEL)\n"
      MESSAGE+="🔗 $URL\n\n"
      POST=true
    fi
  fi
done < "$FIRMWARE_LIST"

if [ "$POST" = true ]; then
  [ -n "$DISCORD_SUFFIX" ] && MESSAGE+="\n$DISCORD_SUFFIX"

  if [ "$DRY_RUN" = true ]; then
    log "DRY_RUN enabled – message not sent"
    echo "$MESSAGE"
  else
    log "Posting update to Discord"
    curl -s -X POST \
      -H "Content-Type: application/json" \
      -d "{\"content\":\"$MESSAGE\"}" \
      "$DISCORD_WEBHOOK"
  fi

: > "$STATE_FILE"
  for MODEL in "${!CURRENT[@]}"; do
    echo "$MODEL=${CURRENT[$MODEL]}" >> "$STATE_FILE"
  done
else
  log "No firmware changes detected"
fi

log "Firmware check run completed"

#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

#######################################
# Required environment
#######################################
: "${DISCORD_WEBHOOK:?DISCORD_WEBHOOK is not set}"
: "${WEBSITE:?WEBSITE is not set}"

#######################################
# Configuration
#######################################
DRY_RUN="${DRY_RUN:-false}"
CRAWL_DEPTH="${CRAWL_DEPTH:-5}"
LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-30}"

BASE_DOMAIN="fw.gl-inet.com"

LOG_DIR="/data/logs"
LOG_FILE="$LOG_DIR/monitor.log"
STATE_FILE="/data/versions.txt"

TMP_DIR="/tmp/crawl"
VISITED_FILE="$TMP_DIR/visited.txt"

mkdir -p "$LOG_DIR" "$TMP_DIR"
touch "$STATE_FILE" "$VISITED_FILE"

#######################################
# Logging
#######################################
log() {
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$ts] $*" | tee -a "$LOG_FILE"
}

log "Starting firmware check run"

#######################################
# Log retention
#######################################
find "$LOG_DIR" -type f -name "*.log" -mtime +"$LOG_RETENTION_DAYS" -delete || true
log "Old logs older than $LOG_RETENTION_DAYS days cleaned"

#######################################
# Helpers
#######################################
already_visited() {
  grep -Fxq "$1" "$VISITED_FILE"
}

mark_visited() {
  echo "$1" >> "$VISITED_FILE"
}

safe_filename() {
  echo "${1//[\/:]/_}"
}

json_escape() {
  jq -Rs . <<<"$1"
}

#######################################
# Recursive crawler
#######################################
crawl() {
  local url="$1"
  local depth="$2"

  [[ "$depth" -le 0 ]] && return
  already_visited "$url" && return
  mark_visited "$url"

  log "Crawling $url (depth $depth)"

  local safe file
  safe="$(safe_filename "$url")"
  file="$TMP_DIR/${safe}.html"

  if ! curl -fsSL "$url" -o "$file"; then
    log "WARN: Failed to fetch $url"
    return
  fi

  mapfile -t links < <(
    grep -oiE 'href="[^"]+"' "$file" |
    sed -E 's/^href="//;s/"$//' |
    sort -u
  )

  for link in "${links[@]}"; do
    local next

    case "$link" in
      http://*|https://*)
        next="$link"
        ;;
      /*)
        next="https://${BASE_DOMAIN}${link}"
        ;;
      *)
        next="${url%/}/$link"
        ;;
    esac

    # Enforce domain pinning
    [[ "$next" != *"$BASE_DOMAIN"* ]] && continue

    if [[ "$next" =~ \.(bin|img|tar)$ ]]; then
      echo "$next"
    elif [[ "$next" =~ /$ ]]; then
      crawl "$next" $((depth - 1))
    fi
  done
}

#######################################
# Crawl execution
#######################################
FIRMWARE_LIST="$TMP_DIR/firmware.txt"
: > "$FIRMWARE_LIST"
: > "$VISITED_FILE"

crawl "$WEBSITE" "$CRAWL_DEPTH" | sort -u > "$FIRMWARE_LIST"

log "Firmware files discovered: $(wc -l < "$FIRMWARE_LIST")"

#######################################
# Load previous state
#######################################
declare -A STORED CURRENT

while IFS="=" read -r model data || [[ -n "$model" ]]; do
  [[ -n "$model" ]] && STORED["$model"]="$data"
done < "$STATE_FILE"

#######################################
# Detection logic
#######################################
DISCORD_TITLE="${DISCORD_TITLE:-🚀 New GL.iNet Firmware Released}"
DISCORD_PREFIX="${DISCORD_PREFIX:-New firmware detected:}"
DISCORD_SUFFIX="${DISCORD_SUFFIX:-}"
DISCORD_EMOJI="${DISCORD_EMOJI:-📦}"

MESSAGE="**$DISCORD_TITLE**\n$DISCORD_PREFIX\n\n"
POST=false

while read -r URL || [[ -n "$URL" ]]; do
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

    LAST="${STORED[$MODEL]:-}"
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

#######################################
# Notify & persist
#######################################
if [[ "$POST" == true ]]; then
  [[ -n "$DISCORD_SUFFIX" ]] && MESSAGE+="\n$DISCORD_SUFFIX"

  if [[ "$DRY_RUN" == true ]]; then
    log "DRY_RUN enabled – message not sent"
    echo -e "$MESSAGE"
  else
    log "Posting update to Discord"
    payload=$(json_escape "$MESSAGE")
    curl -fsS -X POST \
      -H "Content-Type: application/json" \
      -d "{\"content\":$payload}" \
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
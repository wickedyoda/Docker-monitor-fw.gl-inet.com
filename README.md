# GL.iNet Firmware Monitor

A Docker-based monitoring service that tracks new GL.iNet firmware releases and posts notifications to Discord via webhook.

This project is designed to be quiet, configurable, and safe for long-running production use.

---

## Features

- Recursive crawling of firmware directories (configurable depth)
- Version-aware deduplication (no reposts on reuploads or mirrors)
- Stable vs Beta detection based on filename
- Discord notifications via webhook
- Dry-run mode for safe testing
- Fully configurable via `.env` file
- Docker-native logging (`docker logs`)
- Persistent log files with automatic retention
- No cron jobs required

---

## How It Works

1. Crawls the configured firmware site recursively up to a defined depth
2. Discovers firmware files (`.bin`, `.img`, `.tar`)
3. Extracts model, version, and release channel (stable or beta)
4. Compares against previously recorded versions
5. Posts to Discord only if:
   - The version changes, or
   - The release channel changes (beta ↔ stable)
6. Logs all actions to container logs and a rotating log file

---

## Directory Structure

```
glinet-fw-monitor/
├── Dockerfile
├── docker-compose.yml
├── monitor.sh
├── wrapper.sh
├── .env.example
└── data/
    ├── versions.txt
    └── logs/
        └── monitor.log
```

---

## Requirements

- Docker
- Docker Compose
- Discord webhook URL

---

## Setup

### 1. Create environment file

```
cp .env.example .env
```

Edit `.env` and configure values.

---

## Environment Variables

| Variable | Description | Default |
|--------|-------------|---------|
| WEBSITE | Base firmware URL to crawl | https://fw.gl-inet.com |
| DISCORD_WEBHOOK | Discord webhook URL | required |
| DRY_RUN | Disable Discord posting | true |
| CHECK_INTERVAL | Check interval (seconds) | 21600 (6 hours) |
| CRAWL_DEPTH | Recursive crawl depth | 5 |
| LOG_RETENTION_DAYS | Log retention period | 30 |
| DISCORD_TITLE | Message title | GL.iNet Firmware Monitor |
| DISCORD_PREFIX | Text before firmware list | Firmware change detected: |
| DISCORD_SUFFIX | Text after firmware list | empty |
| DISCORD_EMOJI | Emoji per entry | 📦 |

---

## Running with Docker

```
docker compose up -d --build
```

---

## Logs

### Container logs
```
docker logs glinet-fw-monitor
```

### Persistent logs
```
./data/logs/monitor.log
```

Logs older than the configured retention period are automatically deleted.

---

## Testing Mode

By default, `DRY_RUN=true`.

In this mode:
- No Discord messages are sent
- Output is logged for verification

To force a test notification:
```
rm -f data/versions.txt
docker compose restart
```

---

## Going Live

Set the following in `.env`:
```
DRY_RUN=false
```

Restart the container:
```
docker compose restart
```

---

## Stable vs Beta Detection

- Filenames containing `beta` (case-insensitive) are classified as BETA
- All others are treated as STABLE
- Channel changes trigger notifications even if the version does not change

---

## Deduplication Logic

Notifications are sent only when:
- The firmware version changes, or
- The release channel changes

Reuploads and mirror refreshes do not trigger reposts.

---

## Copyright & Legal

All data, scripts, and related materials are Copyright © WickedYoda.

Use of this project is subject to WickedYoda’s copyright, privacy, and usage terms.

The official Copyright and Privacy Notice can be found here:
https://wickedyoda.com/?page_id=3

Unauthorized redistribution, reuse, or modification outside the scope of the published terms is not permitted.

---

## License

Refer to WickedYoda’s copyright and privacy notice for licensing and usage terms.

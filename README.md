# GL.iNet Firmware Monitor (Docker)

A Docker-based service that monitors the GL.iNet firmware repository for new firmware releases and posts notifications to Discord via webhook.

This project is designed to be quiet, configurable, and safe for continuous operation, with automated container publishing and retention management.

---

## Features

- Recursive crawling of firmware directories with configurable depth
- Monitors firmware files (.bin, .img, .tar)
- Prevents duplicate notifications unless version or channel changes
- Detects stable vs beta firmware based on filename
- Discord notifications via webhook
- Dry-run mode for safe testing
- Persistent state tracking
- Full logging to container logs and rotating log files
- Automated Docker image publishing to GitHub Container Registry
- Automatic pruning of old container images (90-day retention)

---

## How It Works

1. Crawls the configured firmware URL recursively up to the configured depth
2. Discovers firmware files and extracts model, version, and channel
3. Compares results against the last recorded state
4. Posts to Discord only when a change is detected
5. Logs all actions for auditing and troubleshooting

---

## Directory Structure

```
.
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

## Environment Variables

| Variable | Description | Default |
|--------|------------|---------|
| WEBSITE | Base firmware URL | https://fw.gl-inet.com/firmware/ |
| DISCORD_WEBHOOK | Discord webhook URL | required |
| DRY_RUN | Disable Discord posting | true |
| CHECK_INTERVAL | Check interval (seconds) | 10800 (3 hours) |
| CRAWL_DEPTH | Recursive crawl depth | 5 |
| LOG_RETENTION_DAYS | Log retention period | 30 |
| DISCORD_TITLE | Discord message title | GL.iNet Firmware Monitor |
| DISCORD_PREFIX | Message prefix | Firmware change detected |
| DISCORD_SUFFIX | Message suffix | empty |
| DISCORD_EMOJI | Entry emoji | 📦 |

---

## Running with Docker Compose

```
docker compose up -d
```

---

## Logs

### Container Logs
```
docker logs glinet-fw-monitor
```

### Persistent Logs
```
./data/logs/monitor.log
```

Logs older than the configured retention period are automatically removed.

---

## Testing Mode

By default, the monitor runs in dry-run mode.

DRY_RUN=true

This allows you to verify crawling, detection, and message formatting without sending Discord notifications.

---

## Going Live

Set the following in .env:

DRY_RUN=false

Restart the container:

docker compose restart

---

## Docker Image

Images are automatically built and published on every push to the main branch.

Tags published:
- latest
- Date-based tag (YYYYMMDD)

Example:
ghcr.io/wickedyoda/docker-monitor-fw.gl-inet.com:latest
ghcr.io/wickedyoda/docker-monitor-fw.gl-inet.com:20251215

Old images older than 90 days are automatically pruned.

---

## Security Notes

- Do not commit your .env file
- Rotate Discord webhooks if exposed
- Access to firmware data is read-only
- No reverse engineering or firmware modification is performed

---

## Copyright & Legal

All data, scripts, and related materials are Copyright © WickedYoda.

Use of this project is subject to WickedYoda’s copyright and privacy terms.

Copyright and Privacy Notice:
https://wickedyoda.com/?page_id=3

---

## License

Refer to the WickedYoda Copyright and Privacy Notice for licensing and usage terms.

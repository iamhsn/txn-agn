#!/usr/bin/env bash
# Weekly: remove unused Docker images and old journal logs so the disk never fills.
set -euo pipefail
. /opt/txn-agn/scripts/lib.sh
before=$(df --output=pcent / | tail -1 | tr -dc 0-9)
docker image prune -af --filter "until=168h" >/dev/null
docker builder prune -af >/dev/null 2>&1 || true
journalctl --vacuum-time=14d >/dev/null
after=$(df --output=pcent / | tail -1 | tr -dc 0-9)
echo "Disk: ${before}% -> ${after}%"
(( after < 80 )) || telegram "Disk at ${after}% after weekly cleanup; needs a look."

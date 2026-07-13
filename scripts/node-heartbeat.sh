#!/bin/bash

# node-heartbeat.sh
# Writes a health snapshot to a known location every 60 seconds.
# This is the Linux implementation of the node agent defined in ADR-003.
#
# Usage:
#   Run once:    ./node-heartbeat.sh
#   Run as loop: while true; do ./node-heartbeat.sh; sleep 60; done
#
# Install as cron (every minute):
#   * * * * * /path/to/node-heartbeat.sh

set -euo pipefail

OUTPUT_DIR="${COMMODITYCLOUD_STATUS_DIR:-/var/lib/commoditycloud}"
OUTPUT_FILE="$OUTPUT_DIR/node-status.json"
WORKLOAD_FILE="$OUTPUT_DIR/active-workload"

# Allow running without root by writing to local dir
if [ ! -w "$(dirname "$OUTPUT_FILE")" ] 2>/dev/null; then
    OUTPUT_DIR="${HOME}/.commoditycloud"
    OUTPUT_FILE="$OUTPUT_DIR/node-status.json"
    WORKLOAD_FILE="$OUTPUT_DIR/active-workload"
fi

mkdir -p "$OUTPUT_DIR"

# --- Detect node identity ---
NODE_ID=$(hostname -s)

# --- Detect uptime ---
if [[ "$(uname)" == "Darwin" ]]; then
    # macOS
    BOOT_TIME=$(sysctl -n kern.boottime | awk '{print $4}' | tr -d ',')
    UPTIME_SECONDS=$(( $(date +%s) - BOOT_TIME ))
else
    # Linux
    UPTIME_SECONDS=$(awk '{print int($1)}' /proc/uptime)
fi

# --- Detect RAM ---
if [[ "$(uname)" == "Darwin" ]]; then
    TOTAL_MEM=$(sysctl -n hw.memsize)
    PAGE_SIZE=$(sysctl -n hw.pagesize)
    FREE_PAGES=$(vm_stat | awk '/Pages free/ {print $3}' | tr -d '.')
    RAM_FREE_MB=$(( (FREE_PAGES * PAGE_SIZE) / 1024 / 1024 ))
else
    RAM_FREE_MB=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
fi

# --- Detect storage ---
if [[ "$(uname)" == "Darwin" ]]; then
    STORAGE_FREE_GB=$(df -g "$OUTPUT_DIR" | awk 'NR==2 {print $4}')
else
    STORAGE_FREE_GB=$(df -BG "$OUTPUT_DIR" | awk 'NR==2 {gsub("G",""); print $4}')
fi

# --- Detect active workload ---
WORKLOAD="none"
WORKLOAD_STATUS="idle"
if [ -f "$WORKLOAD_FILE" ]; then
    WORKLOAD=$(cat "$WORKLOAD_FILE")
    WORKLOAD_STATUS="running"
fi

# --- Write snapshot ---
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "$OUTPUT_FILE" <<EOF
{
  "node_id": "$NODE_ID",
  "timestamp": "$TIMESTAMP",
  "uptime_seconds": $UPTIME_SECONDS,
  "workload": "$WORKLOAD",
  "workload_status": "$WORKLOAD_STATUS",
  "resources": {
    "ram_free_mb": $RAM_FREE_MB,
    "storage_free_gb": $STORAGE_FREE_GB
  }
}
EOF

echo "✅ Status written to $OUTPUT_FILE"
cat "$OUTPUT_FILE"

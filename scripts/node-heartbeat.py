#!/usr/bin/env python3
"""
node-heartbeat.py
Writes a health snapshot (node-status.json) to a known location.
This is the cross-platform implementation of the node agent defined in ADR-003.

Supported platforms: Linux, macOS, Windows, Android (via Termux)

Usage:
    Run once:      python3 node-heartbeat.py
    Run as loop:   while true; do python3 node-heartbeat.py; sleep 60; done
    Windows loop:  for /L %i in (1,0,2) do python node-heartbeat.py && timeout 60

No third-party dependencies. Uses Python stdlib only.
"""

import json
import os
import platform
import shutil
import socket
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------

def detect_platform() -> str:
    system = platform.system()
    if system == "Darwin":
        return "macos"
    if system == "Linux":
        # Termux (Android) exposes $PREFIX
        if os.environ.get("PREFIX", "").startswith("/data/data/com.termux"):
            return "android-termux"
        return "linux"
    if system == "Windows":
        return "windows"
    return "unknown"


# ---------------------------------------------------------------------------
# Output directory (platform-appropriate, no root required)
# ---------------------------------------------------------------------------

def resolve_output_dir() -> Path:
    env_override = os.environ.get("COMMODITYCLOUD_STATUS_DIR")
    if env_override:
        return Path(env_override)

    system = platform.system()
    if system == "Windows":
        base = Path(os.environ.get("LOCALAPPDATA", Path.home()))
        return base / "CommodityCloud"
    # macOS, Linux, Termux
    return Path.home() / ".commoditycloud"


# ---------------------------------------------------------------------------
# Resource detection (stdlib only — no psutil)
# ---------------------------------------------------------------------------

def get_uptime_seconds() -> int:
    system = platform.system()
    try:
        if system == "Linux":
            with open("/proc/uptime") as f:
                return int(float(f.read().split()[0]))
        if system == "Darwin":
            # sysctl kern.boottime returns seconds since epoch
            import subprocess
            out = subprocess.check_output(["sysctl", "-n", "kern.boottime"], text=True)
            # format: "{ sec = 1720000000, usec = 0 } Sun Jul 13 ..."
            boot_sec = int(out.split("sec =")[1].split(",")[0].strip())
            return int(time.time()) - boot_sec
        if system == "Windows":
            import subprocess
            out = subprocess.check_output(
                ["wmic", "os", "get", "LastBootUpTime"], text=True
            )
            # format: 20260713041200.123456+000
            raw = out.strip().splitlines()[-1].strip()
            boot_dt = datetime.strptime(raw[:14], "%Y%m%d%H%M%S").replace(
                tzinfo=timezone.utc
            )
            return int(time.time() - boot_dt.timestamp())
    except Exception:
        pass
    return -1


def get_ram_free_mb() -> int:
    system = platform.system()
    try:
        if system == "Linux":
            with open("/proc/meminfo") as f:
                for line in f:
                    if line.startswith("MemAvailable:"):
                        return int(line.split()[1]) // 1024
        if system == "Darwin":
            import subprocess
            page_size = int(
                subprocess.check_output(["sysctl", "-n", "hw.pagesize"], text=True).strip()
            )
            vm_stat = subprocess.check_output(["vm_stat"], text=True)
            # macOS memory model: "available" = free + inactive + speculative + purgeable
            # "Pages free" alone (~500MB) understates available memory by 10x.
            # Activity Monitor's "Available Memory" uses this broader definition.
            reclaimable_labels = ("Pages free", "Pages inactive", "Pages speculative", "Pages purgeable")
            total_reclaimable = 0
            for line in vm_stat.splitlines():
                if any(line.startswith(label) for label in reclaimable_labels):
                    pages = int(line.split(":")[1].strip().rstrip("."))
                    total_reclaimable += pages
            if total_reclaimable > 0:
                return (total_reclaimable * page_size) // (1024 * 1024)
        if system == "Windows":
            import subprocess
            out = subprocess.check_output(
                ["wmic", "os", "get", "FreePhysicalMemory"], text=True
            )
            kb = int(out.strip().splitlines()[-1].strip())
            return kb // 1024
    except Exception:
        pass
    return -1


def get_storage_free_gb(path: Path) -> int:
    try:
        usage = shutil.disk_usage(str(path))
        return usage.free // (1024 ** 3)
    except Exception:
        return -1


def get_active_workload(workload_file: Path) -> tuple[str, str]:
    try:
        if workload_file.exists():
            return workload_file.read_text().strip(), "running"
    except Exception:
        pass
    return "none", "idle"


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    output_dir = resolve_output_dir()
    output_dir.mkdir(parents=True, exist_ok=True)

    output_file = output_dir / "node-status.json"
    workload_file = output_dir / "active-workload"

    node_id = socket.gethostname().split(".")[0]
    detected_platform = detect_platform()
    uptime = get_uptime_seconds()
    ram_free = get_ram_free_mb()
    storage_free = get_storage_free_gb(output_dir)
    workload, workload_status = get_active_workload(workload_file)
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    snapshot = {
        "node_id": node_id,
        "platform": detected_platform,
        "timestamp": timestamp,
        "uptime_seconds": uptime,
        "workload": workload,
        "workload_status": workload_status,
        "resources": {
            "ram_free_mb": ram_free,
            "storage_free_gb": storage_free,
        },
    }

    output_file.write_text(json.dumps(snapshot, indent=2))
    print(f"✅  Status written to {output_file}")
    print(json.dumps(snapshot, indent=2))


if __name__ == "__main__":
    main()

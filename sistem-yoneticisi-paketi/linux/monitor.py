#!/usr/bin/env python3
"""Sistem Yöneticisi Paketi — Linux CLI monitör (psutil)."""

from __future__ import annotations

import argparse
import json
import time

try:
    import psutil
except ImportError:
    print("psutil gerekli: pip install -r requirements.txt")
    raise SystemExit(1)


def fmt_bytes(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024:
            return f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} PB"


def collect_dashboard() -> dict:
    cpu = psutil.cpu_percent(interval=0.5)
    mem = psutil.virtual_memory()
    net = psutil.net_io_counters()
    disks = []
    for part in psutil.disk_partitions(all=False):
        try:
            usage = psutil.disk_usage(part.mountpoint)
        except PermissionError:
            continue
        disks.append(
            {
                "mount": part.mountpoint,
                "percent": usage.percent,
                "used_bytes": usage.used,
                "total_bytes": usage.total,
            }
        )
    return {
        "cpu_percent": cpu,
        "ram_percent": mem.percent,
        "ram_used_bytes": mem.used,
        "ram_total_bytes": mem.total,
        "network": {"bytes_recv": net.bytes_recv, "bytes_sent": net.bytes_sent},
        "disks": disks,
    }


def dashboard_once(as_json: bool = False) -> None:
    data = collect_dashboard()
    if as_json:
        print(json.dumps(data, indent=2))
        return

    print(f"CPU: {data['cpu_percent']:.1f}%")
    print(
        f"RAM: {data['ram_percent']:.1f}% "
        f"({fmt_bytes(data['ram_used_bytes'])} / {fmt_bytes(data['ram_total_bytes'])})"
    )
    net = data["network"]
    print(f"Ağ (toplam): ↓ {fmt_bytes(net['bytes_recv'])}  ↑ {fmt_bytes(net['bytes_sent'])}")
    print("\nDisk:")
    for disk in data["disks"]:
        print(
            f"  {disk['mount']}: {disk['percent']:.1f}% "
            f"({fmt_bytes(disk['used_bytes'])} / {fmt_bytes(disk['total_bytes'])})"
        )


def watch(interval: float, as_json: bool) -> None:
    try:
        while True:
            if not as_json:
                print("\033[2J\033[H", end="")
                print("Sistem Yöneticisi Paketi — Linux CLI\n")
            dashboard_once(as_json=as_json)
            if not as_json:
                print(f"\n(Yenileme: {interval}s — Ctrl+C ile çık)")
            time.sleep(interval)
    except KeyboardInterrupt:
        if not as_json:
            print("\nÇıkıldı.")


def collect_processes(limit: int) -> list[dict]:
    rows = []
    # psutil'de süreç cpu_percent ilk çağrıda hep 0.0 döner: önce ölçümü başlat,
    # kısa bekle, sonra aradaki farkı oku.
    procs = list(psutil.process_iter(["pid", "name", "memory_info"]))
    for proc in procs:
        try:
            proc.cpu_percent(None)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    time.sleep(0.5)
    for proc in procs:
        try:
            info = proc.info
            mem_mb = (info["memory_info"].rss if info.get("memory_info") else 0) / (1024 * 1024)
            rows.append(
                {
                    "pid": info["pid"],
                    "name": info.get("name") or "?",
                    "cpu_percent": proc.cpu_percent(None),
                    "memory_mb": round(mem_mb, 1),
                }
            )
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    rows.sort(key=lambda r: r["cpu_percent"], reverse=True)
    return rows[:limit]


def list_processes(limit: int, as_json: bool = False) -> None:
    rows = collect_processes(limit)
    if as_json:
        print(json.dumps(rows, indent=2))
        return

    print(f"{'PID':>8}  {'CPU%':>6}  {'MEM MB':>8}  NAME")
    print("-" * 48)
    for row in rows:
        print(f"{row['pid']:8d}  {row['cpu_percent']:6.1f}  {row['memory_mb']:8.1f}  {row['name']}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Linux sistem monitörü")
    parser.add_argument("command", nargs="?", choices=["dashboard", "processes", "watch"], default="dashboard")
    parser.add_argument("--interval", type=float, default=2.0, help="watch modu yenileme süresi")
    parser.add_argument("--limit", type=int, default=25, help="processes modu satır sayısı")
    parser.add_argument("--json", action="store_true", help="JSON çıktı (script entegrasyonu)")
    args = parser.parse_args()

    if args.command == "dashboard":
        dashboard_once(as_json=args.json)
    elif args.command == "watch":
        watch(args.interval, args.json)
    elif args.command == "processes":
        list_processes(args.limit, as_json=args.json)


if __name__ == "__main__":
    main()

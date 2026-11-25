#!/bin/bash
set -u
out=/var/tmp/sre-lab-soak
mkdir -p "$out"
vmstat -n -t 30 61 > "$out/vmstat.txt" &
vmstat_pid=$!
trap 'kill "$vmstat_pid" 2>/dev/null || true' EXIT
for ((i=0; i<=60; i++)); do
  {
    date -u +'%FT%TZ'
    pid=$(systemctl show k3s -p MainPID --value)
    printf 'pid=%s ' "$pid"
    if [[ "$pid" != 0 && -r /proc/$pid/status ]]; then awk '/^VmRSS:/{printf "rss_kib=%s ",$2}' "/proc/$pid/status"; fi
    printf 'current_bytes='; cat /sys/fs/cgroup/system.slice/k3s.service/memory.current 2>/dev/null || true
    printf 'events '; tr '\n' ' ' < /sys/fs/cgroup/system.slice/k3s.service/memory.events 2>/dev/null || true; printf '\n'
    printf 'psi '; tr '\n' ' ' < /proc/pressure/memory; printf '\n'
    awk '/^(MemAvailable|SwapTotal|SwapFree):/{printf "%s%s ",$1,$2} END{print ""}' /proc/meminfo
  } >> "$out/samples.txt"
  (( i == 60 )) || sleep 30
done
wait "$vmstat_pid"

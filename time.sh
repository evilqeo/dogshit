#!/bin/bash
set -euo pipefail

echo "[1] Killing miner processes immediately..."
pkill -9 -f xmr_linux_ 2>/dev/null || true
pkill -9 -f "node index.js" 2>/dev/null || true
pkill -9 -f check.sh 2>/dev/null || true

echo "[2] Locating s6 scan directory (supervision root)..."
S6_SCAN_ROOTS=("/etc/service" "/service" "/var/run/s6" "/var/service")
scan_root=""
for dir in "${S6_SCAN_ROOTS[@]}"; do
  if [ -d "$dir" ]; then
    scan_root="$dir"
    break
  fi
done

if [ -z "$scan_root" ]; then
  echo "  — No s6 scan directory found in common paths."
else
  echo "  — Found scan directory: $scan_root"
  echo "[3] Using s6-svscanctl to reload and prune services..."
  s6-svscanctl -hn "$scan_root" || echo "Error or no permission for s6-svscanctl"
  
  echo "[4] Identifying service directories running the miner..."
  for svc_dir in "$scan_root"/*; do
    if grep -qE 'xmr_linux_|node index.js|check.sh|minio.daviduwu.ovh' "$svc_dir/run" 2>/dev/null; then
      echo "    • Found miner service: $svc_dir"
      echo "    — Stopping service with s6-svunlink..."
      s6-svunlink -t 5000 "$scan_root" "$(basename "$svc_dir")" || true
      mv "$svc_dir" "$svc_dir.disabled.$(date +%s)" || true
    fi
  done
fi

echo "[5] Removing residual files..."
rm -f /root/xmr_linux_* /tmp/xmr_linux_* /config/xmr_linux_* /config/check.sh /usr/local/lib/sshdd.so /tmp/nginx /tmp/sleeping /start.bat /5.bat 2>/dev/null
find / -type f \( -name 'xmr_linux_*' -o -name 'check.sh' -o -name '*.bat' \) -exec rm -f {} \; 2>/dev/null || true

echo "[6] Cleaning cron jobs..."
for user in $(cut -f1 -d: /etc/passwd); do
  crontab -u "$user" -l 2>/dev/null | grep -vE 'xmr_linux_|check.sh|minio.daviduwu.ovh' | crontab -u "$user" -
done
sed -i '/xmr_linux_\|check.sh\|minio.daviduwu.ovh/d' /etc/crontab /etc/cron.*/* 2>/dev/null || true

echo "[7] Cleanup complete. Reboot recommended."
exit 0

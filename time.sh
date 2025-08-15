#!/bin/bash
set -euo pipefail

echo "[*] Starting deep cleanup of persistent miner..."

# 1. Kill all known malicious processes
echo "[*] Killing all miner-related processes..."
for p in $(pgrep -f -d ' ' 'xmr_linux_|check.sh|node index.js|vncc|tmate|sosal123|seized|/tmp/nginx|/tmp/sleeping|start.bat|5.bat'); do
    echo "Killing PID $p"
    kill -9 "$p" || true
done

# 2. Find and disable s6 services related to miner
echo "[*] Disabling s6 supervision services..."
S6_PATHS=(
  /etc/service
  /service
  /var/run/s6
  /var/service
)

for path in "${S6_PATHS[@]}"; do
  if [ -d "$path" ]; then
    for svc in "$path"/*; do
      if grep -qE 'xmr_linux_|node index.js|check.sh' "$svc"/run 2>/dev/null; then
        echo "Disabling s6 service: $svc"
        s6-svc -d "$svc" 2>/dev/null || true
        mv "$svc" "${svc}.disabled.$(date +%s)" || true
      fi
    done
  fi
done

# 3. Remove malware files
echo "[*] Removing malicious files..."
FILES_TO_REMOVE=(
  /root/xmr_linux_*
  /tmp/xmr_linux_*
  /config/xmr_linux_*
  /config/check.sh
  /config/start
  /root/check.sh
  /usr/local/lib/sshdd.so
  /tmp/nginx
  /tmp/sleeping
  /start.bat
  /5.bat
)
for f in "${FILES_TO_REMOVE[@]}"; do
  rm -f $f 2>/dev/null || true
done

# Also find anywhere else these files might hide
find / -type f \( -name 'xmr_linux_*' -o -name 'check.sh' -o -name '*.bat' \) -exec rm -f {} \; 2>/dev/null || true

# 4. Clean cron jobs for all users
echo "[*] Cleaning user cronjobs..."
for user in $(cut -f1 -d: /etc/passwd); do
  crontab -u "$user" -l 2>/dev/null | grep -vE 'xmr_linux_|check.sh|node index.js|minio.daviduwu.ovh' | crontab -u "$user" -
done

# Remove system-wide cron entries
sed -i '/xmr_linux_\|check.sh\|node index.js/d' /etc/crontab /etc/cron.*/* 2>/dev/null || true

# 5. Check and clear startup scripts
echo "[*] Removing miner from startup scripts..."
STARTUP_FILES=(
  /etc/rc.local
  /etc/init.d/miner*
  /etc/systemd/system/miner.service
  /etc/systemd/system/xmr.service
  ~/.bashrc
  ~/.profile
)

for file in "${STARTUP_FILES[@]}"; do
  if [ -f "$file" ]; then
    sed -i '/xmr_linux_\|check.sh\|node index.js/d' "$file"
    echo "Cleaned $file"
  fi
done

# 6. Disable suspicious aliases or functions
unalias -a || true

echo "[*] Cleanup done. Please reboot your system."

echo "[*] Monitoring for miner processes in next 60s..."
for i in {1..12}; do
  sleep 5
  if pgrep -f 'xmr_linux_' >/dev/null || pgrep -f 'check.sh' >/dev/null || pgrep -f 'node index.js' >/dev/null; then
    echo "[!] Miner process detected still running after cleanup attempt!"
    echo "Run this script again or investigate deeper."
    exit 1
  fi
done

echo "[*] No miner processes detected. System clean!"
exit 0

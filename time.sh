#!/bin/bash
set -e

echo "[*] Killing miner and related processes..."
pkill -9 -f xmr_linux_ 2>/dev/null || true
pkill -9 -f vncc 2>/dev/null || true
pkill -9 -f tmate 2>/dev/null || true
pkill -9 -f sosal123 2>/dev/null || true
pkill -9 -f seized 2>/dev/null || true
pkill -9 -f /tmp/nginx 2>/dev/null || true
pkill -9 -f /tmp/sleeping 2>/dev/null || true
pkill -9 -f start.bat 2>/dev/null || true
pkill -9 -f 5.bat 2>/dev/null || true
pkill -9 -f check.sh 2>/dev/null || true
pkill -9 -f 'node index.js' 2>/dev/null || true

echo "[*] Removing known malware files..."
rm -f /root/xmr_linux_*
rm -f /tmp/xmr_linux_*
rm -f /config/xmr_linux_*
rm -f /config/check.sh
rm -f /config/start
rm -f /root/check.sh
rm -f /usr/local/lib/sshdd.so
rm -f /tmp/nginx
rm -f /tmp/sleeping
rm -f /start.bat
rm -f /5.bat

echo "[*] Disabling miner auto-restart scripts..."

# Find and disable any scripts named check.sh, start.bat, 5.bat in common locations
for script in /config/check.sh /config/start /root/check.sh /start.bat /5.bat; do
    if [ -f "$script" ]; then
        mv "$script" "$script.disabled.$(date +%s)" && echo "Disabled $script"
    fi
done

echo "[*] Cleaning cron jobs for all users..."

for user in $(cut -f1 -d: /etc/passwd); do
    crontab -u "$user" -l 2>/dev/null | grep -vE 'xmr_linux_|check.sh|node index.js|minio.daviduwu.ovh' | crontab -u "$user" -
done

echo "[*] Removing suspicious downloads from minio.daviduwu.ovh..."

find / -type f -name 'xmr_linux_*' -o -name 'check.sh' -o -name '*.bat' 2>/dev/null | while read -r file; do
    grep -q 'minio.daviduwu.ovh' "$file" && rm -f "$file" && echo "Deleted $file"
done

echo "[*] Cleanup complete. Please reboot your system and monitor."


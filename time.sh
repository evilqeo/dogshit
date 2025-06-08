#!/bin/bash

echo "[*] Starting full crypto miner cleanup..."

# 1. Kill known miner and Node.js launcher processes
echo "[*] Killing miner and node processes..."
pkill -9 -f 'node index.js' 2>/dev/null
pkill -9 -f 'xmr_linux_amd6' 2>/dev/null
pkill -9 -f 'xmrig' 2>/dev/null

# 2. Remove miner binaries and directories
echo "[*] Removing miner files..."
rm -rf /root/xmr_linux_amd644
rm -rf /tmp/xmrig

# 3. Remove Node.js launcher scripts
echo "[*] Searching and removing suspicious index.js scripts..."
find / -type f -name "index.js" -exec grep -q 'xmr_linux_amd644\|xmrig' {} \; -exec rm -f {} \; 2>/dev/null

# 4. Scan for .js files linked to miners
echo "[*] Scanning for .js files that reference miner binaries..."
find / -type f -name "*.js" 2>/dev/null | while read jsfile; do
    if grep -q 'xmr_linux_amd644\|xmrig' "$jsfile"; then
        echo "    [!] Removing suspicious script: $jsfile"
        rm -f "$jsfile"
    fi
done

# 5. Remove persistence from root's crontab
echo "[*] Cleaning root crontab entries..."
crontab -l 2>/dev/null | grep -vE 'xmr_linux_amd644|xmrig|node index.js' | crontab - 2>/dev/null

# 6. Clean root's shell startup files
echo "[*] Cleaning root's bash/profile files..."
for file in /root/.bashrc /root/.profile; do
    if [ -f "$file" ]; then
        sed -i '/xmr_linux_amd644/d' "$file"
        sed -i '/node index.js/d' "$file"
    fi
done

# 7. Check and remove systemd services
echo "[*] Searching systemd for malicious miner services..."
grep -rlE 'node index.js|xmr_linux_amd644|xmrig' /etc/systemd/system 2>/dev/null | while read service_file; do
    svc_name=$(basename "$service_file" | sed 's/.service$//')
    echo "    [*] Disabling and removing service: $svc_name"
    systemctl disable "$svc_name" 2>/dev/null
    rm -f "$service_file"
done

# Reload systemd
systemctl daemon-reexec
systemctl daemon-reload

# 8. Final status check
echo "[*] Verifying cleanup..."
if pgrep -f 'node index.js\|xmr_linux_amd6\|xmrig' > /dev/null; then
    echo "[!] Warning: Some miner processes are still running!"
else
    echo "[+] Success: No miner processes found."
fi

if [ -f /root/xmr_linux_amd644 ] || [ -d /tmp/xmrig ]; then
    echo "[!] Warning: Some miner files still exist!"
else
    echo "[+] Success: All miner files removed."
fi

echo "[*] Crypto miner cleanup completed."

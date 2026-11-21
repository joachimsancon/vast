#!/bin/bash
# Installs pearl-idle-miner. Run as root:  sudo ./install.sh
set -euo pipefail
cd "$(dirname "$0")"
[ "$(id -u)" = 0 ] || { echo "Run as root (sudo ./install.sh)"; exit 1; }
for c in docker nvidia-smi curl sha256sum runuser pkill; do
  command -v "$c" >/dev/null || { echo "Missing dependency: $c"; exit 1; }
done
id pearlminer >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin pearlminer
install -m 755 pearl-idle-miner /usr/local/sbin/pearl-idle-miner
install -m 644 pearl-idle-miner.service /etc/systemd/system/pearl-idle-miner.service
if [ ! -f /etc/pearl-idle-miner.conf ]; then
  install -m 644 pearl-idle-miner.conf.example /etc/pearl-idle-miner.conf
  echo "Created /etc/pearl-idle-miner.conf – set WALLET there, then run:"
  echo "  sudo systemctl enable --now pearl-idle-miner"
else
  echo "Keeping existing /etc/pearl-idle-miner.conf"
  systemctl daemon-reload
  systemctl restart pearl-idle-miner 2>/dev/null || true
fi
systemctl daemon-reload
echo "Logs:  tail -F /var/log/srbminer-gpu0.log   |   journalctl -t pearl-idle-miner -f"

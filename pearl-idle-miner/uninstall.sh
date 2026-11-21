#!/bin/bash
# Removes pearl-idle-miner (keeps /etc/pearl-idle-miner.conf). Run as root.
set -u
systemctl disable --now pearl-idle-miner 2>/dev/null
pkill -KILL -x SRBMiner-MULTI 2>/dev/null
nvidia-smi -rgc >/dev/null 2>&1; nvidia-smi -rmc >/dev/null 2>&1
rm -f /usr/local/sbin/pearl-idle-miner /etc/systemd/system/pearl-idle-miner.service
systemctl daemon-reload
echo "Removed. Config kept in /etc/pearl-idle-miner.conf, miner binaries in /opt/srbminer (delete if you like)."

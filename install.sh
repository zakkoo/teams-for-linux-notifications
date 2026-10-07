#!/bin/bash
# install.sh <source-dir-name>   → run that source as a user service (meeting-alert.service), restart on crash
# install.sh --remove            → stop and remove the service
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
unit=~/.config/systemd/user/meeting-alert.service
if [[ ${1:-} == --remove ]]; then
  systemctl --user disable --now meeting-alert.service 2>/dev/null || true
  rm -f "$unit"; systemctl --user daemon-reload; echo removed; exit 0
fi
src=${1:?usage: install.sh <source-dir-name> | --remove}
[[ -x $ROOT/sources/$src/start ]] || { echo "no sources/$src/start"; exit 1; }
mkdir -p "$(dirname "$unit")"
cat >"$unit" <<UNIT
[Unit]
Description=Meeting alert ($src)
After=graphical-session.target

[Service]
ExecStart=$ROOT/sources/$src/start
EnvironmentFile=-$ROOT/config.env
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
UNIT
systemctl --user daemon-reload
systemctl --user enable --now meeting-alert.service
echo "running $src — logs: journalctl --user -fu meeting-alert"

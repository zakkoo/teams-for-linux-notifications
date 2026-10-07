#!/bin/bash
# The one place every source ends up. Swap the body for your own "prominent colored thing".
# usage: alert.sh <title> [body] [join-url]
set -uo pipefail
title=$1 body=${2:-} url=${3:-}
mkdir -p ~/.local/state && echo "$(date -Is) $title | $body | $url" >>~/.local/state/meeting-alert.log

args=(-u critical -g 󰍹 --app-name meeting-alert -t 0 "$title" "$body")
[[ -n $url ]] && args+=(--exec xdg-open "$url")
omarchy-notification-send "${args[@]}"

# Red window borders for 60s, then restore from config.
export HYPRLAND_INSTANCE_SIGNATURE=${HYPRLAND_INSTANCE_SIGNATURE:-$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr" 2>/dev/null | head -1)}
hyprctl keyword general:col.active_border 'rgb(ff2020)' >/dev/null 2>&1 &&
  (sleep 60; hyprctl reload >/dev/null 2>&1) &

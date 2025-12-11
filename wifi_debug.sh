#!/usr/bin/env zsh
# Usage:
#   USB mode phone:   ./wifi_debug.sh connect <DEVICE_IP> [flutter_target]
#   Wireless pairing: ./wifi_debug.sh pair <PAIR_IP:PORT> <PAIR_CODE> <DEVICE_IP:PORT> [flutter_target]
# Examples:
#   ./wifi_debug.sh connect 192.168.178.139 lib/main.dart
#   ./wifi_debug.sh pair 192.168.178.139:37169 123456 192.168.178.139:44825 lib/main.dart

set -euo pipefail

cmd="${1:-}"
if [[ -z "$cmd" ]]; then
  echo "Usage:"
  echo "  $0 connect <DEVICE_IP> [flutter_target]"
  echo "  $0 pair <PAIR_IP:PORT> <PAIR_CODE> <DEVICE_IP:PORT> [flutter_target]"
  exit 1
fi

run_flutter() {
  local device="$1"
  local target="${2:-lib/main.dart}"
  echo "Launching Flutter on $device..."
  flutter run -d "$device" --target "$target" --debug
}

restart_adb() {
  echo "Restarting adb..."
  adb kill-server >/dev/null 2>&1 || true
  adb start-server
}

if [[ "$cmd" == "connect" ]]; then
  DEVICE_IP="${2:-}"
  TARGET="${3:-lib/main.dart}"
  if [[ -z "$DEVICE_IP" ]]; then
    echo "Need <DEVICE_IP>"
    exit 1
  fi

  echo "Pinging $DEVICE_IP..."
  if ! ping -c 1 -W 2 "$DEVICE_IP" >/dev/null 2>&1; then
    echo "Ping failed (ICMP may be blocked); continuing to try adb connect."
  fi

  restart_adb
  echo "Switching ADB to TCP on port 5555 (USB must be connected)..."
  adb tcpip 5555

  echo "Connecting to $DEVICE_IP:5555..."
  if ! adb connect "$DEVICE_IP:5555"; then
    echo "Connect failed; retrying once after restart..."
    restart_adb
    adb connect "$DEVICE_IP:5555"
  fi

  echo "Devices now:"
  adb devices
  run_flutter "$DEVICE_IP:5555" "$TARGET"
  exit 0
fi

if [[ "$cmd" == "pair" ]]; then
  PAIR_ADDR="${2:-}"   # e.g., 192.168.1.42:37169 from phone pairing screen
  PAIR_CODE="${3:-}"   # 6-digit code
  DEVICE_ADDR="${4:-}" # e.g., 192.168.1.42:44825 (the “Connect to device” address)
  TARGET="${5:-lib/main.dart}"

  if [[ -z "$PAIR_ADDR" || -z "$PAIR_CODE" || -z "$DEVICE_ADDR" ]]; then
    echo "Need <PAIR_IP:PORT> <PAIR_CODE> <DEVICE_IP:PORT>"
    exit 1
  fi

  # Older platform-tools don't support 'adb pair'. Detect and fail fast with guidance.
  if ! adb --help 2>/dev/null | grep -q "pair.*PAIR"; then
    echo "Your adb build doesn't support 'adb pair'. Please update Android platform-tools (e.g., via Android SDK Manager) or use the 'connect' mode with USB." >&2
    exit 1
  fi

  restart_adb
  echo "Pairing with $PAIR_ADDR ..."
  adb pair "$PAIR_ADDR" "$PAIR_CODE"

  echo "Connecting to $DEVICE_ADDR ..."
  adb connect "$DEVICE_ADDR"

  echo "Devices now:"
  adb devices
  run_flutter "$DEVICE_ADDR" "$TARGET"
  exit 0
fi

echo "Unknown command: $cmd"
exit 1
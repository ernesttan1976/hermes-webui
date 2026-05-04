#!/usr/bin/env bash
set -euo pipefail

# Watch for a healthy process listening on port 8642.
# If none is found, wait 30s and start hermes_gateway.sh in a new Terminal tab/window.
# This script is intended for macOS (uses AppleScript/Terminal), with simple fallbacks.

PORT=8642
CHECK_INTERVAL=10
WAIT_BEFORE_START=30
# HTTP health check URL (default points to local gateway health endpoint)
HEALTH_URL="http://127.0.0.1:${PORT}/health"
GATEWAY_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)/hermes_gateway.sh"

# Track the last Terminal window ids we opened on macOS (if any)
LAST_TERMINAL_WINDOW_ID=""
LAST_LOG_WINDOW_ID=""

if [ ! -x "$GATEWAY_SCRIPT" ]; then
  echo "Making gateway script executable: $GATEWAY_SCRIPT"
  chmod +x "$GATEWAY_SCRIPT" || true
fi

function is_port_open() {
  # Prefer an HTTP health check to determine service health.
  # If HEALTH_URL is set (default: http://127.0.0.1:$PORT/health), use curl or wget.
  if [[ -n "${HEALTH_URL:-}" ]]; then
    if command -v curl >/dev/null 2>&1; then
      # -s: silent, -f: fail on non-2xx, --max-time: timeout in seconds
      curl --max-time 3 -sf "$HEALTH_URL" >/dev/null 2>&1 && return 0 || return 1
    elif command -v wget >/dev/null 2>&1; then
      wget -q --timeout=3 --spider "$HEALTH_URL" >/dev/null 2>&1 && return 0 || return 1
    else
      # No HTTP client available; fall through to port check
      :
    fi
  fi

  # Fallback: Try lsof (macOS/Linux), then ss (linux), then netstat as last resort
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1 && return 0 || return 1
  elif command -v ss >/dev/null 2>&1; then
    ss -ltn | awk '{print $4}' | grep -q ":$PORT$" && return 0 || return 1
  else
    netstat -an 2>/dev/null | grep -E "LISTEN|LISTENING" | grep -q ".$PORT" && return 0 || return 1
  fi
}

function kill_port_processes() {
  # Kill any process listening on $PORT
  if command -v lsof >/dev/null 2>&1; then
    local pids
    pids=$(lsof -t -iTCP:$PORT -sTCP:LISTEN 2>/dev/null || true)
    if [[ -n "$pids" ]]; then
      echo "Killing existing processes on port $PORT: $pids"
      kill $pids || true
    fi
  elif command -v ss >/dev/null 2>&1; then
    local pids
    pids=$(ss -ltnp "sport = :$PORT" 2>/dev/null | awk -F',' '/pid=/ {sub(/pid=/,"",$2); print $2}' || true)
    if [[ -n "$pids" ]]; then
      echo "Killing existing processes on port $PORT: $pids"
      kill $pids || true
    fi
  else
    echo "Warning: cannot automatically kill processes on port $PORT (no lsof or ss)"
  fi
}

function start_gateway_terminal() {
  echo "Starting hermes gateway using Terminal (if available) or background process."

  if [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v osascript >/dev/null 2>&1; then
      # macOS + AppleScript: open two Terminal windows/tabs (gateway + log tail)
      osascript <<EOF
        tell application "Terminal"
          activate
          do script "${GATEWAY_SCRIPT}"
          do script "tail -F ~/.hermes/logs/gateway.log"
        end tell
EOF
      echo "Started hermes gateway and log tail in Terminal."
    elif command -v open >/dev/null 2>&1 && [[ -d /Applications/Utilities/Terminal.app ]]; then
      # Fallback: open gateway script; tail in background
      open -a Terminal "$GATEWAY_SCRIPT" || true
      (sleep 1; tail -F ~/.hermes/logs/gateway.log) &
      echo "Started hermes gateway in Terminal and background tail of gateway log."
    else
      # Last resort: run both in background in this shell
      bash "$GATEWAY_SCRIPT" &
      echo "Started gateway in background with PID $! (no Terminal control)"
      (sleep 1; tail -F ~/.hermes/logs/gateway.log) &
      echo "Started background tail of gateway log"
    fi
  else
    # Non-macOS: just start background process and tail in background
    bash "$GATEWAY_SCRIPT" &
    echo "Started gateway in background with PID $!"
    (sleep 1; tail -F ~/.hermes/logs/gateway.log) &
    echo "Started background tail of gateway log"
  fi
}

while true; do
  if is_port_open; then
    # Process listening - healthy: do NOT start any new Terminal
    sleep $CHECK_INTERVAL
    continue
  fi

  echo "No process listening on port $PORT. Waiting $WAIT_BEFORE_START seconds before starting gateway..."
  sleep $WAIT_BEFORE_START

  # Double-check after waiting
  if is_port_open; then
    echo "Process started during wait. Skipping start."
    sleep $CHECK_INTERVAL
    continue
  fi

  # At this point the app is still not running (port closed).
  # Only now are we allowed to start a Terminal for the gateway, and we will
  # only open a new one if the previous Terminal window is closed (handled
  # inside start_gateway_terminal).
  kill_port_processes
  start_gateway_terminal

  # Give the process some time then re-check
  sleep $CHECK_INTERVAL

done

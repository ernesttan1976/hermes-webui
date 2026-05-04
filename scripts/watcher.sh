#!/usr/bin/env bash
set -euo pipefail

# Watch for a healthy process listening on port 8642.
# If none is found, wait 30s and start hermes_gateway.sh in a new Terminal tab/window.
# This script is intended for macOS (uses AppleScript/Terminal), with simple fallbacks.

PORT=8642
CHECK_INTERVAL=10
WAIT_BEFORE_START=30
GATEWAY_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)/hermes_gateway.sh"

# Track the last Terminal window id we opened on macOS (if any)
LAST_TERMINAL_WINDOW_ID=""

if [ ! -x "$GATEWAY_SCRIPT" ]; then
  echo "Making gateway script executable: $GATEWAY_SCRIPT"
  chmod +x "$GATEWAY_SCRIPT" || true
fi

function is_port_open() {
  # Try lsof first (macOS/Linux), then ss (linux), then netstat as fallback
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1 && return 0 || return 1
  elif command -v ss >/dev/null 2>&1; then
    ss -ltn | awk '{print $4}' | grep -q ":$PORT$" && return 0 || return 1
  else
    # netstat fallback
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
    # macOS: prefer AppleScript so we can capture the window id and avoid opening multiple windows
    if command -v osascript >/dev/null 2>&1; then
      # If we have a previously recorded Terminal window id, check if it still exists.
      if [[ -n "$LAST_TERMINAL_WINDOW_ID" ]]; then
        local still_exists
        still_exists=$(osascript <<EOF
          tell application "Terminal"
            set existing_windows to id of every window
            if existing_windows contains $LAST_TERMINAL_WINDOW_ID then
              return "yes"
            else
              return "no"
            end if
          end tell
EOF
        )
        if [[ "$still_exists" == "yes" ]]; then
          echo "Previous Terminal window id $LAST_TERMINAL_WINDOW_ID still open; not opening a new one."
          return
        else
          echo "Previous Terminal window id $LAST_TERMINAL_WINDOW_ID is gone; clearing tracking."
          LAST_TERMINAL_WINDOW_ID=""
        fi
      fi

      # Either no previous window tracked or it is closed: open a new Terminal window running the script
      LAST_TERMINAL_WINDOW_ID=$(osascript <<EOF
        tell application "Terminal"
          set newTab to do script "${GATEWAY_SCRIPT}"
          set newWindow to front window
          return id of newWindow
        end tell
EOF
      )
      echo "Started hermes gateway in Terminal window id $LAST_TERMINAL_WINDOW_ID"
    elif command -v open >/dev/null 2>&1 && [[ -d /Applications/Utilities/Terminal.app ]]; then
      # Fallback: 'open' (no reliable tracking, but at least avoid multiple via LAST_TERMINAL_WINDOW_ID)
      if [[ -n "$LAST_TERMINAL_WINDOW_ID" ]]; then
        echo "Terminal window previously opened (id $LAST_TERMINAL_WINDOW_ID); skipping new open via 'open'."
        return
      fi
      open -a Terminal "$GATEWAY_SCRIPT" || true
      LAST_TERMINAL_WINDOW_ID="open-fallback"
    else
      # Last resort: run in background in this shell
      bash "$GATEWAY_SCRIPT" &
      echo "Started gateway in background with PID $! (no Terminal control)"
    fi
  else
    # Non-macOS: just start background process (no window management)
    bash "$GATEWAY_SCRIPT" &
    echo "Started gateway in background with PID $!"
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

#!/usr/bin/env bash
set -euo pipefail

# Watch for a healthy process listening on port 8642.
# If none is found, wait 30s and start hermes_gateway.sh in a new terminal window.
# This script is intended for macOS (uses "open -a Terminal"), but will fall back to starting
# the script in the background if Terminal isn't available.

PORT=8642
CHECK_INTERVAL=10
WAIT_BEFORE_START=30
GATEWAY_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)/hermes_gateway.sh"

# Track the last child terminal PID we started (if any)
LAST_CHILD_PID=""

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
    # macOS: try to open a new Terminal window and run the script
    if command -v open >/dev/null 2>&1 && [[ -d /Applications/Utilities/Terminal.app ]]; then
      # 'open' doesn't give us a PID, so we can't track/kill this terminal reliably
      open -a Terminal "$GATEWAY_SCRIPT" || true
      LAST_CHILD_PID=""
    elif command -v osascript >/dev/null 2>&1; then
      # osascript also doesn't give us a PID; run without tracking
      osascript -e "tell application \"Terminal\" to do script \"$GATEWAY_SCRIPT\"" || true
      LAST_CHILD_PID=""
    else
      # Fallback: run in background in this shell, tracking PID
      bash "$GATEWAY_SCRIPT" &
      LAST_CHILD_PID=$!
      echo "Started gateway in background with PID $LAST_CHILD_PID"
    fi
  else
    # Linux / other: try gnome-terminal, xterm, or background
    if command -v gnome-terminal >/dev/null 2>&1; then
      gnome-terminal -- "$GATEWAY_SCRIPT" || true
      LAST_CHILD_PID=""
    elif command -v xterm >/dev/null 2>&1; then
      xterm -e "$GATEWAY_SCRIPT" &
      LAST_CHILD_PID=$!
      echo "Started gateway in xterm with PID $LAST_CHILD_PID"
    else
      bash "$GATEWAY_SCRIPT" &
      LAST_CHILD_PID=$!
      echo "Started gateway in background with PID $LAST_CHILD_PID"
    fi
  fi
}

while true; do
  if is_port_open; then
    # Process listening - healthy
    sleep $CHECK_INTERVAL
    continue
  fi

  echo "No process listening on port $PORT. Waiting $WAIT_BEFORE_START seconds before starting gateway..."
  sleep $WAIT_BEFORE_START

  # Double-check after waiting
  if is_port_open; then
    echo "Process started during wait. Skipping start."
    # If we had a child terminal/background process from a previous attempt, and the
    # port is now healthy, close/kill that previous child if we can.
    if [[ -n "$LAST_CHILD_PID" ]]; then
      if kill -0 "$LAST_CHILD_PID" 2>/dev/null; then
        echo "Port is healthy; terminating previous child process $LAST_CHILD_PID."
        kill "$LAST_CHILD_PID" || true
      fi
      LAST_CHILD_PID=""
    fi
    sleep $CHECK_INTERVAL
    continue
  fi

  # At this point, port is still not open after waiting.
  # If we still have a previous child process recorded, and it's alive, close it.
  if [[ -n "$LAST_CHILD_PID" ]]; then
    if kill -0 "$LAST_CHILD_PID" 2>/dev/null; then
      echo "Port still not healthy; terminating previous child process $LAST_CHILD_PID before starting a new one."
      kill "$LAST_CHILD_PID" || true
    fi
    LAST_CHILD_PID=""
  fi

  # Ensure any old gateway process is terminated before starting a new one
  kill_port_processes

  # Start a new gateway terminal/background process and record PID when possible
  start_gateway_terminal

  # Give the process some time then re-check
  sleep $CHECK_INTERVAL

done

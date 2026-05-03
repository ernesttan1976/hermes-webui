#!/usr/bin/env bash
set -euo pipefail

# Hermes WebUI + Agent local runner for macOS
# - Runs without Docker using bootstrap.py
# - Uses the same hermes-home as the Docker setup by default

REPO_ROOT="/Volumes/MyCrucial/raid/hermes-webui"
cd "$REPO_ROOT"

# Reuse the existing hermes-home directory so config/sessions carry over
export HERMES_HOME="$REPO_ROOT/docker-volumes/hermes-home"

# Default host/port for WebUI
export HERMES_WEBUI_HOST="127.0.0.1"
export HERMES_WEBUI_PORT="8787"

# Ensure a log dir exists under the user Library
LOG_DIR="$HOME/Library/Logs/Hermes"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/hermes-webui.log"

# Simple restart loop for manual resilience
while true; do
  echo "[hermes-run-terminal] Starting Hermes WebUI at http://$HERMES_WEBUI_HOST:$HERMES_WEBUI_PORT" | tee -a "$LOG_FILE"
  # --no-browser to avoid popping a tab every restart; user can open manually
  python3 "$REPO_ROOT/bootstrap.py" --no-browser "$HERMES_WEBUI_PORT" >>"$LOG_FILE" 2>&1 || true
  echo "[hermes-run-terminal] Process exited. Restarting in 5 seconds..." | tee -a "$LOG_FILE"
  sleep 5
done

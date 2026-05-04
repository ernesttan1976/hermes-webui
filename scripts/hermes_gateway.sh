#!/usr/bin/env bash
set -euo pipefail

cd /Volumes/MyCrucial/raid/hermes-agent

# Activate virtual environment
if [ -f .venv/bin/activate ]; then
  # shellcheck disable=SC1091
  source .venv/bin/activate
else
  echo "Virtual environment .venv not found in /Volumes/MyCrucial/raid/hermes-agent" >&2
  exit 1
fi

# Run hermes gateway
uv run hermes gateway

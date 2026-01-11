#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
BASE_DIR="$(pwd)"

# Activate venv
if [[ ! -f ".venv/bin/activate" ]]; then
  echo "[!] .venv not found. Run ./setup.sh first."
  exit 1
fi
# shellcheck disable=SC1091
source ".venv/bin/activate"

FIFO="/tmp/seestar"
INDI_PORT="${INDI_PORT:-7624}"
APP_DIR="${APP_DIR:-$BASE_DIR/seestar_alp}"

# Verify app files
if [[ ! -f "$APP_DIR/root_app.py" ]]; then
  echo "[!] root_app.py not found at: $APP_DIR/root_app.py"
  exit 1
fi
if [[ ! -f "$APP_DIR/indi/start_indi_devices.py" ]]; then
  echo "[!] start_indi_devices.py not found at: $APP_DIR/indi/start_indi_devices.py"
  exit 1
fi

echo "[i] Using APP_DIR: $APP_DIR"

# Ensure config.toml exists (create from example if needed)
mkdir -p "$APP_DIR/logs"
if [[ ! -f "$APP_DIR/device/config.toml" ]]; then
  echo "[i] device/config.toml missing; creating from example"
  if [[ -f "$APP_DIR/device/config.toml.example" ]]; then
    cp "$APP_DIR/device/config.toml.example" "$APP_DIR/device/config.toml"
    sed -i -e 's/127.0.0.1/0.0.0.0/g' "$APP_DIR/device/config.toml" || true
    sed -i -e 's|log_prefix =.*|log_prefix = "logs/"|g' "$APP_DIR/device/config.toml" || true
  else
    echo "[!] Missing $APP_DIR/device/config.toml.example"
    exit 1
  fi
fi

# Create FIFO if needed
if [[ -p "$FIFO" ]]; then
  echo "[i] FIFO exists: $FIFO"
else
  if [[ -e "$FIFO" ]]; then
    echo "[!] $FIFO exists but is not a FIFO. Remove it and rerun:"
    echo "    rm -f $FIFO"
    exit 1
  fi
  echo "[i] Creating FIFO: $FIFO"
  mkfifo "$FIFO"
fi

# Avoid confusion if port is busy
if sudo ss -ltnp | grep -q ":$INDI_PORT"; then
  echo "[!] INDI port $INDI_PORT is already in use."
  sudo ss -ltnp | grep ":$INDI_PORT" || true
  echo "    Use another port: INDI_PORT=7625 ./run.sh"
  exit 1
fi

echo "[i] Starting indiserver on port $INDI_PORT"
indiserver -p "$INDI_PORT" -f "$FIFO" &
INDI_PID=$!

cleanup() {
  echo
  echo "[i] Cleaning up..."
  if kill -0 "$INDI_PID" 2>/dev/null; then
    kill "$INDI_PID" 2>/dev/null || true
    wait "$INDI_PID" 2>/dev/null || true
  fi
  echo "[i] Done."
}
trap cleanup EXIT INT TERM

echo "[i] Starting INDI devices"
pushd "$APP_DIR/indi" >/dev/null
python3 start_indi_devices.py
popd >/dev/null

echo "[i] Launching root_app.py"
pushd "$APP_DIR" >/dev/null
python3 root_app.py
popd >/dev/null


#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
BASE_DIR="$(pwd)"

echo "[i] Base dir: $BASE_DIR"

# --- Debian deps (safe to re-run) ---
echo "[i] Installing apt deps"
sudo apt update
sudo apt install -y \
  python3-venv python3-pip git indi-bin \
  build-essential pkg-config

# --- Clone or update seestar_alp ---
REPO_DIR="$BASE_DIR/seestar_alp"
REPO_URL="https://github.com/smart-underworld/seestar_alp.git"

if [[ -d "$REPO_DIR/.git" ]]; then
  echo "[i] Updating seestar_alp"
  git -C "$REPO_DIR" pull --ff-only
else
  echo "[i] Cloning seestar_alp"
  git clone "$REPO_URL" "$REPO_DIR"
fi

# --- Ensure seestar_alp folders/config exist ---
echo "[i] Initializing seestar_alp config"
mkdir -p "$REPO_DIR/logs"

# Create device/config.toml from example if missing (upstream behavior)
if [[ ! -f "$REPO_DIR/device/config.toml" ]]; then
  if [[ -f "$REPO_DIR/device/config.toml.example" ]]; then
    cp "$REPO_DIR/device/config.toml.example" "$REPO_DIR/device/config.toml"

    # Optional: match upstream Raspberry Pi setup defaults:
    # - bind to all interfaces (so you can access Web UI from other machines)
    # - log into ./logs
    sed -i -e 's/127.0.0.1/0.0.0.0/g' "$REPO_DIR/device/config.toml" || true
    sed -i -e 's|log_prefix =.*|log_prefix = "logs/"|g' "$REPO_DIR/device/config.toml" || true
  else
    echo "[!] Missing $REPO_DIR/device/config.toml.example (repo layout changed?)"
    exit 1
  fi
else
  # Keep a quick backup if it already exists
  cp "$REPO_DIR/device/config.toml" "$REPO_DIR/device/config.toml.bak" || true
fi

# --- Create venv (repair if incomplete) ---
if [[ -e .venv && ! -d .venv ]]; then
  echo "[!] .venv exists but is not a directory; remove/rename it and rerun."
  exit 1
fi
if [[ -d .venv && ! -x .venv/bin/python ]]; then
  echo "[i] Found incomplete .venv; removing"
  rm -rf .venv
fi

if [[ ! -d .venv ]]; then
  echo "[i] Creating venv"
  python3 -m venv .venv
fi

# Activate venv
# shellcheck disable=SC1091
source .venv/bin/activate

echo "[i] Python: $(python -V)"
echo "[i] Upgrading pip tooling"
python -m pip install -U pip setuptools wheel

# --- Install pyINDI fork ---
echo "[i] Installing pyINDI fork"
python -m pip install "git+https://github.com/stefano-sartor/pyINDI.git"

# --- Fix indi.dtd path inside venv ---
PURELIB="$(python -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')"
DEVICE_DIR="$PURELIB/pyindi/device"
DTD_SRC="$PURELIB/pyindi/data/indi.dtd"
DTD_EXPECTED="$DEVICE_DIR/data/indi.dtd"

echo "[i] purelib: $PURELIB"

if [[ ! -f "$DTD_SRC" ]]; then
  echo "[!] pyINDI installed but missing: $DTD_SRC"
  exit 1
fi

rm -rf "$DEVICE_DIR/data"
ln -s ../data "$DEVICE_DIR/data"

if [[ ! -f "$DTD_EXPECTED" ]]; then
  echo "[!] Still missing expected DTD: $DTD_EXPECTED"
  exit 1
fi

python -c "import pyindi.device; print('pyindi.device import OK')"

# --- Install seestar_alp requirements (if present) ---
echo "[i] Installing seestar_alp requirements (if available)"
if [[ -f "$REPO_DIR/requirements.txt" ]]; then
  python -m pip install -r "$REPO_DIR/requirements.txt"
else
  echo "[i] No requirements.txt found in $REPO_DIR (skipping)"
fi

# --- Verify expected app files exist ---
if [[ ! -f "$REPO_DIR/root_app.py" ]]; then
  echo "[!] Expected $REPO_DIR/root_app.py not found. Repo layout may have changed."
  exit 1
fi
if [[ ! -f "$REPO_DIR/indi/start_indi_devices.py" ]]; then
  echo "[!] Expected $REPO_DIR/indi/start_indi_devices.py not found."
  exit 1
fi

echo "[✓] Setup complete."
echo "    Next: ./run.sh"


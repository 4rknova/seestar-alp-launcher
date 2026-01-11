# seestar-alp-launcher

Debian-friendly helper scripts to set up and run `seestar_alp` + INDI in a
clean, repeatable way.

This repository does NOT contain the Seestar application code itself. Instead,
it:

- installs required Debian packages (INDI + Python tooling)
- clones (or updates) the upstream `seestar_alp` repository into `./seestar_alp`
- creates a local Python virtualenv in `./.venv`
- installs the `pyINDI` fork required by `seestar_alp`
- applies the `indi.dtd` symlink fix needed by `pyindi`
- ensures `seestar_alp/device/config.toml` exists (copied from the example on
  first run)
- starts an observing session: FIFO -> indiserver -> INDI devices -> root_app.py

## Directory layout

After running setup, you should have:

    seestar-alp-launcher/
      setup.sh
      run.sh
      .gitignore
      .venv/                  # local Python virtual environment
      seestar_alp/            # cloned upstream project (git repo)
        root_app.py
        indi/start_indi_devices.py
        device/config.toml.example
        device/config.toml    # generated from example
        logs/                 # created on demand

## Requirements

- Debian-based system
- sudo access for installing apt packages
- network access for cloning GitHub repos / pip installs

## Setup (one-time)

From the `seestar-alp-launcher` directory:

    chmod +x setup.sh run.sh
    ./setup.sh

What `setup.sh` does:

1. Installs apt packages: `python3-venv`, `python3-pip`, `git`, `indi-bin`,
   plus build tools.
2. Clones or updates `seestar_alp` into `./seestar_alp`.
3. Creates/repairs `./.venv` and upgrades pip tooling.
4. Installs the `pyINDI` fork:
   `git+https://github.com/stefano-sartor/pyINDI.git`
5. Fixes `pyindi` looking for `indi.dtd` under `pyindi/device/data/` by
   symlinking:
   `pyindi/device/data -> ../data`
6. Copies `seestar_alp/device/config.toml.example` to
   `seestar_alp/device/config.toml` if missing, and creates `seestar_alp/logs/`.

## Run (each session)

    ./run.sh

What `run.sh` does:

1. Activates the local venv (`./.venv`).
2. Ensures the FIFO exists at `/tmp/seestar` (creates it if missing).
3. Starts `indiserver` on port 7624 using that FIFO.
4. Runs `seestar_alp/indi/start_indi_devices.py`.
5. Launches `seestar_alp/root_app.py`.
6. On exit (or Ctrl-C), stops the `indiserver` it started.

### Changing the INDI port

If port 7624 is busy or you want a different port:

    INDI_PORT=7625 ./run.sh

### Using a different `seestar_alp` location

By default, `run.sh` uses `./seestar_alp`. If you want to point it elsewhere:

    APP_DIR="/path/to/seestar_alp" ./run.sh

## Notes / troubleshooting

### `start_indi_devices.py` fails with missing `device/config.toml`

Both `setup.sh` and `run.sh` will create it automatically from
`config.toml.example`. To regenerate it manually:

    cp seestar_alp/device/config.toml.example seestar_alp/device/config.toml

### `pyindi` import fails looking for `indi.dtd`

The scripts apply the symlink fix inside the venv site-packages:

    .../site-packages/pyindi/device/data -> ../data

If you recreate the venv, rerun `./setup.sh`.

## What this repo is / isn't

- A Debian-friendly wrapper around `seestar_alp` + `pyINDI` + INDI setup.
- Keeps Python installs isolated in a venv (no system `pip` installs).
- Not a replacement for `seestar_alp` itself; it clones it into `./seestar_alp`.
- Does not configure Stellarium for you (you still point Stellarium at the
  INDI server).

## Configuring Stellarium

Stellarium can control mounts and show telescope position via INDI. This
launcher starts `indiserver` (default port 7624), which is what Stellarium
connects to.

### 1) Install Stellarium and the INDI plugin support

On Debian:

    sudo apt update
    sudo apt install -y stellarium

(Some Debian builds package the INDI plugin separately. If you do not see any
telescope/INDI options in Stellarium after installing, search available
packages for "stellarium" and "indi" and install the matching plugin package.)

### 2) Start your INDI session first

In this repo:

    ./run.sh

Leave it running.

### 3) Configure Stellarium to use the INDI server

In Stellarium:

1. Open the Configuration window (F2).
2. Go to the Plugins tab.
3. Select the Telescope Control plugin.
4. Check "Load at startup" (optional but recommended) and restart Stellarium.
5. Open Telescope Control (often available under the configuration/plugins
   area, or via a telescope control window/shortcut depending on version).
6. Add a telescope using an INDI connection:
   - Host: 127.0.0.1 (if Stellarium is on the same machine)
   - Port: 7624 (or whatever you set via INDI_PORT)
7. Save/apply, then connect.

If Stellarium is running on a different machine than `indiserver`, use the IP
address of the machine running `run.sh` instead of 127.0.0.1, and ensure your
firewall allows inbound TCP to the chosen INDI port.

### 4) Common checks if Stellarium won't connect

- Confirm the INDI port is listening:

      ss -ltn | grep ':7624'

- If you changed the port:

      INDI_PORT=7625 ./run.sh

  then set Stellarium to port 7625.

- If connecting over the network, confirm host reachability and firewall rules
  (e.g. `ufw`/`nftables`) allow the INDI port.

## License

The helper scripts and files in this repository are licensed under the MIT
License.

Upstream components (`seestar_alp`, INDI, and the `pyINDI` fork) retain their
respective licenses.

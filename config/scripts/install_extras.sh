#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

echo "[install_extras] Ensuring hyperblue command is available..."
"${SCRIPT_DIR}/ensure_hyperblue.sh"

echo "[install_extras] Enabling hyperblue-first-login.service for user sessions..."
# Create the wants directory if it doesn't exist
mkdir -p /usr/lib/systemd/user/default.target.wants

# Create symlink to enable the service for all users by default
ln -sf ../hyperblue-first-login.service /usr/lib/systemd/user/default.target.wants/hyperblue-first-login.service

echo "[install_extras] Extras installation complete."

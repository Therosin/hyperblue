#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

echo "[install_extras] Ensuring hyperblue command is available..."
"${SCRIPT_DIR}/ensure_hyperblue.sh"
echo "[install_extras] Extras installation complete."

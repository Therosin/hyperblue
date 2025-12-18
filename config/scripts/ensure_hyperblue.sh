#!/usr/bin/env bash
# Copyright (C) 2025 Theros <https://github.com/therosin>
#
# This file is part of hyperblue.
#
# hyperblue is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# hyperblue is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with hyperblue.  If not, see <https://www.gnu.org/licenses/>.

set -euo pipefail

readonly TARGET="/usr/bin/hyperblue"
readonly SOURCE="/usr/share/hyperblue/hyperblue.sh"

log() {
    echo "[hyperblue] $*"
}

fatal() {
    echo "[hyperblue] $*" >&2
    exit 1
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        fatal "This script must be run as root so it can manage ${TARGET}."
    fi
}

ensure_source_exists() {
    if [[ ! -f ${SOURCE} ]]; then
        fatal "Expected launcher script not found at ${SOURCE}."
    fi

    if [[ ! -x ${SOURCE} ]]; then
        log "Marking ${SOURCE} as executable."
        chmod +x "${SOURCE}"
    fi
}

ensure_symlink() {
    if [[ -L ${TARGET} ]]; then
        local current_target
        current_target=$(readlink -f "${TARGET}") || fatal "Failed to resolve ${TARGET}."

        if [[ ${current_target} == ${SOURCE} ]]; then
            log "hyperblue symlink already points to ${SOURCE}."
            return 0
        fi

        log "Updating existing hyperblue symlink from ${current_target} to ${SOURCE}."
        ln -sfn "${SOURCE}" "${TARGET}"
        return 0
    fi

    if [[ -e ${TARGET} ]]; then
        fatal "${TARGET} exists and is not a symlink; refusing to overwrite."
    fi

    log "Setting up hyperblue symlink at ${TARGET}."
    ln -s "${SOURCE}" "${TARGET}"
}

main() {
    log "Configuring hyperblue command..."
    require_root
    ensure_source_exists
    ensure_symlink
    log "hyperblue command configured."
}

main "$@"

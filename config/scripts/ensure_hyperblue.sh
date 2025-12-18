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
readonly FIRST_LOGIN_SERVICE="/usr/lib/systemd/user/hyperblue-first-login.service"
readonly FIRST_LOGIN_SERVICE_NAME="hyperblue-first-login.service"
readonly USER_WANTS_DIR="/usr/lib/systemd/user/default.target.wants"
readonly FIRST_RUN_INSTALL_SCRIPT="/usr/share/hyperblue/firstrun_install.sh"

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
        chmod +x "${SOURCE}" || fatal "Failed to mark ${SOURCE} as executable."
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

ensure_first_run_install_script() {
    if [[ ! -f ${FIRST_RUN_INSTALL_SCRIPT} ]]; then
        fatal "Expected first-run installer not found at ${FIRST_RUN_INSTALL_SCRIPT}."
    fi

    if [[ ! -x ${FIRST_RUN_INSTALL_SCRIPT} ]]; then
        log "Marking ${FIRST_RUN_INSTALL_SCRIPT} as executable."
        chmod +x "${FIRST_RUN_INSTALL_SCRIPT}" || fatal "Failed to mark ${FIRST_RUN_INSTALL_SCRIPT} as executable."
    fi
}

ensure_first_login_service_file() {
    if [[ ! -f ${FIRST_LOGIN_SERVICE} ]]; then
        fatal "Expected user service not found at ${FIRST_LOGIN_SERVICE}."
    fi

    if [[ ! -r ${FIRST_LOGIN_SERVICE} ]]; then
        fatal "User service at ${FIRST_LOGIN_SERVICE} is not readable."
    fi
}

manual_enable_first_login_service() {
    log "Falling back to manual enable of ${FIRST_LOGIN_SERVICE_NAME}."
    mkdir -p "${USER_WANTS_DIR}" || fatal "Failed to create ${USER_WANTS_DIR}."
    ln -sfn "../${FIRST_LOGIN_SERVICE_NAME}" "${USER_WANTS_DIR}/${FIRST_LOGIN_SERVICE_NAME}" || fatal "Failed to link ${FIRST_LOGIN_SERVICE_NAME} into ${USER_WANTS_DIR}."
    log "Manual enable completed via ${USER_WANTS_DIR}/${FIRST_LOGIN_SERVICE_NAME}."
}

reload_user_units() {
    if ! command -v systemctl >/dev/null 2>&1; then
        log "systemctl not found; unable to reload user units automatically."
        return
    fi

    if systemctl --global daemon-reload >/dev/null 2>&1; then
        log "Reloaded global user units."
        return
    fi

    if systemctl daemon-reload >/dev/null 2>&1; then
        log "Reloaded systemd units with system-wide daemon-reload fallback."
        return
    fi

    log "Warning: Unable to reload systemd units automatically; user sessions may need a manual reload."
}

enable_first_login_service() {
    log "Ensuring ${FIRST_LOGIN_SERVICE_NAME} is enabled for all users..."

    if command -v systemctl >/dev/null 2>&1; then
        if systemctl --global enable "${FIRST_LOGIN_SERVICE_NAME}" >/dev/null 2>&1; then
            log "${FIRST_LOGIN_SERVICE_NAME} enabled globally via systemctl."
        else
            log "systemctl --global enable failed."
            manual_enable_first_login_service
        fi
    else
        log "systemctl not available; enabling via manual symlink."
        manual_enable_first_login_service
    fi

    reload_user_units
}

main() {
    log "Configuring hyperblue command..."
    require_root
    ensure_source_exists
    ensure_symlink
    ensure_first_run_install_script
    ensure_first_login_service_file
    enable_first_login_service
    log "hyperblue command configured and first-login installer enabled."
}

main "$@"

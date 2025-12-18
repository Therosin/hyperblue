#! /usr/bin/env bash
set -oue pipefail

# First run installation script for HyperBlue.

# ─── Utils ────────────────────────────────────────────────────────────────────

safe_exec() {
    # command to check
    local command=$1
    # script to execute
    local script=$2
    if ! command -v ${command%% *} &> /dev/null; then
        error "$command could not be found. Aborting."
        exit 1
    fi

    echo "Executing: $script"

    eval "$script"
    if [[ $? -ne 0 ]]; then
        error "Failed to execute $script"
        exit 1
    fi
}

# ─── Main Script ──────────────────────────────────────────────────────────────

install_hyprland() {
    echo "Installing Hyprland and dependencies..."
    # sh <(curl -L https://raw.githubusercontent.com/JaKooLit/Hyprland-Dots/main/Distro-Hyprland.sh)
    safe_exec curl "curl -L https://raw.githubusercontent.com/JaKooLit/Hyprland-Dots/main/Distro-Hyprland.sh | bash"
}



echo "Starting first run installation for HyperBlue..."

# ─── Installation ─────────────────────────────────────────────────────────────
install_hyprland


echo "First run installation completed."

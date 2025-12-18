#!/usr/bin/env bash
# shellcheck disable=SC2181
set -euo pipefail

# First run installation script for HyperBlue.

# ─── Utils ────────────────────────────────────────────────────────────────────

colorize() {
    local color=$1
    shift
    echo -e "\033[${color}m$*\033[0m"
}

info() {
    colorize "0;32" "$@"
}

error() {
    colorize "0;31" "$@"
}

warn() {
    colorize "0;33" "$@"
}

check_and_exec() {
    # command to check
    local command=$1
    # script to execute
    local script=$2
    if ! command -v "${command%% *}" &> /dev/null; then
        error "$command could not be found. Aborting."
        exit 1
    fi

    info "Executing: $script"

    if ! eval "$script"; then
        error "Failed to execute $script"
        exit 1
    fi
}

# ─── Main Script ──────────────────────────────────────────────────────────────

install_hyprland() {
    info "Installing Hyprland and dependencies..."
    
    # Security: Download script to temp file and verify before execution
    local script_url="https://raw.githubusercontent.com/JaKooLit/Hyprland-Dots/main/Distro-Hyprland.sh"
    local temp_script
    temp_script=$(mktemp) || {
        error "Failed to create temporary file"
        exit 1
    }
    
    # Expected SHA256 checksum of the script (update this when script changes)
    # To get checksum: curl -L <url> | sha256sum
    # This is a placeholder - replace with actual checksum when ready to enable verification
    # shellcheck disable=SC2034
    local expected_checksum=""
    
    info "Downloading Hyprland installation script..."
    if ! curl -fsSL "$script_url" -o "$temp_script"; then
        error "Failed to download Hyprland installation script"
        rm -f "$temp_script"
        exit 1
    fi
    
    # Calculate checksum of downloaded script
    local actual_checksum
    actual_checksum=$(sha256sum "$temp_script" | cut -d' ' -f1)
    
    # Verify checksum (commented out for now - needs actual checksum)
    # if [[ "$actual_checksum" != "$expected_checksum" ]]; then
    #     error "Checksum verification failed!"
    #     error "Expected: $expected_checksum"
    #     error "Got: $actual_checksum"
    #     rm -f "$temp_script"
    #     exit 1
    # fi
    
    if [[ -z "$expected_checksum" ]]; then
        warn "WARNING: Checksum verification is currently disabled."
        warn "To enable it, update the expected_checksum variable with the current checksum:"
        warn "  $actual_checksum"
    fi
    
    # Make script executable and run it
    chmod +x "$temp_script"
    
    info "Executing Hyprland installation script..."
    if bash "$temp_script"; then
        info "Hyprland installation completed successfully"
    else
        error "Hyprland installation failed"
        rm -f "$temp_script"
        exit 1
    fi
    
    # Clean up
    rm -f "$temp_script"
}



main() {
    if [[ $EUID -eq 0 ]]; then
        error "This installer should be run as the logged-in user, not root."
        exit 1
    fi

    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hyperblue"
    local first_run_flag="${config_dir}/.firstrun_done"

    # Ensure config directory exists before attempting flag file creation
    if ! mkdir -p "$config_dir"; then
        error "Failed to create config directory: $config_dir"
        exit 1
    fi

    # Atomically create the flag file to prevent race conditions
    # Using noclobber mode (set -C) ensures the file is created exclusively
    # The colon (:) is a null command that creates an empty file
    # If successful (file didn't exist), proceed with installation
    # If failed (file already exists), skip installation
    if (set -C; : > "$first_run_flag") 2>/dev/null; then
        # File was created successfully - this is the first run
        info "Starting first run installation for HyperBlue..."
        install_hyprland
        info "First run installation completed."
    else
        # File already exists - installation was already completed
        warn "First run tasks already completed, skipping."
        exit 0
    fi
}

main "$@"

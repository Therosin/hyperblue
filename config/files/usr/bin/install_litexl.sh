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

#!/usr/bin/env bash
set -oue pipefail

if ! command -v curl &>/dev/null; then
    error "curl is not installed. Please install curl and try again."
    exit 1
fi

function colorize() {
    local color=$1
    shift
    echo -e "\033[${color}m$*\033[0m"
}

function info() {
    colorize "0;32" "$@"
}

function error() {
    colorize "0;31" "$@"
}

function warn() {
    colorize "0;33" "$@"
}

function url_install() {
    local url=$1

    if [[ -z $url ]]; then
        error "No URL provided to url_install"
        exit 1
    fi

    curl -fsSL "$url" | bash

    if [[ $? -ne 0 ]]; then
        error "Failed to install $url"
        exit 1
    fi
}

function safe_exec() {
    local script=$1

    if [[ -z $script ]]; then
        error "No script provided to safe_exec"
        exit 1
    fi

    eval "$script"

    if [[ $? -ne 0 ]]; then
        error "Failed to execute $script"
        exit 1
    fi
}

ensure_directory() {
    local dir=$1

    if [[ -z $dir ]]; then
        error "No directory provided to ensure_directory"
        exit 1
    fi

    if [[ ! -d $dir ]]; then
        info "Creating directory: $dir"
        mkdir -p "$dir"
        if [[ $? -ne 0 ]]; then
            error "Failed to create directory: $dir"
            exit 1
        fi
    else
        info "Directory already exists: $dir"
    fi

    return 0
}

# curl -LO https://github.com/lite-xl/lite-xl/releases/download/v2.1.7/lite-xl-v2.1.7-addons-linux-x86_64-portable.tar.gz

# if tar -xzf lite-xl-v2.1.7-addons-linux-x86_64-portable.tar.gz -C /opt; then
#     echo "Extraction successful."
# else
#     echo "Error: Extraction failed." >&2
#     exit 1
# fi

# if [ -d /opt/lite-xl ]; then
#     echo "Directory /opt/lite-xl exists."
# else
#     echo "Error: Directory /opt/lite-xl was not created." >&2
#     exit 1
# fi

# if chown -R root:root /opt/lite-xl && chmod -R 755 /opt/lite-xl; then
#     echo "Permissions set successfully."
# else
#     echo "Error: Failed to set permissions." >&2
#     exit 1
# fi

# if ! grep -q '/opt/lite-xl' /etc/profile; then
#     if echo 'export PATH=/opt/lite-xl:$PATH' | tee -a /etc/profile > /dev/null; then
#         echo "PATH updated successfully."
#     else
#         echo "Error: Failed to update PATH." >&2
#         exit 1
#     fi
# fi

function download_package() {
    local version=$1
    local target=$2
    local url="https://github.com/lite-xl/lite-xl/releases/download/v${version}/lite-xl-v${version}-addons-linux-x86_64-portable.tar.gz"

    if [[ -z $version || -z $target ]]; then
        error "Version and target must be specified."
        exit 1
    fi

    # Ensure the target directory exists
    ensure_directory "$(dirname "$target")"
    if [[ $? -ne 0 ]]; then
        error "Failed to ensure target directory exists: $(dirname "$target")"
        exit 1
    fi

    # Download the package to the target directory
    curl -L "$url" -o "$target"
    if [[ $? -ne 0 ]]; then
        error "Failed to download package from $url"
        exit 1
    fi

    # Check if the download was successful
    if [[ ! -f $target ]]; then
        error "Package download failed or file does not exist: $target"
        exit 1
    fi
    info "Package downloaded to $target"
}

function extract_package() {
    local target=$1
    local dest=$2

    if [[ -z $target || -z $dest ]]; then
        error "Target and destination must be specified."
        exit 1
    fi

    # Extract the package to the destination directory
    tar -xzf "$target" -C "$dest"
    if [[ $? -ne 0 ]]; then
        error "Failed to extract package to $dest"
        exit 1
    fi

    # Check if the extraction was successful
    if [[ ! -d $dest ]]; then
        error "Extraction failed or destination directory does not exist: $dest"
        exit 1
    fi

    info "Package extracted to $dest"
}

function set_permissions() {
    local target=$1
    if [[ -z $target ]]; then
        error "Target directory must be specified."
        exit 1
    fi

    # ownership and permissions to current user if not specified.
    local owner=$2
    if [[ -z $owner ]]; then
        owner="$USER:$USER"
    fi
    local permissions=${3:-755}

    sudo -c "chown -R $owner $target"
    # Check if the command was successful
    if [[ $? -ne 0 ]]; then
        error "Failed to set ownership for $target"
        exit 1
    fi

    sudo -c "chmod -R $permissions $target"
    # Check if the command was successful
    if [[ $? -ne 0 ]]; then
        error "Failed to set permissions for $target"
        exit 1
    fi

    info "Permissions set for $target"
}

function update_path() {
    local target=$1
    if [[ -z $target ]]; then
        error "Target directory must be specified."
        exit 1
    fi

    # Check if the target is already in PATH
    if ! grep -q "$target" /etc/profile; then
        echo "export PATH=$target:\$PATH" | sudo tee -a /etc/profile >/dev/null
        if [[ $? -ne 0 ]]; then
            error "Failed to update PATH with $target"
            exit 1
        fi
        info "PATH updated with $target"
    else
        warn "Target directory is already in PATH: $target"
    fi
}

function cleanup_package() {
    local TARGET=$1
    if rm -f $TARGET; then
        echo "Cleanup successful."
    else
        echo "Error: Cleanup failed." >&2
    fi
}

function install_litexl() {
    local version="2.1.7"
    local download_to="/tmp/lite-xl-v${version}-addons-linux-x86_64-portable.tar.gz"
    local install_to="$HOME/.local/share/lite-xl"
    local owner="$USER:$USER"
    local permissions="755"

    info "Installing Lite XL version $version..."

    # Download the package
    download_package "$version" "$download_to"
    if [[ $? -ne 0 ]]; then
        error "Failed to download Lite XL package."
        exit 1
    fi

    # Extract the package
    extract_package "$download_to" "$install_to"
    if [[ $? -ne 0 ]]; then
        error "Failed to extract Lite XL package."
        cleanup_package "$download_to"
        exit 1
    fi

    # Set permissions
    set_permissions "$install_to" "$owner" "$permissions"
    if [[ $? -ne 0 ]]; then
        error "Failed to set permissions for Lite XL installation."
        exit 1
    fi

    # Update PATH
    update_path "$install_to"
    if [[ $? -ne 0 ]]; then
        error "Failed to update PATH for Lite XL."
        exit 1
    fi

    # Cleanup downloaded package
    cleanup_package "$download_to"
    if [[ $? -ne 0 ]]; then
        error "Failed to clean up downloaded package."
        exit 1
    fi

    info "Lite XL version $version installed successfully."
}

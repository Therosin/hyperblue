#! /usr/bin/env bash
# shellcheck disable=SC2181
set -oue pipefail
# This script installs development tools for the system.
if ! command -v curl &> /dev/null; then
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

ensure_user_bin() {
    if [[ ! -d $HOME/.local/bin ]]; then
        info "Creating $HOME/.local/bin directory..."
        mkdir -p "$HOME/.local/bin"
    fi
}


function install_luvit() {
    info "Installing luvit..."
    if ! command -v lit &> /dev/null; then
        safe_exec "cd $HOME/.local/bin && curl -L https://github.com/luvit/lit/raw/master/get-lit.sh | sh"
        if [[ $? -ne 0 ]]; then
            error "Failed to install Luvit"
        fi
    else
        warn "Luvit is already installed"
        return
    fi
}

function install_deno() {
    if ! command -v deno &> /dev/null; then
        info "Deno is not installed, installing now..."
        safe_exec "curl -fsSL https://deno.land/install.sh | sh"
        if [[ $? -ne 0 ]]; then
            error "Failed to install Deno"
        fi
    else
        warn "Deno is already installed"
        return
    fi
}

function install_bun() {
    if ! command -v bun &> /dev/null; then
        info "Bun is not installed, installing now..."
        safe_exec "curl -fsSL https://bun.sh/install | bash"
        if [[ $? -ne 0 ]]; then
            error "Failed to install Bun"
        fi
    else
        warn "Bun is already installed"
        return
    fi
}

function install_fnm() {
    if ! command -v fnm &> /dev/null; then
        info "fnm is not installed, installing now..."
        safe_exec "curl -fsSL https://fnm.vercel.app/install | bash"
        if [[ $? -ne 0 ]]; then
            error "Failed to install fnm"
        fi
    else
        warn "fnm is already installed"
        return
    fi
}

# install pyenv
function install_pyenv() {
    if ! command -v pyenv &> /dev/null; then
        info "pyenv is not installed, installing now..."
        safe_exec "curl -fsSL https://pyenv.run | bash"
        if [[ $? -ne 0 ]]; then
            error "Failed to install pyenv"
        fi
    else
        warn "pyenv is already installed"
        return
    fi
}


ensure_user_bin
info "Installing devtools..."
install_luvit
install_deno
install_bun
install_fnm
#! /usr/bin/env bash
# shellcheck disable=SC2181
set -oue pipefail

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


function install_fnm() {
    info "Installing fnm..."
    url_install https://fnm.vercel.app/install
}

function install_deno() {
    info "Installing deno..."
    safe_exec "curl -fsSL https://deno.land/install.sh | sh"
}

function install_bun() {
    info "Installing bun..."
    url_install https://bun.sh/install
}

function install_luvit() {
    info "Installing luvit..."
    safe_exec "cd /usr/bin && curl -L https://github.com/luvit/lit/raw/master/get-lit.sh | sh"
}

info "Installing devtools..."
install_luvit
## disable deno, bun and fnm for now
#install_deno
#install_bun
#install_fnm
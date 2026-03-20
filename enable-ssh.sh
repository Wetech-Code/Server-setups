#!/usr/bin/env bash

set -euo pipefail

#######################################
# Logging
#######################################

log() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

error() {
    echo "[ERROR] $1" >&2
}

#######################################
# Root Check
#######################################

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error "Please run as root or with sudo"
        exit 1
    fi
}

#######################################
# Validate Port
#######################################

validate_port() {

    local port="$1"

    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        error "Port must be a number"
        exit 1
    fi

    if (( port < 1 || port > 65535 )); then
        error "Port must be between 1 and 65535"
        exit 1
    fi
}

#######################################
# Install SSH
#######################################

install_ssh() {

    if ! dpkg -l | grep -q openssh-server; then

        log "Installing OpenSSH Server..."

        apt-get update
        apt-get install -y openssh-server

    else

        log "OpenSSH already installed"

    fi

}

#######################################
# Configure SSH
#######################################

configure_ssh() {

    local port="$1"

    log "Setting SSH port to $port"

    if grep -q "^#Port" /etc/ssh/sshd_config; then
        sed -i "s/^#Port.*/Port $port/" /etc/ssh/sshd_config
    elif grep -q "^Port" /etc/ssh/sshd_config; then
        sed -i "s/^Port.*/Port $port/" /etc/ssh/sshd_config
    else
        echo "Port $port" >> /etc/ssh/sshd_config
    fi

}

#######################################
# Start SSH
#######################################

start_ssh() {

    log "Enabling and starting SSH service"

    systemctl enable ssh
    systemctl restart ssh

}

#######################################
# Show Status
#######################################

show_status() {

    local port="$1"

    echo
    log "SSH is now running"
    log "Listening on port: $port"

    echo
    echo "Test connection:"
    echo "ssh username@SERVER_IP -p $port"

}

#######################################
# Main
#######################################

main() {

    require_root

    echo
    read -rp "Enter SSH port (default 22): " PORT

    PORT=${PORT:-22}

    validate_port "$PORT"

    install_ssh
    configure_ssh "$PORT"
    start_ssh
    show_status "$PORT"

}

main "$@"
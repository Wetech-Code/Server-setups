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

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error "Run with sudo"
        exit 1
    fi
}

#######################################
# Install Redis if missing
#######################################

install_redis_if_needed() {

    if ! command -v redis-server >/dev/null 2>&1; then

        log "Installing Redis..."

        apt-get update
        apt-get install -y redis

    fi

}

#######################################
# Get Redis services
#######################################

get_services() {

    systemctl list-unit-files \
        | awk '/redis.*service/ {print $1}'
}

#######################################
# Validate port
#######################################

validate_port() {

    local port="$1"

    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        error "Invalid port"
        exit 1
    fi

    if (( port < 1 || port > 65535 )); then
        error "Port out of range"
        exit 1
    fi

    if ss -lnt | grep -q ":$port "; then
        error "Port already in use"
        exit 1
    fi
}

#######################################
# Select service
#######################################

select_service() {

    SERVICES=$(get_services)

    if [[ -z "$SERVICES" ]]; then

        error "No Redis instances found"
        exit 1

    fi

    echo
    echo "Available Redis instances:"
    echo

    select SERVICE in $SERVICES; do

        if [[ -n "$SERVICE" ]]; then
            break
        fi

    done
}

#######################################
# Create new instance
#######################################

create_instance() {

    read -rp "Enter new Redis port: " PORT
    validate_port "$PORT"

    read -rp "Enter username: " USERNAME

    read -rsp "Enter password: " PASSWORD
    echo

    read -rsp "Confirm password: " CONFIRM
    echo

    [[ "$PASSWORD" != "$CONFIRM" ]] && error "Passwords do not match" && exit 1

    CONF="/etc/redis/redis-${PORT}.conf"
    DATA="/var/lib/redis/${PORT}"
    ACL="/etc/redis/users-${PORT}.acl"
    SERVICE="/etc/systemd/system/redis-${PORT}.service"

    mkdir -p "$DATA"

    cp /etc/redis/redis.conf "$CONF"

    sed -i "s/^port .*/port $PORT/" "$CONF"
    sed -i "s|^dir .*|dir $DATA|" "$CONF"

    echo "user default off" > "$ACL"
    echo "user $USERNAME on >$PASSWORD allcommands allkeys" >> "$ACL"

    echo "aclfile $ACL" >> "$CONF"

    chown -R redis:redis "$DATA" "$ACL"

    cat > "$SERVICE" <<EOF
[Unit]
Description=Redis instance on port ${PORT}
After=network.target

[Service]
User=redis
Group=redis
ExecStart=/usr/bin/redis-server ${CONF}
ExecStop=/usr/bin/redis-cli -p ${PORT} shutdown
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable redis-${PORT}
    systemctl start redis-${PORT}

    log "Redis instance created on port $PORT"
}

#######################################
# Change port
#######################################

change_port() {

    select_service

    CONF=$(systemctl show "$SERVICE" \
        | grep ExecStart \
        | sed -n 's/.*redis-server \(.*\.conf\).*/\1/p')

    CURRENT=$(grep "^port " "$CONF" | awk '{print $2}')

    echo "Current port: $CURRENT"

    read -rp "Enter new port: " NEWPORT
    validate_port "$NEWPORT"

    sed -i "s/^port .*/port $NEWPORT/" "$CONF"

    systemctl restart "$SERVICE"

    log "Port updated to $NEWPORT"
}

#######################################
# Change credentials
#######################################

change_credentials() {

    select_service

    CONF=$(systemctl show "$SERVICE" \
        | grep ExecStart \
        | sed -n 's/.*redis-server \(.*\.conf\).*/\1/p')

    ACL=$(grep "^aclfile" "$CONF" | awk '{print $2}')

    read -rp "Enter new username: " USERNAME

    read -rsp "Enter new password: " PASSWORD
    echo

    echo "user default off" > "$ACL"
    echo "user $USERNAME on >$PASSWORD allcommands allkeys" >> "$ACL"

    systemctl restart "$SERVICE"

    log "Credentials updated"
}

#######################################
# Enable all
#######################################

enable_all() {

    for svc in $(get_services)
    do
        systemctl enable "$svc"
        systemctl start "$svc"
    done

    log "All Redis instances enabled"
}

#######################################
# Menu
#######################################

menu() {

    echo
    echo "Redis Management Menu"
    echo
    echo "1) Create NEW Redis instance"
    echo "2) Change port"
    echo "3) Change username/password"
    echo "4) Enable/start all instances"
    echo "5) Exit"
    echo

    read -rp "Select option: " OPTION

    case "$OPTION" in
        1) create_instance ;;
        2) change_port ;;
        3) change_credentials ;;
        4) enable_all ;;
        5) exit 0 ;;
        *) error "Invalid option" ;;
    esac
}

#######################################
# Main
#######################################

main() {

    require_root

    install_redis_if_needed

    menu
}

main
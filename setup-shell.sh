#!/usr/bin/env bash

set -euo pipefail

#######################################
# Detect User
#######################################

USER_NAME="${SUDO_USER:-$USER}"
HOME_DIR=$(eval echo "~$USER_NAME")
FONT_DIR="$HOME_DIR/.local/share/fonts"

log() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "Run with sudo"
        exit 1
    fi
}

#######################################
# Install Base Packages
#######################################

install_packages() {

    log "Installing required packages..."

    apt-get update

    apt-get install -y \
        zsh \
        git \
        curl \
        wget \
        unzip \
        fontconfig

}

#######################################
# Install Oh My Zsh
#######################################

install_ohmyzsh() {

    if [ ! -d "$HOME_DIR/.oh-my-zsh" ]; then

        log "Installing Oh My Zsh..."

        sudo -u "$USER_NAME" sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        "" --unattended

    else

        log "Oh My Zsh already installed"

    fi

}

#######################################
# Install Powerlevel10k
#######################################

install_powerlevel10k() {

    local theme_dir="$HOME_DIR/.oh-my-zsh/custom/themes/powerlevel10k"

    if [ ! -d "$theme_dir" ]; then

        log "Installing Powerlevel10k..."

        sudo -u "$USER_NAME" git clone --depth=1 \
            https://github.com/romkatv/powerlevel10k.git \
            "$theme_dir"

    else

        log "Powerlevel10k already installed"

    fi

}

#######################################
# Install Plugins
#######################################

install_plugins() {

    local plugin_dir="$HOME_DIR/.oh-my-zsh/custom/plugins"

    log "Installing Zsh plugins..."

    if [ ! -d "$plugin_dir/zsh-autosuggestions" ]; then

        sudo -u "$USER_NAME" git clone \
            https://github.com/zsh-users/zsh-autosuggestions \
            "$plugin_dir/zsh-autosuggestions"

    fi

    if [ ! -d "$plugin_dir/zsh-syntax-highlighting" ]; then

        sudo -u "$USER_NAME" git clone \
            https://github.com/zsh-users/zsh-syntax-highlighting \
            "$plugin_dir/zsh-syntax-highlighting"

    fi

}

#######################################
# Configure .zshrc
#######################################

configure_zshrc() {

    ZSHRC="$HOME_DIR/.zshrc"

    log "Configuring theme and plugins..."

    sed -i \
    's|ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' \
    "$ZSHRC"

    sed -i \
    's|plugins=(.*)|plugins=(git zsh-autosuggestions zsh-syntax-highlighting)|' \
    "$ZSHRC"

}

#######################################
# Install Fonts
#######################################

install_fonts() {

    log "Installing Meslo Nerd Fonts..."

    sudo -u "$USER_NAME" mkdir -p "$FONT_DIR"

    for font in \
        "MesloLGS NF Regular.ttf" \
        "MesloLGS NF Bold.ttf" \
        "MesloLGS NF Italic.ttf" \
        "MesloLGS NF Bold Italic.ttf"
    do

        sudo -u "$USER_NAME" wget -q \
            -P "$FONT_DIR" \
            "https://github.com/romkatv/powerlevel10k-media/raw/master/${font// /%20}"

    done

    fc-cache -fv

}

#######################################
# Set Default Shell
#######################################

set_default_shell() {

    log "Setting Zsh as default shell..."

    chsh -s /usr/bin/zsh "$USER_NAME"

}

#######################################
# Main
#######################################

main() {

    require_root

    install_packages
    install_ohmyzsh
    install_powerlevel10k
    install_plugins
    configure_zshrc
    install_fonts
    set_default_shell

    echo
    log "Setup complete"
    echo
    echo "Run:"
    echo
    echo "exec zsh"
    echo
    echo "Then:"
    echo
    echo "p10k configure"

}

main "$@"
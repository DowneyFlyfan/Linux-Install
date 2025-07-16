#!/bin/bash

# End Execution once a single step fails
set -e

log_step() {
    echo ""
    echo "=================================================="
    echo "$1"
    echo "=================================================="
}

initial_setup() {
    log_step "Setting up Basic System"
    sudo apt update
    sudo apt upgrade
    sudo apt install -y firefox ranger fzf curl exfatprogs exfat-fuse openssh-server htop xclip git neovim cuda-toolkit
    sudo apt install -y dust

    # Only for Older Version of Ubuntu
    # log_step "Installing neovim"
    # sudo add-apt-repository -y ppa:deadsnakes/ppa
    # sudo add-apt-repository -y ppa:neovim-ppa/stable
    # sudo apt update
    # sudo snap install nvim --classic
}

configure_shell() {
    log_step "Configuring Shell (~/.bashrc)"
    echo "Updating ~/.bashrc..."

    local bashrc_additions_marker="# Added by init_device.sh"
    if ! grep -Fxq "$bashrc_additions_marker" ~/.bashrc; then
        {
            echo ""
            echo "$bashrc_additions_marker"
            echo 'export PATH="/snap/bin:$PATH"'
            echo 'export PATH="$HOME/Documents/scripts:$PATH"'
            echo 'export PATH="/usr/local/cuda/bin:$PATH"'
            echo 'alias rg="ranger"'
            echo 'alias vi="nvim"'
            echo 'export EDITOR=nvim'
            echo 'export VISUAL=nvim'
            echo 'export VERTEXAI_PROJECT="68996079624"'
            echo 'export VERTEXAI_LOCATION="us-central1"'
            echo 'export http_proxy=http://localhost:7890'
            echo 'export https_proxy=http://localhost:7890'

            echo '# End of additions by init_device.sh'
        } >> ~/.bashrc
        source "$HOME/.bashrc"
        echo "~/.bashrc updated."

    fi
}

setup_scripts() {
    log_step "Setting up User Scripts"

    mv scripts $HOME/Documents
    mv ../Clash $HOME/Documents

    rm -rf $HOME/.config/ranger
    mv ../ranger $HOME/.config

    cd $HOME/Documents/scripts
    ./st
    cd $HOME/Linux-Install/Jetson
}

# === Main Script Execution ===
main() {
    log_step "Please make sure that this script is running under Jetson Directory!"

    initial_setup
    setup_scripts
    configure_shell

    log_step "Main Setup Complete!"
    echo "Now use put the st command into 'startup application'"
    echo "Now set up the proxy in 'Setting' as instructed in Readme.md"
    echo "Clash has to match your system!!!"
}

main

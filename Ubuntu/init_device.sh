#!/bin/bash

# Basics
log_step() {
    echo ""
    echo "=================================================="
    echo "$1"
    echo "=================================================="
}

setup_basic_system() {
    log_step "Setting up Basic System"
    sudo apt update
    sudo apt upgrade
    sudo apt install -y firefox ranger fzf curl exfatprogs exfat-fuse openssh-server htop xclip cuda-toolkit
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo add-apt-repository -y ppa:neovim-ppa/stable # Using stable PPA for Neovim
    sudo apt update
    echo "Installing Neovim..."
    sudo snap install nvim --classic
}

setup_python() {
    log_step "Setting up Python Environment"
    sudo apt install -y python3-pip python3.10-venv
    sudo pip3 install --upgrade pip
    pip3 install matplotlib debugpy aider-chat kornia jtop
    pip3 install torch torchvision torchaudio rotary_embedding_torch
    pip3 install timm h5py PyWavelets ast-grep-cli
    pip3 install kornia
}

setup_C() {
    log_step "Installing C Related Packages"
    wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/llvm-snapshot.gpg

    echo "deb [signed-by=/etc/apt/keyrings/llvm-snapshot.gpg] http://apt.llvm.org/jammy/ llvm-toolchain-jammy main" | sudo tee /etc/apt/sources.list.d/llvm.list
    echo "deb-src [signed-by=/etc/apt/keyrings/llvm-snapshot.gpg] http://apt.llvm.org/jammy/ llvm-toolchain-jammy main" | sudo tee -a /etc/apt/sources.list.d/llvm.list

    sudo apt update
    sudo apt install llvm-20
}

setup_nodejs_env() {
    log_step "Setting up Node.js Environment"
    if ! command -v nvm &> /dev/null; then
        echo "Installing NVM (Node Version Manager)..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    else
        echo "NVM is already installed."
    fi

    export NVM_DIR="$HOME/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        \. "$NVM_DIR/nvm.sh"  # This loads nvm
    fi

    # Source NVM bash_completion
    if [ -s "$NVM_DIR/bash_completion" ]; then
        # shellcheck source=/dev/null
        \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
    fi

    if command -v nvm &> /dev/null; then
        echo "Installing Node.js (latest LTS)..."
        nvm install --lts
        nvm use --lts
        nvm alias default 'lts/*' # Set default node version
        echo "Installing global Node package: tree-sitter-cli..."
        npm install -g tree-sitter-cli
    fi
}

# Input Methods & User Scripts & shell & Python Packages & User Repo
setup_input_method() {
    log_step "Configuring Input Method (fcitx5)"
    sudo apt install -y fcitx5 fcitx5-frontend-gtk3 fcitx5-frontend-qt5 fcitx5-config-qt fcitx5-chinese-addons
    echo "Setting fcitx5 as default input method. This may require a reboot or session restart."
    im-config -n fcitx5
    echo "记得在 设置 fcitx5设置 中 调整快捷键, 在设置中切换Mac键盘"
}

setup_user_scripts() {
    log_step "Setting up User Scripts"

    mv scripts $HOME/Documents
    mv ../Clash $HOME/Documents
    mv ../ranger $HOME/.config

    cd $HOME/Documents
    nohup ./CrashCore -d . > output.log 2>&1 &
    cd $HOME
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
            
            # Adjust it based on your system
            echo 'export PATH="/usr/lib/llvm-20/bin:$PATH"'
            echo 'export PATH="/usr/local/cuda/bin:$PATH"'
            echo 'alias rg="ranger"'
            echo 'alias vi="nvim"'
            echo 'export EDITOR=nvim'
            echo 'export VISUAL=nvim'
            echo 'export VERTEXAI_PROJECT="68996079624"'
            echo 'export VERTEXAI_LOCATION="us-central1"'
            echo '# End of additions by init_device.sh'
        } >> ~/.bashrc
        source "$HOME/.bashrc"
        echo "~/.bashrc updated."
    fi
}

install_conda() {
    log_step "Installing Jetson Specific Python Packages"
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt-get install -y python3-pip libjpeg-dev libpng-dev libtiff-dev

    echo "Installing miniconda3..."
    curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh
    chmod 777 Miniconda3-latest-Linux-aarch64.sh
    rm -rf Miniconda3-latest-Linux-aarch64.sh
    echo "PATH=$HOME/miniconda3/bin:$PATH" >> ~/.bashrc
    source .bashrc
}

clone_configurations() {
    log_step "Cloning Configurations"
    mkdir -p "$HOME/.config"

    local nvim_config_repo_url="https://github.com/DowneyFlyfan/neovim-configuration.git"
    local nvim_config_temp_dir="$HOME/neovim_config_temp"
    echo "Cloning Neovim configuration repository from $nvim_config_repo_url..."
    if git clone "$nvim_config_repo_url" "$nvim_config_temp_dir"; then
        echo "Moving Neovim configuration to $HOME/.config/nvim..."
        mv "$nvim_config_temp_dir" "$HOME/.config/nvim"
    fi
}

# === Main Script Execution ===
main() {
    # System and environment setup
    setup_basic_system
    setup_nodejs_env
    setup_input_method

    # Python
    setup_python
    install_conda

    # Others
    clone_configurations
    install_other_packages
    configure_shell
    setup_user_scripts

    log_step "Setup Complete! Now use put the st command into 'Startup Application'!"
}

main

#!/bin/bash

# End Execution once a single step fails
set -e

log_step() {
    echo ""
    echo "=================================================="
    echo "$1"
    echo "=================================================="
}

setup_nvim(){
    log_step "Cloning neovim configurations"
    mkdir -p "$HOME/.config"

    local nvim_config_repo_url="https://github.com/DowneyFlyfan/neovim-configuration.git"
    local nvim_config_temp_dir="$HOME/neovim_config_temp"
    echo "Cloning Neovim configuration repository from $nvim_config_repo_url..."
    if git clone "$nvim_config_repo_url" "$nvim_config_temp_dir"; then
        echo "Moving Neovim configuration to $HOME/.config/nvim..."
        mv "$nvim_config_temp_dir" "$HOME/.config/nvim"
    fi
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
        \. "$NVM_DIR/bash_completion"
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

setup_conda() {
    log_step "Setting up Python Environment"
    sudo apt install -y python3-pip python3.10-venv
    sudo pip3 install --upgrade pip

    log_step "Installing Jetson Specific Python Packages"
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt-get install -y python3-pip libjpeg-dev libpng-dev libtiff-dev

    log_step "Installing Latest miniconda3 ARM64 Version..."
    curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh
    local miniconda_installer="Miniconda3-latest-Linux-aarch64.sh"
    local miniconda_install_path="$HOME/miniconda3"
    local miniconda_init_script="$miniconda_install_path/etc/profile.d/conda.sh"

    chmod +x "$miniconda_installer"
    "./$miniconda_installer" -b -p "$miniconda_install_path"
    rm -f "$miniconda_installer"

    # Initialize conda in the current shell session
    if [ -f "$miniconda_init_script" ]; then
        . "$miniconda_init_script"
        echo "Conda initialized in current session."
    else
        echo "❌ Conda initialization script not found at $miniconda_init_script"
        echo "Please manually initialize conda after the script finishes."
    fi

    log_step "Initiate Conda Environment..."
    conda create --name hspeedtrack python=3.10
    source $HOME/.bashrc
    conda init
    source $HOME/.bashrc
    conda activate hspeedtrack
}

setup_python(){
    log_step "Please visit https://pypi.jetson-ai-lab.dev/jp6 to see latest version"
    log_step "Installing torch and other python packages in conda env"
    cd $HOME/Downloads
    wget https://pypi.jetson-ai-lab.dev/jp6/cu126/+f/6ef/f643c0a7acda9/torch-2.7.0-cp310-cp310-linux_aarch64.whl#sha256=6eff643c0a7acda92734cc798338f733ff35c7df1a4434576f5ff7c66fc97319
    wget https://pypi.jetson-ai-lab.dev/jp6/cu126/+f/c59/026d500c57366/torchaudio-2.7.0-cp310-cp310-linux_aarch64.whl#sha256=c59026d500c573666ae0437c4202ac312ac8ebe38fa12dbb37250a07c1e826f9
    wget https://pypi.jetson-ai-lab.dev/jp6/cu126/+f/daa/bff3a07259968/torchvision-0.22.0-cp310-cp310-linux_aarch64.whl#sha256=daabff3a0725996886b92e4b5dd143f5750ef4b181b5c7d01371a9185e8f0402
    rm -rf $HOME/.local/lib

    pip install numpy=1.26.4 scipy cupy-cuda12x setuptools pytest pyyaml
    pip install torch-2.7.0-cp310-cp310-linux_aarch64.whl torchvision-0.22.0-cp310-cp310-linux_aarch64.whl torchaudio-2.7.0-cp310-cp310-linux_aarch64.whl
}

setup_others(){
    log_step "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

    log_step "Installing C..."
    wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/llvm-snapshot.gpg

    echo "deb [signed-by=/etc/apt/keyrings/llvm-snapshot.gpg] http://apt.llvm.org/jammy/ llvm-toolchain-jammy main" | sudo tee /etc/apt/sources.list.d/llvm.list
    echo "deb-src [signed-by=/etc/apt/keyrings/llvm-snapshot.gpg] http://apt.llvm.org/jammy/ llvm-toolchain-jammy main" | sudo tee -a /etc/apt/sources.list.d/llvm.list

    sudo apt update
    sudo apt install llvm-20
}

# === Main Script Execution ===
main(){
    log_step "Make sure you manually complete some of the settings required in 'before_vpn' function before executing this function!"
    setup_nvim
    setup_nodejs_env
    setup_conda
    setup_python
    setup_others
}

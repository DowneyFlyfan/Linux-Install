#!/bin/bash

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

    log_step "Creating New Conda Environment..."
    conda create --name track python=3.10
    source $HOME/.bashrc
    conda init
    source $HOME/.bashrc
    conda activate track
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
    sudo pip install jetson-stats
}

setup_others(){
    log_step "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

    log_step "Installing C"
    sudo rm /etc/apt/sources.list.d/llvm.list
    wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/llvm-snapshot.gpg

    echo "deb [signed-by=/etc/apt/keyrings/llvm-snapshot.gpg] http://apt.llvm.org/jammy/ llvm-toolchain-jammy-17 main" | sudo tee /etc/apt/sources.list.d/llvm.list
    echo "deb-src [signed-by=/etc/apt/keyrings/llvm-snapshot.gpg] http://apt.llvm.org/jammy/ llvm-toolchain-jammy-17 main" | sudo tee -a /etc/apt/sources.list.d/llvm.list

    sudo apt update
    sudo apt install llvm-17
}

install_opencv_cuda() {
    log_step "Building and Installing OpenCV CUDA Version, it will take approximately 3 hours!!!! Please refer to https://gist.github.com/minhhieutruong0705/8f0ec70c400420e0007c15c98510f133 ! And switch the opencv version to the desired one if you want"

    OPENCV_VERSION="${OPENCV_VERSION:-4.11.0}"
    echo "Current default OpenCV version is $OPENCV_VERSION."
    read -p "Is this the version you want to install? (y/n): " confirm_version
    if [[ "$confirm_version" != "y" && "$confirm_version" != "Y" ]]; then
        read -p "Please enter the desired OpenCV version (e.g., 4.11.0): " OPENCV_VERSION
        echo "Using OpenCV version: $OPENCV_VERSION"
    fi

    local CUDA_ARCH_BIN_VALUE="8.7"
    echo "Using CUDA_ARCH_BIN: $CUDA_ARCH_BIN_VALUE (Please verify this for your cuda!)"
    if hostname | grep -iq "jetson"; then
        echo "Note: On Jetson, ensure CUDA_ARCH_BIN is correct for your model (e.g., Orin: 8.7, Xavier: 7.2)."
    fi

    log_step "Uninstalling existing OpenCV pip packages and apt versions"
    pip uninstall -y opencv-python opencv-contrib-python opencv-python-headless
    sudo apt-get remove -y python3-opencv

    log_step "Installing OpenCV dependencies"
    sudo apt-get update
    # Core build tools (some might be already installed)
    sudo apt-get install -y build-essential cmake pkg-config unzip yasm git checkinstall
    # Python dev and numpy (ensure system python3 has these for build)
    sudo apt-get install -y python3-dev python3-numpy python3-pip python3-testresources
    # Image I/O
    sudo apt-get install -y libjpeg-dev libpng-dev libtiff-dev
    # Video I/O & GStreamer
    sudo apt-get install -y libavcodec-dev libavformat-dev libswscale-dev libavresample-dev
    sudo apt-get install -y libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
    sudo apt-get install -y libxvidcore-dev x264 libx264-dev libfaac-dev libmp3lame-dev libtheora-dev libvorbis-dev
    # OpenCore AMR
    sudo apt-get install -y libopencore-amrnb-dev libopencore-amrwb-dev
    # Camera interface & V4L
    sudo apt-get install -y libdc1394-dev libxine2-dev libv4l-dev v4l-utils
    # GTK for HighGUI
    sudo apt-get install -y libgtk-3-dev
    # Parallelism & Optimization
    sudo apt-get install -y libtbb-dev libatlas-base-dev gfortran
    # Optional but recommended for full features
    sudo apt-get install -y libprotobuf-dev protobuf-compiler libgoogle-glog-dev libgflags-dev
    sudo apt-get install -y libgphoto2-dev libeigen3-dev libhdf5-dev doxygen

    log_step "Cloning OpenCV and OpenCV_Contrib version $OPENCV_VERSION"
    cd "$HOME" || return 1
    if [ -d "opencv" ]; then
        echo "Directory ~/opencv already exists. Skipping clone."
    else
        git clone https://github.com/opencv/opencv.git
    fi
    if [ -d "opencv_contrib" ]; then
        echo "Directory ~/opencv_contrib already exists. Skipping clone."
    else
        git clone https://github.com/opencv/opencv_contrib.git
    fi

    cd opencv && git checkout "$OPENCV_VERSION" && cd ..
    cd opencv_contrib && git checkout "$OPENCV_VERSION" && cd ..

    conda install -c conda-forge libstdcxx-ng

    log_step "Configuring OpenCV build with CMake"
    mkdir -p "$HOME/opencv_build"
    cd "$HOME/opencv_build" || return 1

    cmake \
        -D CMAKE_BUILD_TYPE=Release \
        -D CMAKE_INSTALL_PREFIX=$HOME/miniconda3/envs/hspeedtrack \
        -D OPENCV_EXTRA_MODULES_PATH=$HOME/opencv_contrib/modules/ \
        -D PYTHON3_EXECUTABLE=$HOME/miniconda3/envs/hspeedtrack/bin/python \
        -D PYTHON3_INCLUDE_DIR=$HOME/miniconda3/envs/hspeedtrack/include/python3.10/ \
        -D PYTHON3_LIBRARY=$HOME/miniconda3/envs/hspeedtrack/lib/libpython3.10.so \
        -D PYTHON3_NUMPY_INCLUDE_DIRS=$HOME/miniconda3/envs/hspeedtrack/lib/python3.10/site-packages/numpy/core/include/ \
        -D OPENCV_GENERATE_PKGCONFIG=ON \
        -D OPENCV_PC_FILE_NAME=opencv.pc \
        -D OPENCV_ENABLE_NONFREE=ON \
        -D WITH_CUDA=ON \
        -D WITH_CUDNN=ON \
        -D OPENCV_DNN_CUDA=ON \
        -D CUDA_ARCH_BIN=8.7 \
        -D ENABLE_FAST_MATH=ON \
        -D CUDA_FAST_MATH=ON \
        -D WITH_CUFFT=ON \
        -D WITH_CUBLAS=ON \
        -D WITH_V4L=ON \
        -D WITH_OPENCL=ON \
        -D WITH_OPENGL=ON \
        -D WITH_GSTREAMER=ON \
        -D WITH_TBB=ON \
        ../opencv

    log_step "Compiling OpenCV (this will take a very long time...)"
    make -j $(nproc)

    log_step "Installing OpenCV"
    make install

    log_step "OpenCV Testing"
    source "$HOME/.bashrc"
    conda activate hspeedtrack
    cd "$HOME/Linux-Install/Jetson" || return 1
    pytest test_opencv.py
}

# === Main Script Execution ===
main(){
    log_step "Make sure you manually complete some of the settings required in 'before_vpn' function before executing this function!"
    setup_nvim
    setup_nodejs_env
    setup_conda
    setup_python
    setup_others
    install_opencv_cuda
}

main

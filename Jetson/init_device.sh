#!/bin/bash

OPENCV_VERSION="${OPENCV_VERSION:-4.9.0}"

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
    sudo apt install -y firefox ranger fzf curl exfatprogs exfat-fuse openssh-server htop xclip
}

setup_python_env() {
    log_step "Setting up Python Environment"
    sudo apt install -y python3-pip python3.10-venv
    sudo pip3 install --upgrade pip
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

add_ppas_and_install_extras() {
    log_step "Adding PPAs and Installing Additional Packages"
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo add-apt-repository -y ppa:neovim-ppa/stable # Using stable PPA for Neovim
    sudo apt update
    echo "Installing Neovim..."
    sudo snap install nvim --classic
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

install_conda_packages() {
    log_step "Installing Jetson Specific Python Packages"
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt-get install -y python3-pip libjpeg-dev libpng-dev libtiff-dev

    echo "Installing miniconda3..."
    curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh
    chmod 777 Miniconda3-latest-Linux-aarch64.sh
    rm -rf Miniconda3-latest-Linux-aarch64.sh
    echo "PATH=$HOME/miniconda3/bin:$PATH" >> ~/.bashrc
    source .bashrc

    echo "Into Conda Environment..."
    conda create --name Track python=3.10
    conda init
    source .bashrc
    conda activate Track

    echo "Installing torch, torchvision and torchaudio (CUDA 12.2)"
    curl -O https://nvidia.box.com/shared/static/mp164asf3sceb570wvjsrezk1p4ftj8t.whl
    curl -O https://nvidia.box.com/shared/static/9agsjfee0my4sxckdpuk9x9gt8agvjje.whl
    curl -O https://nvidia.box.com/shared/static/xpr06qe6ql3l6rj22cu3c45tz1wzi36p.whl
    
    pip install torch-2.3.0-cp310-cp310-linux_aarch64.whl torchaudio-2.3.0+952ea74-cp310-cp310-linux_aarch64.whl torchvision-0.18.0a0+6043bc2-cp310-cp310-linux_aarch64.whl
    echo "Installing other packages"
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

# opencv_GPU
install_opencv_gpu() {
    conda activate Track
    echo "Please refer to https://gist.github.com/minhhieutruong0705/8f0ec70c400420e0007c15c98510f133"
    log_step "Building and Installing OpenCV CUDA Version, it will take approximately 3 hours!!!!"

    local CUDA_ARCH_BIN_VALUE="8.7"
    echo "Using CUDA_ARCH_BIN: $CUDA_ARCH_BIN_VALUE (Please verify this for your GPU!)"
    if hostname | grep -iq "jetson"; then
        echo "Note: On Jetson, ensure CUDA_ARCH_BIN is correct for your model (e.g., Orin: 8.7, Xavier: 7.2)."
    fi

    log_step "Uninstalling existing OpenCV pip packages and apt versions"
    pip3 uninstall -y opencv-python opencv-contrib-python opencv-python-headless
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

    log_step "Configuring OpenCV build with CMake"
    mkdir -p "$HOME/opencv_build"
    cd "$HOME/opencv_build" || return 1

    cmake \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_INSTALL_PREFIX=$HOME/miniconda3/envs/Track \
    -D OPENCV_EXTRA_MODULES_PATH=~/opencv_contrib/modules/ \
    -D PYTHON3_EXECUTABLE=$HOME/miniconda3/envs/Track/bin/python \
    -D PYTHON3_INCLUDE_DIR=$HOME/miniconda3/envs/Track/include/python3.10/ \
    -D PYTHON3_LIBRARY=$HOME/miniconda3/envs/Track/lib/libpython3.10.so \
    -D PYTHON3_NUMPY_INCLUDE_DIRS=$HOME/miniconda3/envs/Track/lib/python3.10/site-packages/numpy/_core/include/ \
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

    conda install -c conda-forge libstdcxx-ng

    log_step "Compiling OpenCV (this may take a very long time...)"
    make -j $(nproc)

    log_step "Installing OpenCV"
    sudo make install

    log_step "Updating library cache"
    sudo ldconfig

    log_step "OpenCV Installation Complete"
    echo "OpenCV Python bindings should be available at $PYTHON3_PACKAGES_PATH"
    echo "Verifying installation by trying to import cv2 in Python..."
    if $PYTHON_EXECUTABLE -c "import cv2; print(f'OpenCV version: {cv2.__version__}')"; then
        echo "OpenCV successfully imported."
    else
        echo "Failed to import cv2. You might need to add $PYTHON3_PACKAGES_PATH to your PYTHONPATH."
    fi
}

# === Main Script Execution ===
main() {
    local install_python_packages_choice="N"
    local install_opencv_choice="N"

    local is_jetson_system=false

    if hostname | grep -iq "jetson"; then
        is_jetson_system=true
    fi

    if ! $is_jetson_system; then
        read -p "Do you want to install Base Python packages? (y/N): " install_python_packages_choice
    fi

    read -p "Do you want to build and install OpenCV ${OPENCV_VERSION} from source with CUDA support? (This can take a very long time) (y/N): " install_opencv_choice
    
    cat /etc/nv_tegra_release
}
main

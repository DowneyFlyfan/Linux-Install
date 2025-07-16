#!/bin/bash

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
    sudo apt install -y firefox ranger fzf curl exfatprogs exfat-fuse openssh-server htop
    sudo apt install -y ccache gnome-tweaks xclip linuxqq

    log_step "Installing neovim"
    sudo add-apt-repository -y ppa:neovim-ppa/stable
    sudo apt update
    sudo snap install nvim --classic
    sudo snap install chromium

    log_step "Configuring Input Method (fcitx5)"
    sudo apt install -y fcitx5 fcitx5-frontend-gtk3 fcitx5-frontend-qt5 fcitx5-config-qt fcitx5-chinese-addons
    im-config -n fcitx5
    log_step "记得重启, 并在fcitx5设置中调整快捷键, 在设置中切换Mac键盘"
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
            echo 'alias rg=". ranger"'
            echo 'alias vi="nvim"'
            echo 'export EDITOR=nvim'
            echo 'export VISUAL=nvim'
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

set_static_wifi_ip() {
    echo "Attempting to set a static IP based on current WiFi connection..."

    ACTIVE_WIFI_DEVICE=$(nmcli -t -f DEVICE,TYPE,STATE dev status | grep -E 'wifi:connected|wireless:connected' | cut -d':' -f1 | head -n1) # Added wireless for broader compatibility
    if [ -z "$ACTIVE_WIFI_DEVICE" ]; then
        echo "ERROR: No active WiFi device found."
        return 1
    fi
    echo "INFO: Active WiFi device: $ACTIVE_WIFI_DEVICE"

    # Get the connection name associated with this device
    # -g for get-value
    CON_NAME=$(nmcli -g GENERAL.CONNECTION dev show "$ACTIVE_WIFI_DEVICE")
    if [ -z "$CON_NAME" ]; then
        echo "ERROR: Could not determine connection name for $ACTIVE_WIFI_DEVICE."
        return 1
    fi
    echo "INFO: Active WiFi connection name: \"$CON_NAME\"" # Quoted for clarity if name has spaces

    # Get current IP address with prefix (e.g., 192.168.1.100/24)
    # Takes the first IP if multiple are assigned (e.g., IP4.ADDRESS[1])
    STATIC_IP_WITH_PREFIX=$(nmcli -g IP4.ADDRESS dev show "$ACTIVE_WIFI_DEVICE" | head -n1)
    if [ -z "$STATIC_IP_WITH_PREFIX" ]; then
        echo "ERROR: Could not determine current IP address for $ACTIVE_WIFI_DEVICE."
        return 1
    fi
    echo "INFO: Current IP to be set as static: $STATIC_IP_WITH_PREFIX"

    # Get current gateway
    GATEWAY=$(nmcli -g IP4.GATEWAY dev show "$ACTIVE_WIFI_DEVICE")
    if [ -z "$GATEWAY" ]; then
        echo "ERROR: Could not determine current Gateway for $ACTIVE_WIFI_DEVICE."
        # For some specific network configurations, a gateway might not be present.
        # For typical WiFi internet access, it is required.
        return 1
    fi
    echo "INFO: Current Gateway: $GATEWAY"

    # Get current DNS servers, comma-separated
    # nmcli -g IP4.DNS dev show "$ACTIVE_WIFI_DEVICE" returns DNS servers, one per line, e.g., "IP4.DNS[1]: 8.8.8.8"
    # We need to extract "8.8.8.8" and join multiple entries with commas.
    DNS_SERVERS_RAW=$(nmcli -g IP4.DNS dev show "$ACTIVE_WIFI_DEVICE")
    if [ -z "$DNS_SERVERS_RAW" ]; then
        echo "WARNING: Could not determine DNS servers. Static IP will be set without specific DNS servers."
        DNS_OPTION_COMMAND="ipv4.dns \"\"" # Explicitly set to no DNS
        DNS_SERVERS_DISPLAY="Not set"
    else
        # Process raw DNS entries: remove "IP4.DNS[n]: " prefix, then join with commas
        DNS_SERVERS=$(echo "$DNS_SERVERS_RAW" | sed 's/IP4\.DNS\[[0-9]*\]:\s*//g' | tr '\n' ',' | sed 's/,$//')
        echo "INFO: Current DNS Servers: $DNS_SERVERS"
        DNS_OPTION_COMMAND="ipv4.dns \"$DNS_SERVERS\""
        DNS_SERVERS_DISPLAY="$DNS_SERVERS"
    fi

    echo # Blank line for readability
    echo "-----------------------------------------------------"
    echo "The following settings will be applied to connection \"$CON_NAME\":"
    echo "  Method:     manual"
    echo "  IP Address: $STATIC_IP_WITH_PREFIX"
    echo "  Gateway:    $GATEWAY"
    echo "  DNS Servers: $DNS_SERVERS_DISPLAY"
    echo "-----------------------------------------------------"
    echo # Blank line

    read -r -p "Proceed with setting static IP? (y/N) " confirmation
    if [[ ! "$confirmation" =~ ^[Yy]([Ee][Ss])?$ ]]; then # Accept y, Y, yes, YES
        echo "Operation cancelled by user."
        return 1
    fi

    echo "INFO: Setting static IP for \"$CON_NAME\"..."
    sudo nmcli con mod "$CON_NAME" ipv4.method manual ipv4.addresses "$STATIC_IP_WITH_PREFIX" ipv4.gateway "$GATEWAY" $DNS_OPTION_COMMAND

    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to modify connection \"$CON_NAME\"."
        return 1
    fi

    echo "INFO: Re-activating connection \"$CON_NAME\"..."
    # It's good practice to bring it down then up for settings to take full effect.
    # Using 'nmcli c up' directly after 'mod' sometimes works but down/up is more reliable.
    if sudo nmcli con down "$CON_NAME" && sudo nmcli con up "$CON_NAME"; then
        echo "INFO: Static IP configuration applied successfully."
        echo "INFO: Current IP for \"$CON_NAME\" on device $ACTIVE_WIFI_DEVICE:"
        nmcli dev show "$ACTIVE_WIFI_DEVICE" | grep IP4.ADDRESS
    else
        echo "ERROR: Failed to re-activate connection \"$CON_NAME\"."
        echo "INFO: Settings were modified, but the connection might be down or in an unexpected state."
        echo "INFO: Try: sudo nmcli con up \"$CON_NAME\""
        echo "INFO: Or check: nmcli dev status"
        return 1
    fi

    echo # Blank line
    echo "INFO: To revert \"$CON_NAME\" to DHCP (automatic IP):"
    echo "      sudo nmcli con mod \"$CON_NAME\" ipv4.method auto ipv4.addresses \"\" ipv4.gateway \"\" ipv4.dns \"\" && sudo nmcli con down \"$CON_NAME\" && sudo nmcli con up \"$CON_NAME\""
    return 0
}

# === Main Script Execution ===
main() {
    log_step "Please make sure that this script is running under Jetson Directory!"

    initial_setup
    setup_scripts
    configure_shell
    set_static_wifi_ip

    cat /etc/nv_tegra_release
    log_step "Main Setup Complete!"
    echo "Now use put the st command into 'startup application'"
    echo "Now set up the proxy in 'Setting' as instructed in Readme.md"
}

main

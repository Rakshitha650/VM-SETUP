#!/bin/bash

# Check for required arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <VNC_USERNAME> <VNC_PASSWORD>"
    exit 1
fi

VNC_USERNAME=$1
VNC_PASSWORD=$2

# Log file setup
LOG_FILE="/tmp/performance-vm-$(date +"%d-%b-%Y-%H-%M").log"
echo "[ Log File ]: $LOG_FILE"

# Redirect stdout and stderr to log file
exec > >(tee -a "$LOG_FILE") 2>&1

# Strict error handling
set -euo pipefail
trap 'echo "[ERROR] Script failed at line $LINENO."' ERR

# Detect user home directory
USER_HOME=$(eval echo "~$VNC_USERNAME")

echo "[ VNC User ]: $VNC_USERNAME"
echo "[ User Home Directory ]: $USER_HOME"

# Ensure the user exists
if ! id "$VNC_USERNAME" &>/dev/null; then
    echo "User '$VNC_USERNAME' does not exist. Creating..."
    sudo useradd -m -s /bin/bash "$VNC_USERNAME"
    echo "$VNC_USERNAME:$VNC_PASSWORD" | sudo chpasswd
fi

# Update system
echo "[ Updating System Packages ]"
sudo apt update -y && sudo apt upgrade -y

# Install required packages
echo "[ Installing Required Packages ]"
sudo apt install -y openjdk-11-jdk wireguard tightvncserver xfce4 xfce4-goodies ufw wget

# Enable IP forwarding for WireGuard
echo "[ Enabling IP Forwarding ]"
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Setup VNC
echo "[ Setting up VNC ]"
sudo -u "$VNC_USERNAME" mkdir -p "$USER_HOME/.vnc"
echo "$VNC_PASSWORD" | sudo -u "$VNC_USERNAME" vncpasswd -f > "$USER_HOME/.vnc/passwd"
sudo chmod 600 "$USER_HOME/.vnc/passwd"
sudo chown -R "$VNC_USERNAME:$VNC_USERNAME" "$USER_HOME/.vnc"

# Configure VNC startup
echo "[ Configuring VNC xstartup Script ]"
VNC_STARTUP="$USER_HOME/.vnc/xstartup"
sudo tee "$VNC_STARTUP" > /dev/null <<EOF
#!/bin/bash
xrdb \$HOME/.Xresources
startxfce4 &
EOF
sudo chmod +x "$VNC_STARTUP"
sudo chown "$VNC_USERNAME:$VNC_USERNAME" "$VNC_STARTUP"

# Start and verify VNC
echo "[ Starting VNC Server ]"
sudo -u "$VNC_USERNAME" vncserver :1 || echo "Initial VNC start failed"
sleep 5
sudo -u "$VNC_USERNAME" vncserver -kill :1 || true
sudo -u "$VNC_USERNAME" vncserver :1

# Configure Firewall
echo "[ Configuring Firewall ]"
sudo ufw allow 22/tcp     # SSH
sudo ufw allow 80/tcp     # HTTP
sudo ufw allow 443/tcp    # HTTPS
sudo ufw allow 5901/tcp   # VNC
sudo ufw --force enable

# Install JProfiler 13
echo "[ Installing JProfiler 13 ]"
JPROFILER_VERSION="13_0_1"
JPROFILER_URL="https://download.ej-technologies.com/jprofiler/jprofiler_linux_${JPROFILER_VERSION}.tar.gz"
JPROFILER_DIR="/opt/jprofiler13"

if [ ! -f "$JPROFILER_DIR/bin/jprofiler" ]; then
    wget -O /tmp/jprofiler.tar.gz "$JPROFILER_URL"
    sudo mkdir -p "$JPROFILER_DIR"
    sudo tar -xvzf /tmp/jprofiler.tar.gz -C "$JPROFILER_DIR" --strip-components=1
    sudo ln -sf "$JPROFILER_DIR/bin/jprofiler" /usr/local/bin/jprofiler
    rm -f /tmp/jprofiler.tar.gz
fi

# Verify installed packages
echo "[ Verifying Installed Packages ]"
REQUIRED_PKGS=("openjdk-11-jdk" "wireguard" "tightvncserver" "xfce4" "ufw" "wget")
for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! dpkg -l | grep -q "$pkg"; then
        echo "Package $pkg is missing. Reinstalling..."
        sudo apt install -y "$pkg"
    fi
done

echo "[ ✔ Installation and Configuration Completed Successfully ]"

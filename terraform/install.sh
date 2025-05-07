#!/bin/bash

# Usage check
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <VNC_USERNAME> <VNC_PASSWORD>"
    exit 1
fi

VNC_USERNAME=$1
VNC_PASSWORD=$2

# Log setup
LOG_FILE="/tmp/performance-vm-$(date +"%d-%b-%Y-%H-%M").log"
echo "[ Log File ]: $LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

# Strict error handling
set -euo pipefail
trap 'echo "[ERROR] Script failed at line $LINENO."' ERR

# Determine user home
USER_HOME=$(eval echo "~$VNC_USERNAME")
echo "[ VNC User ]: $VNC_USERNAME"
echo "[ User Home Directory ]: $USER_HOME"

# Create user if missing
if ! id "$VNC_USERNAME" &>/dev/null; then
    echo "[ Creating user '$VNC_USERNAME' ]"
    sudo useradd -m -s /bin/bash "$VNC_USERNAME"
    echo "$VNC_USERNAME:$VNC_PASSWORD" | sudo chpasswd
fi

# System update
echo "[ Updating System Packages ]"
sudo apt update -y && sudo apt upgrade -y

# Install required software
echo "[ Installing Required Packages ]"
sudo apt install -y openjdk-11-jdk wireguard tightvncserver xfce4 xfce4-goodies ufw wget

# Enable IP forwarding
echo "[ Enabling IP Forwarding for WireGuard ]"
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Set up VNC directory and password
echo "[ Configuring VNC ]"
sudo -u "$VNC_USERNAME" mkdir -p "$USER_HOME/.vnc"
echo "$VNC_PASSWORD" | sudo -u "$VNC_USERNAME" vncpasswd -f > "$USER_HOME/.vnc/passwd"
sudo chmod 600 "$USER_HOME/.vnc/passwd"
sudo chown -R "$VNC_USERNAME:$VNC_USERNAME" "$USER_HOME/.vnc"

# Create VNC startup script
echo "[ Creating VNC xstartup Script ]"
VNC_STARTUP="$USER_HOME/.vnc/xstartup"
sudo tee "$VNC_STARTUP" > /dev/null <<EOF
#!/bin/bash
xrdb \$HOME/.Xresources
startxfce4 &
EOF

sudo chmod +x "$VNC_STARTUP"
sudo chown "$VNC_USERNAME:$VNC_USERNAME" "$VNC_STARTUP"

# Start VNC
echo "[ Starting VNC Server for '$VNC_USERNAME' ]"
sudo -u "$VNC_USERNAME" vncserver :1 || echo "[WARN] First-time VNC start may fail (expected)"
sleep 5
sudo -u "$VNC_USERNAME" vncserver -kill :1 || true
sudo -u "$VNC_USERNAME" vncserver :1

# UFW firewall setup
echo "[ Configuring Firewall ]"
sudo ufw allow 22/tcp     # SSH
sudo ufw allow 80/tcp     # HTTP
sudo ufw allow 443/tcp    # HTTPS
sudo ufw allow 5901/tcp   # VNC
sudo ufw --force enable

# Install JProfiler
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
else
    echo "[ JProfiler already installed ]"
fi

# Verify installations
echo "[ Verifying Installed Packages ]"
REQUIRED_PKGS=("openjdk-11-jdk" "wireguard" "tightvncserver" "xfce4" "ufw" "wget")
for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! dpkg -l | grep -q "$pkg"; then
        echo "[WARN] Package '$pkg' is missing. Attempting reinstallation..."
        sudo apt install -y "$pkg"
    fi
done

echo "[ ✔ Installation and Configuration Completed Successfully for user '$VNC_USERNAME' ]"

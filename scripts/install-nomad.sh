#!/bin/bash
set -e

NOMAD_VERSION="${nomad_version}"

echo "Installing Nomad version $NOMAD_VERSION..."

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        NOMAD_ARCH="amd64"
        ;;
    aarch64|arm64)
        NOMAD_ARCH="arm64"
        ;;
    armv7l)
        NOMAD_ARCH="arm"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Download Nomad
echo "Downloading Nomad for $NOMAD_ARCH..."
cd /tmp
curl -sLO "https://releases.hashicorp.com/nomad/$${NOMAD_VERSION}/nomad_$${NOMAD_VERSION}_linux_$${NOMAD_ARCH}.zip"

# Install unzip if not present
if ! command -v unzip &> /dev/null; then
    echo "Installing unzip..."
    apt-get update && apt-get install -y unzip || yum install -y unzip
fi

# Extract and install
echo "Installing Nomad binary..."
unzip -o "nomad_$${NOMAD_VERSION}_linux_$${NOMAD_ARCH}.zip"
chmod +x nomad
mv nomad /usr/local/bin/
rm "nomad_$${NOMAD_VERSION}_linux_$${NOMAD_ARCH}.zip"

# Verify installation
nomad version

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || true
        echo "deb [arch=$NOMAD_ARCH signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null || true
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io
    elif [ -f /etc/redhat-release ]; then
        # RHEL/CentOS
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io
    fi

    systemctl enable docker
    systemctl start docker
    echo "Docker installation complete!"
else
    echo "Docker is already installed."
fi

# Create nomad user if it doesn't exist
if ! id -u nomad &> /dev/null; then
    echo "Creating nomad user..."
    useradd --system --home /etc/nomad.d --shell /bin/false nomad
fi

# Add nomad user to docker group
usermod -aG docker nomad || true

# Create directories
echo "Creating Nomad directories..."
mkdir -p /opt/nomad
mkdir -p /etc/nomad.d
chown -R nomad:nomad /opt/nomad
chown -R nomad:nomad /etc/nomad.d

# Create systemd service file
echo "Creating Nomad systemd service..."
cat > /etc/systemd/system/nomad.service <<'EOF'
[Unit]
Description=Nomad Agent
Documentation=https://www.nomadproject.io/docs
Requires=network-online.target
After=network-online.target

[Service]
Type=simple
User=nomad
Group=nomad
ExecStart=/usr/local/bin/nomad agent -config=/etc/nomad.d
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=2
LimitNOFILE=65536
LimitNPROC=infinity

[Install]
WantedBy=multi-user.target
EOF

echo "Nomad installation complete!"

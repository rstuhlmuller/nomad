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

# Install Nomad using HashiCorp's official repository
if [ -f /etc/debian_version ]; then
    # Debian/Ubuntu - use apt
    echo "Setting up HashiCorp repository for Debian/Ubuntu..."
    apt-get update
    apt-get install -y wget gpg coreutils lsb-release

    # Add HashiCorp GPG key
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

    # Add HashiCorp repository
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

    # Install Nomad
    apt-get update
    apt-get install -y nomad=$NOMAD_VERSION-*

elif [ -f /etc/redhat-release ]; then
    # RHEL/CentOS - use yum
    echo "Setting up HashiCorp repository for RHEL/CentOS..."
    yum install -y yum-utils
    yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
    yum install -y nomad-$NOMAD_VERSION
else
    echo "Unsupported distribution"
    exit 1
fi

# Verify installation
nomad version

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    if [ -f /etc/debian_version ]; then
        # Clean up any existing Docker repo files to avoid conflicts
        rm -f /etc/apt/sources.list.d/docker.list

        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

        # Detect OS - check for Debian or Ubuntu
        if [ -f /etc/os-release ]; then
            . /etc/os-release
        fi

        # Map architecture for Docker
        DOCKER_ARCH=$NOMAD_ARCH

        # Determine which repository to use
        if grep -qi debian /etc/os-release 2>/dev/null || [ "$ID" = "debian" ]; then
            echo "Detected Debian system..."
            DOCKER_REPO="debian"
            VERSION_CODENAME=$(lsb_release -cs)

            # For Debian trixie (testing) or sid, fall back to bookworm (latest stable)
            if [ "$VERSION_CODENAME" = "trixie" ] || [ "$VERSION_CODENAME" = "sid" ]; then
                echo "Debian $VERSION_CODENAME detected, using bookworm repository..."
                VERSION_CODENAME="bookworm"
            fi

            curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor --batch --yes -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$DOCKER_ARCH signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $VERSION_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        elif grep -qi ubuntu /etc/os-release 2>/dev/null || [ "$ID" = "ubuntu" ]; then
            echo "Detected Ubuntu system..."
            DOCKER_REPO="ubuntu"
            VERSION_CODENAME=$(lsb_release -cs)

            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --batch --yes -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$DOCKER_ARCH signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        else
            echo "Error: Unable to detect Debian or Ubuntu"
            exit 1
        fi

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

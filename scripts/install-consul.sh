#!/bin/bash
set -e

CONSUL_VERSION="${consul_version}"

echo "Installing Consul version $CONSUL_VERSION..."

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        CONSUL_ARCH="amd64"
        ;;
    aarch64|arm64)
        CONSUL_ARCH="arm64"
        ;;
    armv7l)
        CONSUL_ARCH="arm"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Download Consul
echo "Downloading Consul for $CONSUL_ARCH..."
cd /tmp
curl -sLO "https://releases.hashicorp.com/consul/$${CONSUL_VERSION}/consul_$${CONSUL_VERSION}_linux_$${CONSUL_ARCH}.zip"

# Install unzip if not present
if ! command -v unzip &> /dev/null; then
    echo "Installing unzip..."
    apt-get update && apt-get install -y unzip || yum install -y unzip
fi

# Extract and install
echo "Installing Consul binary..."
unzip -o "consul_$${CONSUL_VERSION}_linux_$${CONSUL_ARCH}.zip"
chmod +x consul
mv consul /usr/local/bin/
rm "consul_$${CONSUL_VERSION}_linux_$${CONSUL_ARCH}.zip"

# Verify installation
consul version

# Create consul user if it doesn't exist
if ! id -u consul &> /dev/null; then
    echo "Creating consul user..."
    useradd --system --home /etc/consul.d --shell /bin/false consul
fi

# Create directories
echo "Creating Consul directories..."
mkdir -p /opt/consul
mkdir -p /etc/consul.d
chown -R consul:consul /opt/consul
chown -R consul:consul /etc/consul.d

# Create systemd service file
echo "Creating Consul systemd service..."
cat > /etc/systemd/system/consul.service <<'EOF'
[Unit]
Description=Consul Agent
Documentation=https://www.consul.io/docs
Requires=network-online.target
After=network-online.target

[Service]
Type=notify
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

echo "Consul installation complete!"

#!/bin/bash
set -e

echo "=========================================="
echo "Nomad + Consul Cluster Bootstrap Script"
echo "=========================================="
echo ""

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "Error: Terraform is not installed!"
    echo "Please install Terraform from https://www.terraform.io/downloads"
    exit 1
fi

# Check SSH connectivity
echo "Checking SSH connectivity to cluster nodes..."
SERVERS=("10.1.0.200" "10.1.0.201" "10.1.0.202")
SSH_USER="${SSH_USER:-themanofrod}"

for server in "${SERVERS[@]}"; do
    echo -n "Testing connection to $server... "
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$SSH_USER@$server" "echo 'OK'" &> /dev/null; then
        echo "Success"
    else
        echo "Failed!"
        echo "Error: Cannot connect to $server via SSH"
        echo "Please ensure:"
        echo "  1. SSH key is configured (~/.ssh/id_rsa)"
        echo "  2. User $SSH_USER has sudo access"
        echo "  3. Node is reachable"
        exit 1
    fi
done

echo ""
echo "All connectivity checks passed!"
echo ""

# Navigate to terraform directory
cd "$(dirname "$0")/../terraform"

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

echo ""
echo "Ready to deploy cluster!"
echo ""
echo "Next steps:"
echo "  1. Review the plan: terraform plan"
echo "  2. Apply changes: terraform apply"
echo ""
echo "After deployment, verify with:"
echo "  - Consul: ssh $SSH_USER@10.1.0.200 'consul members'"
echo "  - Nomad:  ssh $SSH_USER@10.1.0.200 'nomad server members'"
echo ""
echo "Access UIs at:"
echo "  - Consul: http://10.1.0.200:8500"
echo "  - Nomad:  http://10.1.0.200:4646"

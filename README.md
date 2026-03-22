# Homelab - Nomad + Consul Cluster

This repository contains Terraform configuration for deploying a highly available Nomad and Consul cluster across 3 nodes.

## Architecture

- **3 Consul Servers**: Service discovery, health checks, and KV store
- **3 Nomad Servers**: Job scheduling and orchestration
- **3 Nomad Clients**: Job execution (co-located with servers)
- **Integrated**: Nomad uses Consul for service discovery and registration

## Cluster Nodes

- `10.1.0.200` (zimaboard-0) - Server + Client
- `10.1.0.201` - Server + Client
- `10.1.0.202` - Server + Client

## Prerequisites

Before deployment, ensure:

1. **SSH Access**: Password-less SSH to all nodes as user `themanofrod`
   ```bash
   ssh-copy-id themanofrod@10.1.0.200
   ssh-copy-id themanofrod@10.1.0.201
   ssh-copy-id themanofrod@10.1.0.202
   ```

2. **Passwordless Sudo**: User has passwordless sudo privileges on all nodes
   ```bash
   # Configure passwordless sudo on all nodes
   for ip in 10.1.0.200 10.1.0.201 10.1.0.202; do
     ssh themanofrod@$ip "echo 'themanofrod ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/themanofrod && sudo chmod 0440 /etc/sudoers.d/themanofrod"
   done

   # Verify it works
   for ip in 10.1.0.200 10.1.0.201 10.1.0.202; do
     ssh themanofrod@$ip "sudo echo 'OK on $ip'"
   done
   ```

3. **Network Connectivity**: Required ports are open:
   - **Consul**: 8300, 8301, 8302, 8500, 8600
   - **Nomad**: 4646, 4647, 4648

4. **Terraform**: Installed locally
   ```bash
   terraform version  # Should be >= 1.0
   ```

5. **Internet Access**: Nodes can download Consul and Nomad binaries

## Quick Start

### 1. Bootstrap Check

Run the bootstrap script to verify prerequisites:

```bash
chmod +x scripts/bootstrap.sh
./scripts/bootstrap.sh
```

### 2. Deploy Cluster

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

The deployment will:
- Install Consul on all 3 nodes
- Install Nomad on all 3 nodes
- Configure services and start them
- Wait for cluster formation

### 3. Verify Deployment

Check Consul cluster:
```bash
ssh themanofrod@10.1.0.200 'consul members'
ssh themanofrod@10.1.0.200 'consul operator raft list-peers'
```

Check Nomad cluster:
```bash
ssh themanofrod@10.1.0.200 'nomad server members'
ssh themanofrod@10.1.0.200 'nomad node status'
```

## Access UIs

- **Consul UI**: http://10.1.0.200:8500
- **Nomad UI**: http://10.1.0.200:4646

## Testing

### Test Docker Driver

Deploy a test nginx job:

```bash
ssh themanofrod@10.1.0.200
nomad job run /path/to/test-docker.nomad
nomad job status test-docker
```

Or from your local machine (after setting up Nomad CLI):

```bash
export NOMAD_ADDR=http://10.1.0.200:4646
nomad job run test-docker.nomad
nomad job status test-docker
```

### Test Raw Exec Driver

```bash
nomad job run test-raw-exec.nomad
nomad job status test-raw-exec
nomad alloc logs <allocation-id>
```

## Configuration

### Variables

Customize deployment by editing `terraform/variables.tf` or creating `terraform.tfvars`:

```hcl
server_ips              = ["10.1.0.200", "10.1.0.201", "10.1.0.202"]
ssh_user                = "themanofrod"
consul_version          = "1.19.0"
nomad_version           = "1.8.1"
datacenter              = "homelab"
region                  = "global"
ssh_private_key_path    = "~/.ssh/id_rsa"
```

### Updating Configuration

After modifying Consul or Nomad configuration templates:

```bash
cd terraform
terraform apply
```

Terraform will detect changes and restart services as needed.

## Management

### View Logs

On any node:

```bash
# Consul logs
sudo journalctl -u consul -f

# Nomad logs
sudo journalctl -u nomad -f
```

### Restart Services

```bash
sudo systemctl restart consul
sudo systemctl restart nomad
```

### Stop Cluster

```bash
cd terraform
terraform destroy
```

This will:
- Stop all services
- Remove binaries and configuration
- Clean up directories

## Troubleshooting

For detailed troubleshooting steps and solutions to common issues, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

Common issues covered:
- **Terraform hangs during apply** - Passwordless sudo not configured
- **Consul cluster not forming** - Network or firewall issues
- **Nomad cluster not starting** - Consul dependency issues
- **Jobs not running** - Resource constraints or Docker issues
- **Cannot access UIs** - Firewall or binding issues
- **Complete cluster reset** - Start fresh procedure

Quick checks:

```bash
# Check service status
for ip in 10.1.0.200 10.1.0.201 10.1.0.202; do
  echo "=== $ip ==="
  ssh themanofrod@$ip "sudo systemctl status consul nomad"
done

# Check cluster health
ssh themanofrod@10.1.0.200 "consul members && nomad server members && nomad node status"
```

## Directory Structure

```
homelab/
├── terraform/
│   ├── main.tf                    # Main orchestration
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Outputs (URLs, IPs)
│   ├── providers.tf               # Provider configuration
│   └── modules/
│       ├── consul/
│       │   ├── main.tf           # Consul installation
│       │   ├── variables.tf
│       │   └── templates/
│       │       └── consul.hcl.tpl # Consul config template
│       └── nomad/
│           ├── main.tf           # Nomad installation
│           ├── variables.tf
│           └── templates/
│               └── nomad.hcl.tpl  # Nomad config template
├── scripts/
│   ├── install-consul.sh          # Consul installation script
│   ├── install-nomad.sh           # Nomad installation script
│   └── bootstrap.sh               # Prerequisites check
├── test-docker.nomad              # Docker driver test job
├── test-raw-exec.nomad            # Raw exec driver test job
└── README.md                      # This file
```

## Security Considerations

Current setup is for development/homelab use. For production:

1. **Enable Consul ACLs**:
   ```bash
   consul acl bootstrap
   ```

2. **Enable Nomad ACLs**:
   ```bash
   nomad acl bootstrap
   ```

3. **Configure mTLS** between Consul and Nomad

4. **Set up firewall rules** to restrict access

5. **Integrate HashiCorp Vault** for secrets management

## Next Steps

- [ ] Enable Consul ACLs
- [ ] Enable Nomad ACLs
- [ ] Deploy Traefik as ingress controller
- [ ] Set up monitoring (Prometheus/Grafana)
- [ ] Configure automatic backups
- [ ] Integrate with Vault

## Resources

- [Consul Documentation](https://www.consul.io/docs)
- [Nomad Documentation](https://www.nomadproject.io/docs)
- [Nomad Job Specification](https://www.nomadproject.io/docs/job-specification)
- [Consul Service Discovery](https://www.consul.io/docs/discovery/services)

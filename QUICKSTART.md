# Quick Start Guide

## Prerequisites Check

```bash
# 1. Verify SSH access to all nodes
ssh themanofrod@10.1.0.200 "echo 'Node 1 OK'"
ssh themanofrod@10.1.0.201 "echo 'Node 2 OK'"
ssh themanofrod@10.1.0.202 "echo 'Node 3 OK'"

# 2. Configure passwordless sudo (will prompt for password once per node)
for ip in 10.1.0.200 10.1.0.201 10.1.0.202; do
  ssh themanofrod@$ip "echo 'themanofrod ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/themanofrod && sudo chmod 0440 /etc/sudoers.d/themanofrod"
done

# 3. Verify passwordless sudo (should NOT prompt for password)
for ip in 10.1.0.200 10.1.0.201 10.1.0.202; do
  ssh themanofrod@$ip "sudo echo 'OK on $ip'"
done

# 4. Run bootstrap script
./scripts/bootstrap.sh
```

## Deploy Cluster

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Expected output will show Consul and Nomad being installed on all 3 nodes.

## Verify Cluster

```bash
# Check Consul
ssh themanofrod@10.1.0.200 'consul members'

# Check Nomad
ssh themanofrod@10.1.0.200 'nomad server members'
ssh themanofrod@10.1.0.200 'nomad node status'
```

## Access Web UIs

- Consul: http://10.1.0.200:8500
- Nomad: http://10.1.0.200:4646

## Deploy Test Job

```bash
# Option 1: SSH to node
ssh themanofrod@10.1.0.200
nomad job run /tmp/test-docker.nomad

# Option 2: Remote CLI (set NOMAD_ADDR first)
export NOMAD_ADDR=http://10.1.0.200:4646
nomad job run test-docker.nomad
nomad job status test-docker
```

## Common Commands

```bash
# Consul
consul members                    # Show cluster members
consul catalog services           # List registered services
consul kv put test/key value      # Write to KV store
consul kv get test/key            # Read from KV store

# Nomad
nomad server members              # Show server members
nomad node status                 # Show client nodes
nomad job run <file>              # Run a job
nomad job status <job-name>       # Check job status
nomad alloc logs <alloc-id>       # View allocation logs
nomad job stop <job-name>         # Stop a job
```

## Troubleshooting

### Cluster not forming?

```bash
# Check logs
sudo journalctl -u consul -f
sudo journalctl -u nomad -f

# Restart services
sudo systemctl restart consul
sudo systemctl restart nomad
```

### Job not running?

```bash
# Check node status
nomad node status -verbose

# Check job details
nomad job status -verbose <job-name>

# View allocation logs
nomad alloc logs <allocation-id>
```

## Clean Up

```bash
cd terraform
terraform destroy
```

# Troubleshooting Guide

Common issues and their solutions when deploying the Nomad + Consul cluster.

## Terraform Hangs During Apply

### Symptom
Terraform apply runs for 20+ minutes showing:
```
module.consul.null_resource.install_consul[X] (remote-exec): [sudo] password for themanofrod:
```

### Cause
Passwordless sudo is not configured. The installation scripts run `sudo` commands but cannot prompt for a password in a non-interactive SSH session.

### Solution
1. **Cancel Terraform:**
   ```bash
   # Press Ctrl+C in the terraform terminal (may need twice)
   ```

2. **Configure passwordless sudo on all nodes:**
   ```bash
   for ip in 10.1.0.200 10.1.0.201 10.1.0.202; do
     ssh themanofrod@$ip "echo 'themanofrod ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/themanofrod && sudo chmod 0440 /etc/sudoers.d/themanofrod"
   done
   ```

3. **Verify it works (should not prompt for password):**
   ```bash
   for ip in 10.1.0.200 10.1.0.201 10.1.0.202; do
     ssh themanofrod@$ip "sudo echo 'OK on $ip'"
   done
   ```

4. **Clean up stuck processes:**
   ```bash
   for ip in 10.1.0.200 10.1.0.201 10.1.0.202; do
     ssh themanofrod@$ip "sudo pkill -9 -f 'install-consul.sh|install-nomad.sh' || true"
   done
   ```

5. **Retry deployment:**
   ```bash
   cd terraform
   terraform apply
   ```

### Prevention
Always run `./scripts/bootstrap.sh` before deployment - it now checks for passwordless sudo.

---

## SSH Connection Refused

### Symptom
```
Error: Cannot connect to 10.1.0.X via SSH
```

### Solutions

**Check SSH service is running:**
```bash
# On the target node
sudo systemctl status sshd
```

**Verify SSH key is configured:**
```bash
# From your local machine
ssh-copy-id themanofrod@10.1.0.200
```

**Test connection manually:**
```bash
ssh -v themanofrod@10.1.0.200
```

**Check firewall rules:**
```bash
# On the target node
sudo iptables -L -n | grep 22
```

---

## Consul Cluster Not Forming

### Symptom
```bash
consul members
# Shows only 1 node or no nodes
```

### Diagnosis

1. **Check Consul status on all nodes:**
   ```bash
   for ip in 10.1.0.200 10.1.0.201 10.1.0.202; do
     echo "=== $ip ==="
     ssh themanofrod@$ip "sudo systemctl status consul"
   done
   ```

2. **Check Consul logs:**
   ```bash
   ssh themanofrod@10.1.0.200 "sudo journalctl -u consul -n 50"
   ```

3. **Verify configuration:**
   ```bash
   ssh themanofrod@10.1.0.200 "cat /etc/consul.d/consul.hcl"
   ```

### Common Causes

**Firewall blocking ports:**
```bash
# On each node, verify these ports are open
sudo ss -tlnp | grep -E '(8300|8301|8302|8500|8600)'
```

**Network connectivity issues:**
```bash
# From each node, test connectivity to other nodes
for ip in 10.1.0.200 10.1.0.201 10.1.0.202; do
  nc -zv $ip 8301
done
```

**Mismatched datacenter:**
```bash
# Check datacenter configuration matches on all nodes
grep datacenter /etc/consul.d/consul.hcl
```

### Solutions

**Restart Consul on all nodes:**
```bash
for ip in 10.1.0.200 10.1.0.201 10.1.0.202; do
  ssh themanofrod@$ip "sudo systemctl restart consul"
done

# Wait 10 seconds then check
sleep 10
ssh themanofrod@10.1.0.200 "consul members"
```

**Clear data and restart (CAUTION: loses all Consul data):**
```bash
for ip in 10.1.0.200 10.1.0.201 10.1.0.202; do
  ssh themanofrod@$ip "sudo systemctl stop consul && sudo rm -rf /opt/consul/* && sudo systemctl start consul"
done
```

---

## Nomad Cluster Not Forming

### Symptom
```bash
nomad server members
# Shows only 1 server or error
```

### Diagnosis

1. **Check Nomad status:**
   ```bash
   for ip in 10.1.0.200 10.1.0.201 10.1.0.202; do
     echo "=== $ip ==="
     ssh themanofrod@$ip "sudo systemctl status nomad"
   done
   ```

2. **Check Nomad logs:**
   ```bash
   ssh themanofrod@10.1.0.200 "sudo journalctl -u nomad -n 50"
   ```

3. **Verify Consul is healthy first:**
   ```bash
   ssh themanofrod@10.1.0.200 "consul members"
   ```
   Nomad requires Consul to be running and healthy.

### Solutions

**Ensure Consul is running:**
```bash
# Nomad depends on Consul
for ip in 10.1.0.200 10.1.0.201 10.1.0.202; do
  ssh themanofrod@$ip "sudo systemctl status consul"
done
```

**Restart Nomad on all nodes:**
```bash
for ip in 10.1.0.200 10.1.0.201 10.1.0.202; do
  ssh themanofrod@$ip "sudo systemctl restart nomad"
done

# Wait 15 seconds then check
sleep 15
ssh themanofrod@10.1.0.200 "nomad server members"
```

---

## Nomad Clients Not Ready

### Symptom
```bash
nomad node status
# Shows nodes with status other than "ready"
```

### Diagnosis

1. **Check client logs:**
   ```bash
   ssh themanofrod@10.1.0.200 "sudo journalctl -u nomad | grep -i client"
   ```

2. **Check Docker status:**
   ```bash
   for ip in 10.1.0.200 10.1.0.201 10.1.0.202; do
     echo "=== $ip ==="
     ssh themanofrod@$ip "sudo systemctl status docker"
   done
   ```

3. **Verify client configuration:**
   ```bash
   ssh themanofrod@10.1.0.200 "cat /etc/nomad.d/nomad.hcl | grep -A 10 client"
   ```

### Solutions

**Start Docker if not running:**
```bash
for ip in 10.1.0.200 10.1.0.201 10.1.0.202; do
  ssh themanofrod@$ip "sudo systemctl enable --now docker"
done
```

**Restart Nomad clients:**
```bash
for ip in 10.1.0.200 10.1.0.201 10.1.0.202; do
  ssh themanofrod@$ip "sudo systemctl restart nomad"
done
```

---

## Jobs Not Running

### Symptom
```bash
nomad job status my-job
# Shows allocations failed or pending
```

### Diagnosis

1. **Check job status details:**
   ```bash
   nomad job status -verbose my-job
   ```

2. **Check allocation status:**
   ```bash
   nomad alloc status <allocation-id>
   ```

3. **View allocation logs:**
   ```bash
   nomad alloc logs <allocation-id>
   ```

4. **Check node eligibility:**
   ```bash
   nomad node status
   # All nodes should show "ready" and "eligible"
   ```

### Common Issues

**No eligible nodes:**
```bash
# Check node status
nomad node status -verbose

# Make node eligible if ineligible
nomad node eligibility -enable <node-id>
```

**Resource constraints:**
```bash
# Check node resources
nomad node status <node-id>

# Reduce job resource requirements in job file
```

**Docker image pull failure:**
```bash
# Check allocation logs for pull errors
nomad alloc logs <allocation-id>

# Test Docker pull manually on a node
ssh themanofrod@10.1.0.200 "sudo docker pull nginx:alpine"
```

**Port conflicts:**
```bash
# If using static ports, check they're available
ssh themanofrod@10.1.0.200 "sudo ss -tlnp | grep <port>"
```

---

## Cannot Access UIs

### Symptom
Cannot reach http://10.1.0.200:8500 or http://10.1.0.200:4646

### Solutions

**Check services are running:**
```bash
ssh themanofrod@10.1.0.200 "sudo systemctl status consul nomad"
```

**Verify ports are listening:**
```bash
ssh themanofrod@10.1.0.200 "sudo ss -tlnp | grep -E '(8500|4646)'"
```

**Test from server itself:**
```bash
ssh themanofrod@10.1.0.200 "curl -s http://localhost:8500/v1/status/leader"
ssh themanofrod@10.1.0.200 "curl -s http://localhost:4646/v1/status/leader"
```

**Check firewall:**
```bash
# Temporarily disable firewall to test (Ubuntu/Debian)
ssh themanofrod@10.1.0.200 "sudo ufw status"
ssh themanofrod@10.1.0.200 "sudo ufw allow 8500/tcp && sudo ufw allow 4646/tcp"
```

**Check bind address in configuration:**
```bash
# Consul should have client_addr = "0.0.0.0"
ssh themanofrod@10.1.0.200 "grep client_addr /etc/consul.d/consul.hcl"

# Nomad should have bind_addr = "0.0.0.0"
ssh themanofrod@10.1.0.200 "grep bind_addr /etc/nomad.d/nomad.hcl"
```

---

## Terraform State Locked

### Symptom
```
Error: Error acquiring the state lock
```

### Solution

If you're sure no other Terraform process is running:

```bash
cd terraform
terraform force-unlock <lock-id>
```

---

## Complete Cluster Reset

If you need to start completely fresh:

```bash
# 1. Destroy via Terraform (if possible)
cd terraform
terraform destroy

# 2. Manual cleanup on all nodes
for ip in 10.1.0.200 10.1.0.201 10.1.0.202; do
  ssh themanofrod@$ip "sudo systemctl stop nomad consul || true"
  ssh themanofrod@$ip "sudo systemctl disable nomad consul || true"
  ssh themanofrod@$ip "sudo rm -rf /opt/consul /opt/nomad /etc/consul.d /etc/nomad.d"
  ssh themanofrod@$ip "sudo rm -f /usr/local/bin/consul /usr/local/bin/nomad"
  ssh themanofrod@$ip "sudo rm -f /etc/systemd/system/consul.service /etc/systemd/system/nomad.service"
  ssh themanofrod@$ip "sudo systemctl daemon-reload"
  ssh themanofrod@$ip "sudo userdel -r consul || true"
  ssh themanofrod@$ip "sudo userdel -r nomad || true"
done

# 3. Clean local Terraform state
cd terraform
rm -rf .terraform* terraform.tfstate*

# 4. Start fresh
terraform init
terraform apply
```

---

## Getting Help

If you encounter issues not covered here:

1. **Check logs:**
   - Consul: `sudo journalctl -u consul -f`
   - Nomad: `sudo journalctl -u nomad -f`

2. **Verify configuration:**
   - Consul: `/etc/consul.d/consul.hcl`
   - Nomad: `/etc/nomad.d/nomad.hcl`

3. **Check network connectivity:**
   - Between nodes: `nc -zv <ip> <port>`
   - DNS resolution: `dig <hostname>`

4. **Review documentation:**
   - [Consul Docs](https://www.consul.io/docs)
   - [Nomad Docs](https://www.nomadproject.io/docs)

5. **Enable debug logging:**
   ```bash
   # Edit service configuration
   sudo systemctl edit consul
   # Add: Environment="CONSUL_LOG_LEVEL=DEBUG"

   sudo systemctl edit nomad
   # Add: Environment="NOMAD_LOG_LEVEL=DEBUG"

   sudo systemctl restart consul nomad
   ```

# Deployment Checklist

Use this checklist to ensure a smooth deployment of the Nomad + Consul cluster.

## Pre-Deployment

- [ ] **SSH Access Configured**
  ```bash
  ssh themanofrod@10.1.0.200 "echo OK"
  ssh themanofrod@10.1.0.201 "echo OK"
  ssh themanofrod@10.1.0.202 "echo OK"
  ```

- [ ] **Sudo Access Verified**
  ```bash
  ssh themanofrod@10.1.0.200 "sudo echo OK"
  ```

- [ ] **Terraform Installed**
  ```bash
  terraform version  # Should be >= 1.0
  ```

- [ ] **Network Ports Available**
  - Consul: 8300, 8301, 8302, 8500, 8600
  - Nomad: 4646, 4647, 4648

- [ ] **Internet Connectivity**
  - Nodes can reach releases.hashicorp.com
  - Nodes can reach download.docker.com

- [ ] **Review Variables** in `terraform/variables.tf`
  - Server IPs correct
  - SSH user correct
  - Versions appropriate

## Deployment

- [ ] **Run Bootstrap Script**
  ```bash
  ./scripts/bootstrap.sh
  ```

- [ ] **Initialize Terraform**
  ```bash
  cd terraform
  terraform init
  ```

- [ ] **Review Plan**
  ```bash
  terraform plan
  ```
  - Should show 6 null_resources (3 Consul + 3 Nomad)
  - Should show 2 wait resources

- [ ] **Apply Configuration**
  ```bash
  terraform apply
  ```
  - Confirm with 'yes'
  - Wait for completion (5-10 minutes)

## Post-Deployment Verification

- [ ] **Verify Consul Cluster**
  ```bash
  ssh themanofrod@10.1.0.200 'consul members'
  ```
  - Should show 3 nodes, all 'alive', all 'server'

- [ ] **Verify Consul Raft**
  ```bash
  ssh themanofrod@10.1.0.200 'consul operator raft list-peers'
  ```
  - Should show 3 peers
  - One should be marked as leader

- [ ] **Verify Nomad Servers**
  ```bash
  ssh themanofrod@10.1.0.200 'nomad server members'
  ```
  - Should show 3 servers, all 'alive'
  - One should be marked as leader

- [ ] **Verify Nomad Clients**
  ```bash
  ssh themanofrod@10.1.0.200 'nomad node status'
  ```
  - Should show 3 nodes, all 'ready'

- [ ] **Access Consul UI**
  - Open http://10.1.0.200:8500
  - Should see 3 nodes in Services tab
  - Should see cluster status

- [ ] **Access Nomad UI**
  - Open http://10.1.0.200:4646
  - Should see 3 servers, 3 clients
  - Should see cluster status

## Testing

- [ ] **Test Docker Driver**
  ```bash
  export NOMAD_ADDR=http://10.1.0.200:4646
  nomad job run test-docker.nomad
  nomad job status test-docker
  ```
  - Job should reach 'running' status
  - Should see 3 allocations

- [ ] **Test Raw Exec Driver**
  ```bash
  nomad job run test-raw-exec.nomad
  nomad job status test-raw-exec
  ```
  - Job should complete successfully

- [ ] **Test Service Discovery**
  ```bash
  ssh themanofrod@10.1.0.200 'consul catalog services'
  ```
  - Should see 'test-nginx' service if Docker job is running

- [ ] **View Allocation Logs**
  ```bash
  nomad alloc logs <allocation-id>
  ```
  - Should see nginx logs

- [ ] **Clean Up Test Jobs**
  ```bash
  nomad job stop test-docker
  nomad job stop test-raw-exec
  ```

## Troubleshooting Steps

If any checks fail:

### Consul Issues

- [ ] Check Consul logs
  ```bash
  ssh themanofrod@10.1.0.200 'sudo journalctl -u consul -n 100'
  ```

- [ ] Verify Consul config
  ```bash
  ssh themanofrod@10.1.0.200 'cat /etc/consul.d/consul.hcl'
  ```

- [ ] Restart Consul
  ```bash
  ssh themanofrod@10.1.0.200 'sudo systemctl restart consul'
  ```

### Nomad Issues

- [ ] Check Nomad logs
  ```bash
  ssh themanofrod@10.1.0.200 'sudo journalctl -u nomad -n 100'
  ```

- [ ] Verify Nomad config
  ```bash
  ssh themanofrod@10.1.0.200 'cat /etc/nomad.d/nomad.hcl'
  ```

- [ ] Verify Docker is running
  ```bash
  ssh themanofrod@10.1.0.200 'sudo systemctl status docker'
  ```

- [ ] Restart Nomad
  ```bash
  ssh themanofrod@10.1.0.200 'sudo systemctl restart nomad'
  ```

### Network Issues

- [ ] Check firewall rules
  ```bash
  ssh themanofrod@10.1.0.200 'sudo iptables -L -n'
  ```

- [ ] Test port connectivity
  ```bash
  nc -zv 10.1.0.200 8500
  nc -zv 10.1.0.200 4646
  ```

## Rollback Procedure

If deployment fails and needs rollback:

- [ ] **Stop All Services**
  ```bash
  for ip in 10.1.0.200 10.1.0.201 10.1.0.202; do
    ssh themanofrod@$ip 'sudo systemctl stop nomad consul'
  done
  ```

- [ ] **Destroy Terraform Resources**
  ```bash
  cd terraform
  terraform destroy
  ```

- [ ] **Clean Up Manually (if needed)**
  ```bash
  for ip in 10.1.0.200 10.1.0.201 10.1.0.202; do
    ssh themanofrod@$ip 'sudo rm -rf /opt/consul /opt/nomad /etc/consul.d /etc/nomad.d'
    ssh themanofrod@$ip 'sudo rm /usr/local/bin/consul /usr/local/bin/nomad'
    ssh themanofrod@$ip 'sudo userdel consul nomad' || true
  done
  ```

## Success Criteria

Deployment is successful when:

- ✅ All 3 Consul nodes are alive and in cluster
- ✅ Consul has elected a leader
- ✅ All 3 Nomad servers are alive and in cluster
- ✅ Nomad has elected a leader
- ✅ All 3 Nomad clients are ready
- ✅ Both UIs are accessible
- ✅ Test Docker job runs successfully
- ✅ Services are registered in Consul

## Next Steps After Deployment

- [ ] Enable Consul ACLs (see README.md Security section)
- [ ] Enable Nomad ACLs
- [ ] Set up monitoring
- [ ] Configure backups
- [ ] Deploy production workloads

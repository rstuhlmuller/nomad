datacenter = "${datacenter}"
node_name  = "${node_name}"
data_dir   = "/opt/consul"

# Server configuration
server           = true
bootstrap_expect = 3

# Network configuration
bind_addr   = "${node_ip}"
client_addr = "0.0.0.0"
advertise_addr = "${node_ip}"

# Cluster joining
retry_join = ${retry_join}

# UI configuration
ui_config {
  enabled = true
}

# Performance tuning
performance {
  raft_multiplier = 1
}

# Logging
log_level = "INFO"
enable_syslog = false

# Enable script checks
enable_script_checks = true

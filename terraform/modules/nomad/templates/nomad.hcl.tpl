datacenter = "${datacenter}"
region     = "${region}"
name       = "${node_name}"
data_dir   = "/opt/nomad"

# Bind to all interfaces
bind_addr = "0.0.0.0"

# Advertise specific IP
advertise {
  http = "${node_ip}"
  rpc  = "${node_ip}"
  serf = "${node_ip}"
}

# Server configuration
server {
  enabled          = true
  bootstrap_expect = 3

  server_join {
    retry_join = ${retry_join}
    retry_max  = 3
    retry_interval = "15s"
  }
}

# Client configuration
client {
  enabled = true

  servers = ${retry_join}

  # Node metadata
  meta {
    "node_type" = "server-client"
  }

  # Host volumes for container storage
  host_volume "docker-sock" {
    path      = "/var/run/docker.sock"
    read_only = false
  }
}

# Docker driver configuration
plugin "docker" {
  config {
    allow_privileged = true

    volumes {
      enabled = true
    }

    allow_caps = ["ALL"]
  }
}

# Raw exec driver configuration
plugin "raw_exec" {
  config {
    enabled = true
  }
}

# Consul integration
consul {
  address             = "127.0.0.1:8500"
  auto_advertise      = true
  server_auto_join    = true
  client_auto_join    = true
  server_service_name = "nomad"
  client_service_name = "nomad-client"
}

# Telemetry
telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
}

# Logging
log_level = "INFO"
enable_syslog = false

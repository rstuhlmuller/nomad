variable "server_ips" {
  description = "List of server IP addresses"
  type        = list(string)
}

variable "ssh_user" {
  description = "SSH user for remote connections"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key"
  type        = string
}

variable "nomad_version" {
  description = "Nomad version to install"
  type        = string
}

variable "datacenter" {
  description = "Datacenter name"
  type        = string
}

variable "region" {
  description = "Region name"
  type        = string
}

variable "retry_join" {
  description = "JSON encoded list of server IPs for retry_join"
  type        = string
}

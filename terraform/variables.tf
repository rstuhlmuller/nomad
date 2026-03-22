variable "server_ips" {
  description = "List of server IP addresses"
  type        = list(string)
  default     = ["10.1.0.200", "10.1.0.201", "10.1.0.202"]
}

variable "ssh_user" {
  description = "SSH user for remote connections"
  type        = string
  default     = "themanofrod"
}

variable "consul_version" {
  description = "Consul version to install"
  type        = string
  default     = "1.19.0"
}

variable "nomad_version" {
  description = "Nomad version to install"
  type        = string
  default     = "1.8.1"
}

variable "datacenter" {
  description = "Datacenter name"
  type        = string
  default     = "homelab"
}

variable "region" {
  description = "Nomad region name"
  type        = string
  default     = "global"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_rsa"
}

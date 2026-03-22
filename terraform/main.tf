locals {
  retry_join = jsonencode(var.server_ips)
}

module "consul" {
  source = "./modules/consul"

  server_ips              = var.server_ips
  ssh_user                = var.ssh_user
  ssh_private_key_path    = var.ssh_private_key_path
  consul_version          = var.consul_version
  datacenter              = var.datacenter
  retry_join              = local.retry_join
}

module "nomad" {
  source = "./modules/nomad"

  server_ips              = var.server_ips
  ssh_user                = var.ssh_user
  ssh_private_key_path    = var.ssh_private_key_path
  nomad_version           = var.nomad_version
  datacenter              = var.datacenter
  region                  = var.region
  retry_join              = local.retry_join

  depends_on = [module.consul]
}

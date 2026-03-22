resource "null_resource" "install_consul" {
  count = length(var.server_ips)

  connection {
    type        = "ssh"
    host        = var.server_ips[count.index]
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/consul.hcl.tpl", {
      datacenter  = var.datacenter
      node_ip     = var.server_ips[count.index]
      retry_join  = var.retry_join
      node_name   = "consul-${count.index}"
    })
    destination = "/tmp/consul.hcl"
  }

  provisioner "file" {
    content = templatefile("${path.root}/../scripts/install-consul.sh", {
      consul_version = var.consul_version
    })
    destination = "/tmp/install-consul.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-consul.sh",
      "sudo /tmp/install-consul.sh",
      "sudo mv /tmp/consul.hcl /etc/consul.d/consul.hcl",
      "sudo chown -R consul:consul /etc/consul.d",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable consul",
      "sudo systemctl restart consul"
    ]
  }

  triggers = {
    consul_config = templatefile("${path.module}/templates/consul.hcl.tpl", {
      datacenter  = var.datacenter
      node_ip     = var.server_ips[count.index]
      retry_join  = var.retry_join
      node_name   = "consul-${count.index}"
    })
    consul_version = var.consul_version
  }
}

resource "null_resource" "wait_for_consul_cluster" {
  depends_on = [null_resource.install_consul]

  connection {
    type        = "ssh"
    host        = var.server_ips[0]
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for Consul cluster to form...'",
      "sleep 10",
      "for i in {1..30}; do",
      "  if consul members | grep -q 'alive'; then",
      "    MEMBER_COUNT=$(consul members | grep -c 'alive')",
      "    if [ $MEMBER_COUNT -eq ${length(var.server_ips)} ]; then",
      "      echo 'Consul cluster formed successfully'",
      "      consul members",
      "      exit 0",
      "    fi",
      "  fi",
      "  echo \"Waiting for cluster... (attempt $i/30)\"",
      "  sleep 5",
      "done",
      "echo 'Warning: Consul cluster may not be fully formed'",
      "consul members || true"
    ]
  }
}

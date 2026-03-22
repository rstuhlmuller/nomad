resource "null_resource" "install_nomad" {
  count = length(var.server_ips)

  connection {
    type        = "ssh"
    host        = var.server_ips[count.index]
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/nomad.hcl.tpl", {
      datacenter  = var.datacenter
      region      = var.region
      node_ip     = var.server_ips[count.index]
      retry_join  = var.retry_join
      node_name   = "nomad-${count.index}"
    })
    destination = "/tmp/nomad.hcl"
  }

  provisioner "file" {
    content = templatefile("${path.root}/../scripts/install-nomad.sh", {
      nomad_version = var.nomad_version
    })
    destination = "/tmp/install-nomad.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-nomad.sh",
      "sudo /tmp/install-nomad.sh",
      "sudo mv /tmp/nomad.hcl /etc/nomad.d/nomad.hcl",
      "sudo chown -R nomad:nomad /etc/nomad.d",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable nomad",
      "sudo systemctl restart nomad"
    ]
  }

  triggers = {
    nomad_config = templatefile("${path.module}/templates/nomad.hcl.tpl", {
      datacenter  = var.datacenter
      region      = var.region
      node_ip     = var.server_ips[count.index]
      retry_join  = var.retry_join
      node_name   = "nomad-${count.index}"
    })
    nomad_version = var.nomad_version
  }
}

resource "null_resource" "wait_for_nomad_cluster" {
  depends_on = [null_resource.install_nomad]

  connection {
    type        = "ssh"
    host        = var.server_ips[0]
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for Nomad cluster to form...'",
      "sleep 15",
      "for i in {1..30}; do",
      "  if nomad server members 2>/dev/null | grep -q 'alive'; then",
      "    SERVER_COUNT=$(nomad server members 2>/dev/null | grep -c 'alive')",
      "    if [ $SERVER_COUNT -eq ${length(var.server_ips)} ]; then",
      "      echo 'Nomad servers formed successfully'",
      "      nomad server members",
      "      echo ''",
      "      echo 'Checking Nomad clients...'",
      "      nomad node status",
      "      exit 0",
      "    fi",
      "  fi",
      "  echo \"Waiting for cluster... (attempt $i/30)\"",
      "  sleep 5",
      "done",
      "echo 'Warning: Nomad cluster may not be fully formed'",
      "nomad server members 2>/dev/null || true",
      "nomad node status 2>/dev/null || true"
    ]
  }
}

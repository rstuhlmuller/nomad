job "test-raw-exec" {
  datacenters = ["homelab"]
  type        = "batch"

  group "hello" {
    count = 1

    task "hello-world" {
      driver = "raw_exec"

      config {
        command = "/bin/bash"
        args    = ["-c", "echo 'Hello from raw_exec driver!' && sleep 10"]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}

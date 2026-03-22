job "test-docker" {
  datacenters = ["homelab"]
  type        = "service"

  group "web" {
    count = 3

    network {
      port "http" {
        static = 8080
      }
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "nginx:alpine"
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 128
      }

      service {
        name     = "test-nginx"
        port     = "http"
        provider = "consul"

        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}

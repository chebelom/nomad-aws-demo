job "whoami" {
  datacenters = ["dc1"]

  type = "service"

  group "demo" {
    count = 2

    network {
       port "http" {
         to = 80
       }
    }

    service {
      name = "whoami-demo"
      port = "http"
      provider = "nomad"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.http.rule=Path(`/whoami`)",
      ]
    }

    task "server" {
      env {
        WHOAMI_PORT_NUMBER = "${NOMAD_PORT_http}"
      }

      driver = "docker"

      config {
        image = "traefik/whoami"
        ports = ["http"]
      }
    }
  }
}
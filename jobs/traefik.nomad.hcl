job "traefik" {
    datacenters = ["dc1"]

    type = "system"

    group "traefik" {

        network {
            mode = "host"
            port "http" { 
              static = 80
              to = 80
            }
            port "api" {
              static = 8080
              to = 8080
            }
            port "ping" {
              static = 8082
              to = 8082
            }
            port "metrics" {
              static = 8083
              to = 8083
            }
        }

        service {
            provider = "nomad"
            port = "http"
            name = "traefik"
            tags =["traefik", "demo"]
        }

        service {
            provider = "nomad"
            name = "traefik-admin"
            port = "api"
        }


    task "traefik" {
      driver = "docker"

      config {
        image = "traefik"
        args = ["--configFile=local/traefik.toml"]
        ports = ["http", "api", "ping", "metrics"]
      }



      template {
        destination = "local/traefik.toml"
        data = <<-DATA
        [api]
        insecure = true
        dashboard = true
        debug = true

        [entryPoints]
            [entryPoints.http]
                address =  ":80"
            [entryPoints.ping]
                address =  ":8082"
            [entryPoints.metrics]
                address = ":8083"

        [providers]
            [providers.nomad]
                [providers.nomad.endpoint]
                    address = "http://{{ env "attr.unique.network.ip-address" }}:4646"
        
        [metrics]
            [metrics.prometheus]
                entryPoint = "metrics"
        
        [accessLog]

        DATA
      }


      resources {
        cpu    = 250
        memory = 100
      }  
    }
  }
}
job "dp-adot-collector-lb" {
  datacenters = ["eu-west-2"]
  region      = "eu"
  type        = "service"
  priority    = 90

  constraint {
    distinct_hosts = true
  }

  group "web" {
    count = "{{WEB_TASK_COUNT}}"

    constraint {
      attribute = "${node.class}"
      operator  = "regexp"
      value     = "web.*"
    }

    restart {
      attempts = 3
      delay    = "15s"
      interval = "1m"
      mode     = "delay"
    }

    network {
      port "grpc" {
        static = 4317
        to     = 4317
      }
      port "health" {
        to = 13133
      }
    }

    service {
      name = "dp-adot-collector-lb-grpc-web"
      port = "grpc"
      tags = ["web","otel-collector"]

      check {
        type     = "http"
        port     = "health"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "dp-adot-collector-lb-web" {
      driver = "docker"

      config {
        image = "{{ECR_URL}}:concourse-{{REVISION}}"
        ports = ["grpc","health"]
      }

      resources {
        cpu    = "{{WEB_RESOURCE_CPU}}"
        memory = "{{WEB_RESOURCE_MEM}}"
      }

      template {
        data = <<EOH
        # Configs based on environment (e.g. export BIND_ADDR=":{{ env "NOMAD_PORT_http" }}")
        # or static (e.g. export BIND_ADDR=":8080")

        # Secret configs read from vault
        {{ with (secret (print "secret/" (env "NOMAD_TASK_NAME"))) }}
        {{ range $key, $value := .Data }}
        export {{ $key }}="{{ $value }}"
        {{ end }}
        {{ end }}
        EOH

        destination = "secrets/app.env"
        env         = true
        splay       = "1m"
        change_mode = "restart"
      }

      vault {
        policies = ["dp-adot-collector-lb-web"]
      }
    }
  }

  group "publishing" {
    count = "{{PUBLISHING_TASK_COUNT}}"

    constraint {
      attribute = "${node.class}"
      operator  = "regexp"
      value     = "publishing.*"
    }

    restart {
      attempts = 3
      delay    = "15s"
      interval = "1m"
      mode     = "delay"
    }

    network {
      port "grpc" {
        static = 4317
        to     = 4317
      }
      port "health" {
        to = 13133
      }
    }

    service {
      name = "dp-adot-collector-lb-grpc-publishing"
      port = "grpc"
      tags = ["publishing","otel-collector"]

      check {
        type     = "http"
        port     = "health"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "dp-adot-collector-lb-publishing" {
      driver = "docker"

      config {
        image = "{{ECR_URL}}:concourse-{{REVISION}}"
        ports = ["grpc","health"]
      }

      resources {
        cpu    = "{{PUBLISHING_RESOURCE_CPU}}"
        memory = "{{PUBLISHING_RESOURCE_MEM}}"
      }

      template {
        data = <<EOH
        # Configs based on environment (e.g. export BIND_ADDR=":{{ env "NOMAD_PORT_http" }}")
        # or static (e.g. export BIND_ADDR=":8080")

        # Secret configs read from vault
        {{ with (secret (print "secret/" (env "NOMAD_TASK_NAME"))) }}
        {{ range $key, $value := .Data }}
        export {{ $key }}="{{ $value }}"
        {{ end }}
        {{ end }}
        EOH

        destination = "secrets/app.env"
        env         = true
        splay       = "1m"
        change_mode = "restart"
      }

      vault {
        policies = ["dp-adot-collector-lb-publishing"]
      }
    }
  }
}

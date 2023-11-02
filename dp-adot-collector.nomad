job "dp-adot-collector" {
  datacenters = ["eu-west-2"]
  region      = "eu"
  type        = "service"

  constraint {
    attribute = "${node.class}"
    value     = "management"
  }

  group "management" {
    count = "1"

    restart {
      attempts = 3
      delay    = "15s"
      interval = "1m"
      mode     = "delay"
    }

    task "dp-adot-collector" {
      driver = "docker"

      artifact {
        source = "s3::https://s3-eu-west-2.amazonaws.com/{{DEPLOYMENT_BUCKET}}/dp-adot-collector/{{REVISION}}.tar.gz"
      }

      config {
        command = "${NOMAD_TASK_DIR}/start-task"

        args = ["./dp-adot-collector"]

        image = "{{ECR_URL}}:concourse-{{REVISION}}"
      }

      service {
        name = "dp-adot-collector"
        port = "http"
        tags = ["management"]
        check {
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "2s"
        }
      }

      resources {
        cpu    = "500"
        memory = "512"

        network {
          port "http" {}
        }
      }

      template {
        source      = "${NOMAD_TASK_DIR}/vars-template"
        destination = "${NOMAD_TASK_DIR}/vars"
        data = <<EOH
        # Configs based on nomad networking
        export BIND_ADDR=":{{ env "NOMAD_PORT_http" }}"
        export MAPS_API_URL="http://{{ env "NOMAD_IP_http" }}:12850/"

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
      }

      vault {
        policies = ["dp-adot-collector"]
      }

    }
  }
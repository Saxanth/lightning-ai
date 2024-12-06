terraform {
  required_providers {
    coder   = {
      source  = "coder/coder"
    }
    docker  = {
      source  = "kreuzwerker/docker"
    }
  }
}

module "code-server" {  
  version     = "1.0.18"
  agent_id    = coder_agent.main.id
  settings    = { "workbench.colorTheme" = "Dracula" }
  extensions  = [
    "dracula-theme.theme-dracula", 
    "ms-python.python"
  ]  
  accept_license = true
  source      = "registry.coder.com/modules/code-server/coder"
}

provider "coder" {}
provider "docker" {}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

locals {
  registry_name = "aegregore/workspace"
}

resource "coder_agent" "main" {
  os = "linux"
  arch = "amd64"

  startup_script = <<EOT
    #!/bin/bash
    set -euo pipefail
    # Create user data directory
    mkdir -p ~/data
    # make user share directory
    mkdir -p ~/share
    EOT  
}

# aegregore docker image
data "docker_registry_image" "aegregore" {
  name = "${local.registry_name}:latest"
}

#docker image
resource "docker_image" "aegregore" {
  name          = "${local.registry_name}@${data.docker_registry_image.aegregore.sha256_digest}"
  pull_triggers = [data.docker_registry_image.deeplearning.sha256_digest]
  keep_locally  = true
}

#home_volume
resource "docker_volume" "home_volume" {
  name = "dev-${lower(data.coder_workspace.me.name)}-home"
}

#usr_volume
resource "docker_volume" "usr_volume" {
  name = "dev-${lower(data.coder_workspace.me.name)}-usr"
}

#etc_volume
resource "docker_volume" "etc_volume" {
  name = "dev-${lower(data.coder_workspace.me.name)}-etc"
}

#opt_volume
resource "docker_volume" "opt_volume" {
  name = "dev-${lower(data.coder_workspace.me.name)}-opt"
}

#container workspace
resource "docker_container" "workspace" {
  count    = 1
  image    = docker_image.aegregore.image_id

  memory   = 16*1024
  gpus     = "\"device=0\""

  name     = "${lower(data.coder_workspace.me.name)}"
  hostname = lower(data.coder_workspace.me.name)

  ipc_mode = "host"
  dns      = ["1.1.1.1"]
  command  = ["sh", "-c", replace(coder_agent.main.init_script, "127.0.0.1", "host.docker.internal")]
  env      = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]
  restart  = "unless-stopped"
  
  devices {
    host_path = "/dev/nvidia0"
  }
  devices {
    host_path = "/dev/nvidiactl"
  }
  devices {
    host_path = "/dev/nvidia-uvm-tools"
  }
  devices {
    host_path = "/dev/nvidia-uvm"
  }
  devices {
    host_path = "/dev/nvidia-modeset"
  }

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  # users home directory
  volumes {
    container_path = "/home/developer"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }
  # users data directory
  volumes {
    container_path = "/home/developer/data/"
    host_path      = "/data/${data.coder_workspace_owner.me.name}/"
    read_only      = false
  }
  # shared data directory
  volumes {
    container_path = "/home/developer/share"
    host_path      = "/data/share/"
    read_only      = true
  }

  # setup default volumes
  volumes {
    container_path = "/usr/"
    volume_name    = docker_volume.usr_volume.name
    read_only      = false
  }
  volumes {
    container_path = "/etc/"
    volume_name    = docker_volume.etc_volume.name
    read_only      = false
  }
  volumes {
    container_path = "/opt/"
    volume_name    = docker_volume.opt_volume.name
    read_only      = false
  }

  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }
}
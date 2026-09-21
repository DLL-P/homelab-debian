#!/usr/bin/env bash
# Instala Docker Engine + Compose plugin no Debian 13 (trixie) a partir do
# repositório oficial da Docker. Idempotente: se o Docker já existir, só
# garante que o usuário atual está no grupo docker.
set -euo pipefail

if command -v docker >/dev/null 2>&1; then
  echo "Docker já instalado ($(docker --version)) — pulando instalação."
else
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y ca-certificates curl

  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

sudo usermod -aG docker "$USER"

echo
echo "Docker instalado. Se este for o primeiro 'usermod -aG docker', abra um novo"
echo "shell (ou rode 'newgrp docker') antes de usar 'docker compose' sem sudo."
echo "Teste com: docker run hello-world"

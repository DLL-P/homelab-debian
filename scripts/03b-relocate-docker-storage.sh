#!/usr/bin/env bash
# Move o armazenamento do Docker (imagens/containers) e do containerd
# (camadas/snapshots) para fora da partição padrão /var/lib/..., que em
# muitas instalações Debian é uma partição pequena (poucos GB) incapaz de
# segurar as imagens da stack de mídia inteira.
#
# Rode isto DEPOIS de 02-setup-disks.sh e 03-install-docker.sh, e ANTES de
# subir qualquer stack — só funciona limpo se ainda não há containers
# importantes rodando (containers já criados continuam referenciando o
# caminho antigo até serem recriados).
#
# Uso: ./scripts/03b-relocate-docker-storage.sh [destino]
#   destino (opcional): diretório base onde criar docker/ e containerd/
#                        padrão: /mnt/hdd2 (ver scripts/02-setup-disks.sh)
set -euo pipefail

DEST="${1:-/mnt/hdd2}"

echo "Espaço atual em /var:"
df -h /var

sudo systemctl stop docker docker.socket containerd

sudo mkdir -p "$DEST/docker" "$DEST/containerd"
[ -d /var/lib/docker ] && sudo rsync -a /var/lib/docker/ "$DEST/docker/" || true
[ -d /var/lib/containerd ] && sudo rsync -a /var/lib/containerd/ "$DEST/containerd/" || true

echo '{
  "data-root": "'"$DEST"'/docker"
}' | sudo tee /etc/docker/daemon.json > /dev/null

if [ ! -f /etc/containerd/config.toml ]; then
  sudo mkdir -p /etc/containerd
  containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
fi

# containerd só aceita 'root'/'state' como as PRIMEIRAS linhas do arquivo
# (chaves de nível superior, antes de qualquer [tabela]). Se já existirem
# linhas 'root =' / 'state =' mais abaixo, isso causa chave duplicada — por
# isso removemos qualquer ocorrência solta antes de inserir no topo.
sudo sed -i '/^root = /d; /^state = /d' /etc/containerd/config.toml
sudo sed -i "1i root = \"$DEST/containerd\"\\nstate = \"/run/containerd\"" /etc/containerd/config.toml

echo "--- /etc/containerd/config.toml (topo) ---"
head -5 /etc/containerd/config.toml

sudo systemctl start containerd
sudo systemctl start docker

echo
echo "--- Verificação ---"
docker info | grep -E "Docker Root Dir|Server Version"
df -h /var "$DEST"

echo
echo "Se havia containers rodando antes (ex: Portainer/NPM já configurados),"
echo "recrie-os agora com 'docker compose up -d' em cada stack — as imagens"
echo "serão baixadas de novo, mas dados em volumes nomeados (como o do"
echo "Portainer) são preservados desde que estivessem em /var/lib/docker"
echo "antes deste script rodar (o rsync acima já copiou tudo)."

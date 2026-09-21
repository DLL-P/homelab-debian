#!/usr/bin/env bash
# Verificações antes de instalar qualquer coisa. Não faz nenhuma alteração no sistema.
set -euo pipefail

echo "== Sistema =="
cat /etc/os-release | grep -E '^(PRETTY_NAME|VERSION_CODENAME)='

echo
echo "== CPU/RAM =="
nproc --all
free -h

echo
echo "== Discos e pontos de montagem =="
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL

echo
echo "== Espaço em disco =="
df -h

echo
echo "== Docker =="
if command -v docker >/dev/null 2>&1; then
  docker --version
  echo "Docker já instalado — o script 03-install-docker.sh vai pular a instalação."
else
  echo "Docker não instalado — o script 03-install-docker.sh vai instalar."
fi

echo
echo "== Usuário atual =="
echo "UID=$(id -u) GID=$(id -g) USER=$(whoami)"

echo
echo "Revise a saída acima antes de continuar. Em especial, confira em 'lsblk' quais"
echo "dispositivos (ex: /dev/sdb, /dev/sdc) correspondem aos 2 HDDs de 500GB — você"
echo "vai precisar informar esses nomes ao script 02-setup-disks.sh."

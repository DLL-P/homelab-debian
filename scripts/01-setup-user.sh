#!/usr/bin/env bash
# Cria (ou reaproveita) o usuário administrativo do homelab e o torna sudoer.
#
# IMPORTANTE: este script NUNCA recebe a senha como argumento nem a grava em
# disco. Ele chama `passwd`, que pede a senha de forma interativa e oculta.
# Defina a senha manualmente quando o prompt aparecer.
set -euo pipefail

TARGET_USER="${1:-dll}"

if id "$TARGET_USER" &>/dev/null; then
  echo "Usuário '$TARGET_USER' já existe — não será recriado."
  read -r -p "Quer redefinir a senha dele agora? [s/N] " resp
  if [[ "$resp" =~ ^[sS]$ ]]; then
    sudo passwd "$TARGET_USER"
  fi
else
  echo "Criando usuário '$TARGET_USER'..."
  sudo adduser --gecos "" "$TARGET_USER"
  # adduser já pede a senha interativamente durante a criação.
fi

echo "Adicionando '$TARGET_USER' ao grupo sudo..."
sudo usermod -aG sudo "$TARGET_USER"

echo "Adicionando '$TARGET_USER' ao grupo docker (necessário para rodar os stacks sem sudo)..."
sudo groupadd -f docker
sudo usermod -aG docker "$TARGET_USER"

echo
echo "Pronto. '$TARGET_USER' agora é sudoer e faz parte do grupo docker."
echo "Ele precisa encerrar e reabrir a sessão de shell (ou 'newgrp docker') para"
echo "o grupo docker ter efeito sem precisar de sudo."

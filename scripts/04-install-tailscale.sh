#!/usr/bin/env bash
# Instala o Tailscale para ACESSO REMOTO ADMINISTRATIVO ao servidor (SSH,
# Portainer, Nginx Proxy Manager, etc.) via uma mesh WireGuard privada.
#
# IMPORTANTE: isto NÃO deve ser usado para rotear o tráfego do qBittorrent
# nem dos trackers privados (BJ-Share, CapybaraBR) — eles proíbem VPN.
# O Tailscale aqui só cria uma interface de rede extra (tailscale0) para
# você acessar o servidor remotamente; ele não força nenhum tráfego de
# aplicação a passar por ele. Os containers de mídia continuam usando a
# rede normal do host/Docker, sem qualquer túnel.
set -euo pipefail

if command -v tailscale >/dev/null 2>&1; then
  echo "Tailscale já instalado ($(tailscale version | head -n1)) — pulando instalação."
else
  curl -fsSL https://tailscale.com/install.sh | sh
fi

echo
echo "Rodando 'tailscale up'. Isso vai imprimir um link — abra-o no navegador"
echo "para autenticar este servidor na sua conta Tailscale."
sudo tailscale up

echo
echo "Status da rede Tailscale:"
tailscale status

echo
echo "A partir de agora, dá para acessar este servidor remotamente pelo IP"
echo "Tailscale (100.x.x.x) mesmo estando fora da sua rede local — inclusive"
echo "via SSH e pelas portas de admin (Portainer :9000, NPM :81), SEM abrir"
echo "essas portas para a internet pública no firewall."

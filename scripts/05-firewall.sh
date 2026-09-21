#!/usr/bin/env bash
# Configura UFW: libera só o essencial na rede "normal" (WAN/LAN) e libera
# tudo na interface do Tailscale, que já é autenticada e criptografada.
#
# ATENÇÃO: habilitar o UFW pode derrubar sua sessão SSH atual se a porta 22
# não estiver liberada. Este script libera 22/tcp ANTES de ativar o UFW,
# mas confirme com você mesmo antes de rodar remotamente sem console físico.
set -euo pipefail

sudo apt install -y ufw

echo "Liberando portas essenciais (SSH, HTTP, HTTPS) para qualquer rede..."
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

if ip link show tailscale0 &>/dev/null; then
  echo "Liberando toda a interface tailscale0 (acesso admin: Portainer, NPM, Arr, etc.)..."
  sudo ufw allow in on tailscale0
else
  echo "Aviso: interface tailscale0 não encontrada ainda. Rode 04-install-tailscale.sh"
  echo "antes deste script, ou libere manualmente depois com: sudo ufw allow in on tailscale0"
fi

echo
echo "NÃO liberando para a internet pública (ficam só na LAN/Tailscale):"
echo "  9000 (Portainer), 81 (NPM admin), 8080 (qBittorrent), 9696 (Prowlarr),"
echo "  8989 (Sonarr), 7878 (Radarr), 6767 (Bazarr), 5055 (Jellyseerr), 8096 (Jellyfin)"
echo
echo "Se você quiser hospedar jogos para amigos ocasionalmente, libere a porta"
echo "do jogo SOMENTE enquanto o servidor estiver ativo, por exemplo:"
echo "  sudo ufw allow 25565/tcp   # Minecraft"
echo "  sudo ufw delete allow 25565/tcp   # depois de encerrar a sessão de jogo"

read -r -p "Ativar o UFW agora? [s/N] " resp
if [[ "$resp" =~ ^[sS]$ ]]; then
  sudo ufw --force enable
  sudo ufw status verbose
else
  echo "UFW configurado mas NÃO ativado. Ative depois com: sudo ufw enable"
fi

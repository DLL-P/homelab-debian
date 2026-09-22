#!/usr/bin/env bash
# Orquestra o deploy completo, passo a passo, pedindo confirmação antes de
# cada etapa destrutiva ou irreversível. Rode a partir da raiz do repositório
# clonado NO SERVIDOR (não funciona remotamente a partir de outra máquina).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

confirm() {
  read -r -p "$1 [s/N] " resp
  [[ "$resp" =~ ^[sS]$ ]]
}

echo "=== 0. Verificações iniciais ==="
bash scripts/00-pre-checks.sh
confirm "Continuar para criação do usuário administrativo?" || exit 0

echo "=== 1. Usuário administrativo (dll) ==="
bash scripts/01-setup-user.sh dll
confirm "Continuar para preparação dos HDDs (isto FORMATA os discos)?" || exit 0

echo "=== 2. HDDs de dados ==="
bash scripts/02-setup-disks.sh
confirm "Continuar para instalação do Docker?" || exit 0

echo "=== 3. Docker ==="
bash scripts/03-install-docker.sh

VAR_FREE_KB=$(df --output=avail /var | tail -1)
if [ "$VAR_FREE_KB" -lt 8388608 ]; then
  echo
  echo "AVISO: /var tem menos de 8GB livres ($((VAR_FREE_KB / 1024))MB)."
  echo "O Docker guarda imagens em /var/lib/docker por padrão — com pouco"
  echo "espaço aí, baixar a stack de mídia inteira vai falhar por falta de"
  echo "espaço em disco no meio do processo."
  if confirm "Mover o armazenamento do Docker/containerd para ${HDD2_MOUNT:-/mnt/hdd2} agora?"; then
    bash scripts/03b-relocate-docker-storage.sh "${HDD2_MOUNT:-/mnt/hdd2}"
  else
    echo "Seguindo sem mover — se der 'no space left on device' mais adiante,"
    echo "rode manualmente: ./scripts/03b-relocate-docker-storage.sh"
  fi
fi
confirm "Continuar para instalação do Tailscale?" || exit 0

echo "=== 4. Tailscale (acesso remoto admin) ==="
bash scripts/04-install-tailscale.sh
confirm "Continuar para gerar os arquivos .env dos stacks?" || exit 0

echo "=== 5. Gerar .env dos stacks ==="
bash scripts/07-generate-env.sh
confirm "Continuar para subir Portainer?" || exit 0

echo "=== 6. Portainer ==="
(cd stacks/portainer && docker compose up -d)
confirm "Continuar para subir Nginx Proxy Manager?" || exit 0

echo "=== 7. Nginx Proxy Manager ==="
if sudo ss -tulpn 2>/dev/null | grep -qE ':80 .*apache2|:80 .*nginx\b'; then
  echo "Detectado um servidor web já rodando na porta 80 (fora do Docker),"
  echo "que vai colidir com o Nginx Proxy Manager."
  if confirm "Parar e desabilitar esse serviço agora?"; then
    SVC=$(sudo ss -tulpn 2>/dev/null | grep -E ':80 ' | grep -oE 'apache2|nginx' | head -1)
    sudo systemctl stop "$SVC"
    sudo systemctl disable "$SVC"
  fi
fi
docker network create proxy-network 2>/dev/null || true
(cd stacks/npm && docker compose up -d)
confirm "Continuar para subir a stack de mídia (Arr + Jellyfin)?" || exit 0

echo "=== 8. Stack de mídia ==="
(cd stacks/media && docker compose up -d)
confirm "Continuar para subir os módulos de dashboard/observabilidade?" || exit 0

echo "=== 9. Dashboard e observabilidade ==="
(cd stacks/tools && docker compose up -d)
confirm "Continuar para subir o Crafty Controller (servidor de jogos)?" || exit 0

echo "=== 10. Crafty Controller ==="
(cd stacks/gameservers && docker compose up -d)
confirm "Configurar o firewall agora (pode afetar SSH se mal configurado)?" || exit 0

echo "=== 11. Firewall ==="
bash scripts/05-firewall.sh
confirm "Agendar backup automático semanal?" || exit 0

echo "=== 12. Backup automático ==="
bash scripts/06-backup-cron.sh /mnt/hdd2/backups/homelab

echo
echo "=== Status final ==="
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo
echo "Deploy concluído. Veja docs/POST_DEPLOY.md para os passos manuais"
echo "restantes (configuração inicial de cada serviço pela interface web)."

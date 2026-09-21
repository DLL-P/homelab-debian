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

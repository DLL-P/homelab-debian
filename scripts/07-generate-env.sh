#!/usr/bin/env bash
# Gera os arquivos .env reais (não commitados) a partir dos .env.example,
# preenchendo PUID/PGID/TZ automaticamente e perguntando o resto.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PUID=$(id -u)
PGID=$(id -g)
read -r -p "Timezone [America/Recife]: " TZ
TZ="${TZ:-America/Recife}"

# --- stacks/media/.env ---
MEDIA_ENV="$REPO_ROOT/stacks/media/.env"
if [[ -f "$MEDIA_ENV" ]]; then
  echo "$MEDIA_ENV já existe — não será sobrescrito."
else
  cp "$REPO_ROOT/stacks/media/.env.example" "$MEDIA_ENV"
  sed -i "s/^PUID=.*/PUID=${PUID}/" "$MEDIA_ENV"
  sed -i "s/^PGID=.*/PGID=${PGID}/" "$MEDIA_ENV"
  sed -i "s#^TZ=.*#TZ=${TZ}#" "$MEDIA_ENV"
  echo "Criado $MEDIA_ENV"
fi

# --- stacks/tools/.env ---
TOOLS_ENV="$REPO_ROOT/stacks/tools/.env"
if [[ -f "$TOOLS_ENV" ]]; then
  echo "$TOOLS_ENV já existe — não será sobrescrito."
else
  cp "$REPO_ROOT/stacks/tools/.env.example" "$TOOLS_ENV"
  sed -i "s#^TZ=.*#TZ=${TZ}#" "$TOOLS_ENV"
  read -r -p "URL de notificação do Diun (ntfy/Discord/Telegram, deixe em branco para configurar depois): " DIUN_NOTIF
  if [[ -n "$DIUN_NOTIF" ]]; then
    sed -i "s#^DIUN_NOTIF_URL=.*#DIUN_NOTIF_URL=${DIUN_NOTIF}#" "$TOOLS_ENV"
  fi
  echo "Criado $TOOLS_ENV"
fi

# --- stacks/gameservers/.env ---
GAME_ENV="$REPO_ROOT/stacks/gameservers/.env"
if [[ -f "$GAME_ENV" ]]; then
  echo "$GAME_ENV já existe — não será sobrescrito."
else
  cp "$REPO_ROOT/stacks/gameservers/.env.example" "$GAME_ENV"
  sed -i "s#^TZ=.*#TZ=${TZ}#" "$GAME_ENV"
  echo "Criado $GAME_ENV"
fi

echo
echo "Arquivos .env gerados em stacks/*/. Eles estão no .gitignore e NUNCA devem"
echo "ser commitados no repositório."

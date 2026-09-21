#!/usr/bin/env bash
# Agenda um backup semanal (domingo 03h) dos configs do homelab (/opt/homelab)
# para /mnt/hdd2/backups/homelab. Isto NÃO inclui a biblioteca de mídia
# (grande demais e reobtenível) — só configs/estado dos containers.
set -euo pipefail

BACKUP_DIR="${1:-/mnt/hdd2/backups/homelab}"
sudo mkdir -p "$BACKUP_DIR"

CRON_LINE="0 3 * * 0 tar -czf ${BACKUP_DIR}/homelab-\$(date +\%F).tar.gz /opt/homelab 2>> ${BACKUP_DIR}/backup.log"

( crontab -l 2>/dev/null | grep -vF "homelab-\$(date" ; echo "$CRON_LINE" ) | crontab -

echo "Cron de backup instalado:"
crontab -l | grep homelab

echo
echo "Backup local apenas (mesma máquina). Para 3-2-1 completo (cópia fora do"
echo "host), considere depois 'restic' + 'rclone' para enviar a um provedor de"
echo "nuvem — isso exige credenciais de um serviço externo, então não foi"
echo "automatizado aqui."

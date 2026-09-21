#!/usr/bin/env bash
# Prepara os 2 HDDs de 500GB como discos SEPARADOS (sem RAID/LVM), conforme decidido:
#   HDD1 -> /mnt/hdd1 -> biblioteca de mídia (filmes, séries, músicas)
#   HDD2 -> /mnt/hdd2 -> downloads + backups
#
# ATENÇÃO: este script FORMATA os discos informados (mkfs.ext4), apagando
# qualquer dado neles. Rode antes `lsblk` (ou o script 00-pre-checks.sh) para
# confirmar QUAIS dispositivos são os HDDs de dados e não o SSD do sistema.
set -euo pipefail

echo "Discos disponíveis no sistema:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL
echo

read -r -p "Dispositivo do HDD1 (mídia), ex: /dev/sdb (SEM número de partição): " HDD1
read -r -p "Dispositivo do HDD2 (downloads/backups), ex: /dev/sdc: " HDD2

for dev in "$HDD1" "$HDD2"; do
  if [[ ! -b "$dev" ]]; then
    echo "ERRO: '$dev' não é um dispositivo de bloco válido. Abortando." >&2
    exit 1
  fi
done

echo
echo "!!! ATENÇÃO !!!"
echo "Isto vai APAGAR TODOS OS DADOS em $HDD1 e $HDD2 e criar uma partição ext4 em cada."
read -r -p "Digite EXATAMENTE 'FORMATAR' para confirmar e continuar: " confirm
if [[ "$confirm" != "FORMATAR" ]]; then
  echo "Cancelado. Nenhuma alteração foi feita."
  exit 1
fi

for dev in "$HDD1" "$HDD2"; do
  echo "Particionando $dev..."
  sudo parted -s "$dev" mklabel gpt
  sudo parted -s "$dev" mkpart primary ext4 0% 100%
  sleep 1
done

PART1="${HDD1}1"
PART2="${HDD2}1"

echo "Formatando $PART1 e $PART2 como ext4..."
sudo mkfs.ext4 -F -L hdd1_media "$PART1"
sudo mkfs.ext4 -F -L hdd2_data "$PART2"

sudo mkdir -p /mnt/hdd1 /mnt/hdd2

UUID1=$(sudo blkid -s UUID -o value "$PART1")
UUID2=$(sudo blkid -s UUID -o value "$PART2")

echo "Adicionando entradas em /etc/fstab (com nofail para não travar o boot se o disco sumir)..."
{
  echo "UUID=$UUID1  /mnt/hdd1  ext4  defaults,nofail  0  2"
  echo "UUID=$UUID2  /mnt/hdd2  ext4  defaults,nofail  0  2"
} | sudo tee -a /etc/fstab > /dev/null

sudo mount -a

echo "Criando estrutura de diretórios..."
sudo mkdir -p /mnt/hdd1/media/{filmes,series,musicas}
sudo mkdir -p /mnt/hdd2/{downloads,backups/homelab}

sudo chown -R "$USER:$USER" /mnt/hdd1 /mnt/hdd2

echo
echo "Pronto:"
echo "  /mnt/hdd1 -> $PART1 (UUID $UUID1) -> biblioteca de mídia"
echo "  /mnt/hdd2 -> $PART2 (UUID $UUID2) -> downloads e backups"
df -h /mnt/hdd1 /mnt/hdd2

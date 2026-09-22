# Homelab Debian

Provisionamento completo do homelab, pensado para o seguinte hardware:

- **CPU**: Ryzen 3 3200G
- **RAM**: 12GB DDR4 dual channel
- **Armazenamento**: 1 SSD de 128GB (sistema) + 2 HDDs de 500GB cada (dados)

## Decisões de arquitetura

- **SSD (128GB)**: só o sistema operacional Debian e os diretórios de
  configuração dos containers (`/opt/homelab`). Nada de biblioteca de mídia
  ou downloads aqui — evita saturar o disco do sistema.
- **2 HDDs, mantidos separados (sem RAID/LVM)**: por decisão explícita, os
  discos não são combinados.
  - `/mnt/hdd1` → biblioteca de mídia (filmes, séries, músicas)
  - `/mnt/hdd2` → downloads ativos + backups de configuração
  - Sem redundância entre eles: se um HD falhar, os dados dele se perdem.
    O script de backup (`scripts/06-backup-cron.sh`) cobre só os *configs*
    dos containers, não a biblioteca de mídia inteira (grande demais e
    reobtenível via os próprios indexadores).
- **Sem domínio público**: acesso é só por IP na rede local, ou pelo IP do
  Tailscale quando remoto. O Nginx Proxy Manager é usado apenas como proxy
  reverso interno (nomes em vez de portas), sem certificado público.
- **Tailscale ≠ VPN da stack de mídia**: o Tailscale é instalado no sistema
  operacional só para acesso remoto administrativo (SSH, Portainer, NPM).
  Ele **não** envolve o tráfego do qBittorrent/Sonarr/Radarr/Prowlarr, porque
  os trackers privados usados (**BJ-Share** e **CapybaraBR**) proíbem VPN
  para esse tráfego. Por isso este repositório **não usa Gluetun** — decisão
  deliberada, não uma omissão.
- **Usuário administrativo**: `dll`, criado com `sudo` e no grupo `docker`.
  A senha é definida interativamente pelo próprio `passwd`/`adduser` ao
  rodar `scripts/01-setup-user.sh` — **nenhuma senha fica gravada em texto
  puro em nenhum arquivo deste repositório**. Defina a senha localmente
  quando o script pedir.
- **Armazenamento do Docker/containerd**: por padrão o Docker grava tudo em
  `/var/lib/docker` (e o containerd em `/var/lib/containerd`). Em instalações
  onde `/var` é uma partição pequena (comum em instalações Debian
  particionadas manualmente), isso enche rápido só com as imagens da stack de
  mídia. O `scripts/deploy-all.sh` detecta isso automaticamente e, se
  necessário, roda `scripts/03b-relocate-docker-storage.sh` para mover ambos
  para dentro de um dos HDDs (`/mnt/hdd2/docker` e `/mnt/hdd2/containerd` por
  padrão). Rode esse script manualmente se você ver erros de "no space left
  on device" ao subir alguma stack.
- **Se já existir um Apache/Nginx do sistema na porta 80**: o
  `deploy-all.sh` detecta e pergunta se pode parar e desabilitar o serviço
  antes de subir o Nginx Proxy Manager (que precisa da porta 80/443/81 livre).
- **Servidor de jogos**: Crafty Controller, para gerenciar servidores
  (Minecraft e outros) sob demanda para amigos. Dado o total de 12GB de RAM
  compartilhado com todo o resto da stack, configure a memória de cada
  servidor de jogo com folga e evite rodar vários ao mesmo tempo.

## Estrutura do repositório

```
scripts/            scripts de provisionamento, numerados na ordem de execução
stacks/portainer/   Portainer atrás de socket-proxy (sem acesso direto ao docker.sock)
stacks/npm/         Nginx Proxy Manager
stacks/media/       Sonarr, Radarr, Prowlarr, Bazarr, qBittorrent, FlareSolverr, Jellyseerr, Jellyfin
stacks/tools/       Homepage, Uptime Kuma, Scrutiny, Diun
stacks/gameservers/ Crafty Controller
docs/POST_DEPLOY.md checklist de configuração manual pós-deploy (interfaces web)
```

## Como rodar

Este repositório é só código/config — ele não tem acesso ao seu servidor
físico. Clone-o no próprio servidor Debian 13 e rode a partir de lá:

```bash
git clone <url-deste-repositorio> homelab-debian
cd homelab-debian
chmod +x scripts/*.sh
```

**Opção A — passo a passo com confirmação em cada etapa (recomendado):**

```bash
./scripts/deploy-all.sh
```

**Opção B — rodar cada script manualmente**, na ordem numérica em
`scripts/` (leia cada um antes de rodar — `02-setup-disks.sh` formata
discos e `05-firewall.sh` mexe no firewall):

```bash
./scripts/00-pre-checks.sh
./scripts/01-setup-user.sh dll
./scripts/02-setup-disks.sh        # DESTRUTIVO: formata os 2 HDDs
./scripts/03-install-docker.sh
./scripts/03b-relocate-docker-storage.sh   # se /var tiver pouco espaço, ver abaixo
./scripts/04-install-tailscale.sh
./scripts/07-generate-env.sh
(cd stacks/portainer && docker compose up -d)
docker network create proxy-network
(cd stacks/npm && docker compose up -d)
(cd stacks/media && docker compose up -d)
(cd stacks/tools && docker compose up -d)
(cd stacks/gameservers && docker compose up -d)
./scripts/05-firewall.sh
./scripts/06-backup-cron.sh
```

Depois, siga [`docs/POST_DEPLOY.md`](docs/POST_DEPLOY.md) para a
configuração manual de cada serviço pela interface web (senhas iniciais,
conectar Sonarr/Radarr ao qBittorrent, apontar bibliotecas do Jellyfin,
etc.).

## Segurança

- Nenhum segredo (senha de usuário, chave de API, credencial de serviço)
  está commitado neste repositório. Os arquivos `.env` reais (gerados por
  `scripts/07-generate-env.sh` a partir dos `.env.example`) ficam só no
  servidor e estão no `.gitignore`.
- Portainer roda atrás de um `socket-proxy` somente-leitura para a maior
  parte das operações (sem `EXEC`/`SYSTEM`), reduzindo o risco de um
  container comprometido escalar para controle total do host via
  `docker.sock`.
- Firewall (`ufw`) libera só 22/80/443 publicamente; todas as portas de
  administração (Portainer, NPM, Arr stack) ficam restritas à LAN e à
  interface do Tailscale.

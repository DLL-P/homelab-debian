# Guia de serviços — o que é cada um e como configurar

Referência de todos os softwares que compõem este homelab: pra que servem,
como acessar pela primeira vez, e os passos de configuração principais.
Nenhum valor real (senha, API key, cookie) aparece aqui — isso fica só no
seu gerenciador de senhas pessoal. Sempre que um passo pede uma "API Key",
ela é gerada pelo próprio serviço na primeira vez que você abre — copie o
valor que aparecer na tela dele, não invente um.

Convenção usada abaixo: `IP` é o IP do servidor (local ou Tailscale); nomes
como `sonarr`, `radarr`, `qbittorrent` são os nomes dos containers Docker —
use-os (não `localhost`) sempre que um serviço precisar falar com outro.

---

## Infraestrutura de base

### Docker + Docker Compose
O motor que roda todos os outros serviços como containers isolados.
Instalado por `scripts/03-install-docker.sh`. Não tem interface própria —
gerenciado via `docker compose` (linha de comando) ou pelo Portainer (abaixo).
Se `/var` for pequeno, ver `scripts/03b-relocate-docker-storage.sh`.

### Portainer — `http://IP:9000`
Painel web pra ver/gerenciar todos os containers, sem precisar decorar
comandos `docker`. Roda atrás de um `socket-proxy` (não tem acesso irrestrito
ao `docker.sock`, só o necessário pra listar/subir containers).

**Primeiro acesso**: crie um usuário admin assim que subir — expira em
poucos minutos. Se expirar, rode `docker compose restart portainer` no
diretório `stacks/portainer` e recarregue a página; algumas versões pedem
também um "Setup token", que aparece em `docker logs portainer`.

**Configuração**: depois de criado o usuário, clique em "Get Started" pra
usar o ambiente Docker local (já é este mesmo servidor, não precisa
adicionar nada).

### Nginx Proxy Manager (NPM) — `http://IP:81`
Proxy reverso: permite acessar os serviços por nome (`jellyfin.home`) em vez
de `IP:porta`, e cuidaria de HTTPS se você tivesse domínio público (não é o
caso aqui — acesso é só por IP local/Tailscale).

**Primeiro acesso**: login inicial `admin@example.com` / `changeme` —
**troque a senha e o email imediatamente**, é pedido automaticamente no
primeiro login.

**Configuração**: opcional neste setup (sem domínio público). Se quiser usar
nomes internos, crie um "Proxy Host" por serviço em Hosts → Proxy Hosts,
apontando pro nome do container e a porta interna dele (ex: `jellyfin:8096`).

### Tailscale
Rede privada (mesh WireGuard) só pra acesso administrativo remoto ao
servidor (SSH, Portainer, NPM) — nunca roteia o tráfego de torrent/tracker.
Instalado por `scripts/04-install-tailscale.sh`. Sem interface web própria
no servidor; gerenciado por `tailscale status` / `tailscale up` no terminal,
ou pelo painel em [login.tailscale.com](https://login.tailscale.com).

### UFW (firewall)
Libera só 22 (SSH), 80/443 (NPM) e a interface Tailscale pra qualquer rede;
todo o resto (Portainer, Arr stack, etc.) fica restrito à LAN/Tailscale.
Configurado por `scripts/05-firewall.sh`. Comandos úteis:
`sudo ufw status verbose`, `sudo ufw allow <porta>/tcp`, `sudo ufw delete allow <porta>/tcp`.

---

## Stack de mídia

### qBittorrent — `http://IP:8080`
Cliente de torrent. Roda sem VPN de propósito (ver README, seção "Decisões
de arquitetura") — os trackers privados usados proíbem VPN no tráfego.

**Primeiro acesso**: senha temporária aparece em
`docker logs qbittorrent | grep -i "temporary password"`. Troque
imediatamente em **Tools → Options → Web UI → Authentication**.

**Configuração**:
- **Options → Downloads**: pasta padrão `/downloads`, ative *Automatic
  Torrent Management* se quiser.
- **Options → Web UI → Security**: se outro serviço (Sonarr/Radarr) não
  conseguir conectar com "Unable to connect" mesmo com rede ok, confira o
  campo **Server domains** (sob "Enable Host header validation") — precisa
  aceitar o nome do container, ou deixe `*` pra aceitar qualquer host.

### Prowlarr — `http://IP:9696`
Gerenciador central de indexadores (trackers) — você cadastra os trackers
aqui uma vez, e ele distribui pro Sonarr/Radarr automaticamente.

**Primeiro acesso**: cria usuário/senha na primeira tela.

**Configuração**:
1. **Indexers → Add Indexer**: procure o tracker pelo nome. Cada um pede um
   método de autenticação diferente (Cookie, API Key, API Key + RSS Key) —
   o próprio formulário mostra qual campo preencher. Pra pegar um **cookie**
   de sessão: logado no tracker pelo navegador, abra o DevTools (F12) →
   Application/Armazenamento → Cookies, copie no formato `nome=valor`. Pra
   pegar uma **API Key**: geralmente fica no perfil da sua conta no site do
   tracker, em "Configurações" ou "Segurança".
2. **Settings → Apps → "+"**: adiciona Sonarr/Radarr. Em "Prowlarr Server"
   e "Sonarr/Radarr Server", use o **nome do container**
   (`http://prowlarr:9696`, `http://sonarr:8989`, `http://radarr:7878`) —
   `localhost` não funciona entre containers diferentes. A API Key de cada
   um fica nele mesmo, em Settings → General → Security.

### Sonarr — `http://IP:8989`
Gerencia séries de TV: busca, baixa e organiza episódios automaticamente.

**Primeiro acesso**: pode pedir criação de usuário/senha (Settings →
General → Security → Authentication). Se esquecer a senha, dá pra resetar
editando `stacks/media/sonarr/config.xml`
(`<AuthenticationMethod>None</AuthenticationMethod>`), reiniciando o
container, entrando sem senha e definindo uma nova ali mesmo.

**Configuração**:
- **Settings → Download Clients → "+"**: qBittorrent, host `qbittorrent`,
  porta `8080`, usuário/senha do qBittorrent (digite manualmente — o
  autocomplete do navegador às vezes preenche uma senha salva errada).
- Conectado ao Prowlarr a partir de lá (ver seção Prowlarr acima).
- **Settings → Media Management**: confira os caminhos (`/tv`, `/downloads`
  já vêm mapeados pelo `docker-compose.yml`).

### Radarr — `http://IP:7878`
Mesma coisa que o Sonarr, mas pra filmes. Configuração idêntica: Download
Client (qBittorrent) e conexão com o Prowlarr, com os mesmos cuidados de
nome de container e senha digitada manualmente.

### Bazarr — `http://IP:6767`
Baixa legendas automaticamente pros itens que o Sonarr/Radarr já baixaram.

**Configuração**: **Settings → Sonarr** e **Settings → Radarr** — ative,
host `sonarr`/`radarr`, porta `8989`/`7878`, cole a API Key de cada um
(Settings → General → Security dentro do próprio Sonarr/Radarr). Depois,
em **Settings → Languages** e **Settings → Providers**, escolha idioma(s) e
fontes de legenda.

### Jellyfin — `http://IP:8096`
Servidor de mídia — é o "Netflix caseiro" que reproduz o que o
Sonarr/Radarr baixaram.

**Primeiro acesso**: assistente de configuração inicial (idioma, criar
usuário admin).

**Configuração**: no assistente (ou depois em **Dashboard → Libraries**),
adicione bibliotecas apontando para:
- Séries → `/media/series`
- Filmes → `/media/filmes`
- Músicas → `/media/musicas`

Se o servidor tiver GPU Intel, descomente a seção `devices: /dev/dri` no
`stacks/media/docker-compose.yml` pra transcodificação por hardware.

### Jellyseerr — `http://IP:5055`
Interface de pedidos: você (ou amigos) pedem um filme/série, e ele manda
automaticamente pro Radarr/Sonarr baixarem.

**Configuração**: assistente inicial pede pra conectar ao **Jellyfin**
(URL `http://jellyfin:8096` + login do Jellyfin) e depois ao **Sonarr** e
**Radarr** (URL + API Key de cada, igual configuramos no Bazarr/Prowlarr).

### FlareSolverr
Serviço auxiliar sem interface própria — ajuda o Prowlarr a contornar
proteções anti-bot (Cloudflare) de alguns indexadores. Só precisa estar no
ar; se um indexador do Prowlarr pedir "FlareSolverr", aponte pra
`http://flaresolverr:8191`.

---

## Dashboard e observabilidade

### Homepage — `http://IP:3000`
Painel único com atalhos pra todos os serviços.

**Configuração**: edite os arquivos YAML dentro de
`stacks/tools/homepage/config/` (criados automaticamente na primeira
subida) — principalmente `services.yaml` (lista de serviços/links) e
`settings.yaml` (aparência). Depois de editar, não precisa recriar o
container, o Homepage recarrega sozinho.

### Uptime Kuma — `http://IP:3001`
Monitor de disponibilidade — avisa se algum serviço cair.

**Primeiro acesso**: cria usuário admin na primeira tela.

**Configuração**: **Add New Monitor** pra cada serviço que quiser
acompanhar (tipo HTTP, URL `http://<container>:<porta>`), e configure uma
**Notification** (Telegram, Discord, e-mail, etc.) pra ser avisado.

### Scrutiny — `http://IP:8091`
Monitora a saúde S.M.A.R.T. dos discos (avisa sinais de falha antes de
perder dados).

**Configuração**: nenhuma — ele já lê os discos listados como `devices` no
`stacks/tools/docker-compose.yml` (via variáveis `SCRUTINY_DISK_*` no
`.env`). Só abra a interface e confira que os 3 discos aparecem com status
OK. Se os nomes dos discos (`/dev/sdX`) mudarem depois de um reboot, ajuste
o `.env` e recrie o container.

### Diun
Notifica quando uma imagem Docker que você usa tem atualização disponível.
Sem interface web.

**Configuração**: edite `stacks/tools/.env` e `stacks/tools/docker-compose.yml`
com as variáveis do provedor de notificação escolhido (ntfy, Discord,
Telegram — cada um tem variáveis `DIUN_NOTIF_<PROVEDOR>_*` próprias, ver
comentário no `docker-compose.yml`), depois `docker compose up -d diun`
para aplicar.

---

## Jogos

### Crafty Controller — `https://IP:8443`
Painel web pra criar/gerenciar servidores de jogos (Minecraft e outros) sob
demanda, pra hospedar pros amigos ocasionalmente.

**Primeiro acesso**: certificado autoassinado — o navegador vai avisar
"conexão não é segura", pode prosseguir. Cria usuário admin na primeira
tela.

**Configuração**: **Add New Server** → escolha o tipo (Minecraft
Vanilla/Paper/Forge, etc.) e defina a memória alocada com folga — a máquina
tem só 12GB de RAM no total, compartilhados com todo o resto da stack, então
2-3GB por servidor de jogo é um teto razoável. Libere a porta do jogo no
firewall (`sudo ufw allow 25565/tcp` pro Minecraft, por exemplo) só
enquanto a sessão de jogo estiver ativa, e remova depois
(`sudo ufw delete allow 25565/tcp`).

# Passos manuais pós-deploy

Estes passos exigem alguns cliques na interface web na primeira vez — não dá
para automatizar por API com segurança. Substitua `IP` pelo IP local do
servidor (ou o IP Tailscale, 100.x.x.x, se estiver acessando remotamente).

## Status do último deploy guiado (atualizado em 2026-09-22)

Feito: Portainer, Nginx Proxy Manager, qBittorrent, Prowlarr (+ indexadores
BJ-Share e CapybaraBR), Sonarr, Radarr, e a conexão Sonarr↔Prowlarr,
Radarr↔Prowlarr, Sonarr↔qBittorrent, Radarr↔qBittorrent.

Pendente: Bazarr, Jellyfin, Jellyseerr, Homepage, Uptime Kuma, Scrutiny,
Diun, Crafty Controller (itens 6–13 abaixo). Credenciais e chaves reais
ficaram só num arquivo local do usuário, nunca neste repositório.

Duas pegadinhas encontradas nesse deploy específico, que podem se repetar:
- Ao conectar apps no Prowlarr (ou vice-versa), o campo "Prowlarr Server" /
  "Sonarr Server" / "Radarr Server" precisa do **nome do container** (ex:
  `http://prowlarr:9696`), nunca `localhost` — cada container tem seu
  próprio localhost.
- Ao adicionar o qBittorrent como Download Client no Sonarr/Radarr, cuidado
  com autocomplete do navegador preenchendo usuário/senha errados
  silenciosamente — digite manualmente se o "Test" falhar com "Unable to
  connect" mesmo com a rede ok.

1. **Portainer** (`http://IP:9000`): crie o usuário admin nos primeiros
   minutos após o primeiro `docker compose up -d` — a instalação expira e
   precisa ser refeita se demorar demais (basta `docker compose restart
   portainer` e recarregar a página pra gerar um novo prazo/token).

2. **Nginx Proxy Manager** (`http://IP:81`): login inicial
   `admin@example.com` / `changeme` — **troque a senha imediatamente**.
   Como o acesso é só por IP local (sem domínio público), use o NPM para
   criar "Proxy Hosts" internos por nome, se quiser (ex: `jellyfin.home` em
   vez de `IP:8096`), apontando para o IP interno de cada container na rede
   `proxy-network`.

3. **qBittorrent** (`http://IP:8080`): a senha temporária do admin fica no
   log do container (`docker logs qbittorrent`). Depois de logar, troque a
   senha, defina `/downloads` como pasta padrão de downloads e ative
   *Automatic Torrent Management*.

4. **Prowlarr** (`http://IP:9696`): adicione os indexadores do BJ-Share e
   CapybaraBR (e outros que usar) — BJ-Share pediu **Cookie** de sessão,
   CapybaraBR pediu **API Key + RSS Key** (cada tracker define seu próprio
   método de autenticação no Cardigann). Em Settings → Apps, conecte o
   Sonarr e o Radarr usando o nome do container na URL (ver pegadinha acima).

5. **Sonarr** (`http://IP:8989`) e **Radarr** (`http://IP:7878`): em
   Settings → Download Clients, adicione o qBittorrent (host `qbittorrent`,
   porta `8080`). Como não há Gluetun/VPN no meio, o mapeamento de caminho é
   direto: `/downloads` → `/downloads` (sem remapeamento).

6. **Bazarr** (`http://IP:6767`): conecte ao Sonarr e Radarr para legendas
   automáticas. — **PENDENTE**

7. **Jellyfin** (`http://IP:8096`): assistente inicial, aponte as
   bibliotecas para `/media/filmes`, `/media/series` e `/media/musicas`. — **PENDENTE**

8. **Jellyseerr** (`http://IP:5055`): conecte ao Jellyfin e ao Sonarr/Radarr
   para permitir que você (ou amigos) solicitem novos filmes/séries. — **PENDENTE**

9. **Homepage** (`http://IP:3000`): edite
   `stacks/tools/homepage/config/services.yaml` para adicionar os links dos
   serviços acima. — **PENDENTE**

10. **Uptime Kuma** (`http://IP:3001`): crie monitores HTTP para cada
    serviço acima e configure uma notificação (Telegram, e-mail, etc.). — **PENDENTE**

11. **Scrutiny** (`http://IP:8091`): confirme que os 3 discos (SSD +
    2 HDDs) aparecem e estão com saúde OK. — **PENDENTE**

12. **Diun**: se não configurou a URL de notificação em
    `stacks/tools/.env`, edite `stacks/tools/docker-compose.yml` com as
    variáveis específicas do provedor escolhido (ver comentário no arquivo)
    e rode `docker compose up -d diun` novamente. — **PENDENTE**

13. **Crafty Controller** (`https://IP:8443`, certificado autoassinado —
    aceite o aviso do navegador): crie o usuário admin no primeiro acesso e
    configure um servidor Minecraft com memória limitada (ex: 2-3GB) dado o
    total de 12GB de RAM da máquina. — **PENDENTE**

## Lembrete de segurança

- Nenhuma senha real (do usuário do sistema, dos serviços acima, ou de
  qualquer `.env`) está neste repositório. Os arquivos `.env` reais ficam
  apenas no servidor e estão no `.gitignore`.
- Troque toda senha padrão (NPM, qBittorrent) assim que possível.
- O tráfego do qBittorrent/Prowlarr/Sonarr/Radarr **não passa por VPN**, de
  propósito, para não violar as regras do BJ-Share e do CapybaraBR. Não
  adicione Gluetun a este stack sem revisar essa decisão.
- O Tailscale dá acesso remoto às portas de administração (Portainer, NPM)
  sem expô-las à internet pública — mantenha o firewall (`ufw`) configurado
  para não liberar essas portas fora da LAN/Tailscale.

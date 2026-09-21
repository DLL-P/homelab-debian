# Passos manuais pós-deploy

Estes passos exigem alguns cliques na interface web na primeira vez — não dá
para automatizar por API com segurança. Substitua `IP` pelo IP local do
servidor (ou o IP Tailscale, 100.x.x.x, se estiver acessando remotamente).

1. **Portainer** (`http://IP:9000`): crie o usuário admin nos primeiros
   minutos após o primeiro `docker compose up -d` — a instalação expira e
   precisa ser refeita se demorar demais.

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
   CapybaraBR (e outros que usar). Em Settings → Apps, conecte o Sonarr e o
   Radarr.

5. **Sonarr** (`http://IP:8989`) e **Radarr** (`http://IP:7878`): em
   Settings → Download Clients, adicione o qBittorrent (host `qbittorrent`,
   porta `8080`). Como não há Gluetun/VPN no meio, o mapeamento de caminho é
   direto: `/downloads` → `/downloads` (sem remapeamento).

6. **Bazarr** (`http://IP:6767`): conecte ao Sonarr e Radarr para legendas
   automáticas.

7. **Jellyfin** (`http://IP:8096`): assistente inicial, aponte as
   bibliotecas para `/media/filmes`, `/media/series` e `/media/musicas`.

8. **Jellyseerr** (`http://IP:5055`): conecte ao Jellyfin e ao Sonarr/Radarr
   para permitir que você (ou amigos) solicitem novos filmes/séries.

9. **Homepage** (`http://IP:3000`): edite
   `stacks/tools/homepage/config/services.yaml` para adicionar os links dos
   serviços acima.

10. **Uptime Kuma** (`http://IP:3001`): crie monitores HTTP para cada
    serviço acima e configure uma notificação (Telegram, e-mail, etc.).

11. **Scrutiny** (`http://IP:8091`): confirme que os 3 discos (SSD +
    2 HDDs) aparecem e estão com saúde OK.

12. **Diun**: se não configurou a URL de notificação em
    `stacks/tools/.env`, edite `stacks/tools/docker-compose.yml` com as
    variáveis específicas do provedor escolhido (ver comentário no arquivo)
    e rode `docker compose up -d diun` novamente.

13. **Crafty Controller** (`https://IP:8443`, certificado autoassinado —
    aceite o aviso do navegador): crie o usuário admin no primeiro acesso e
    configure um servidor Minecraft com memória limitada (ex: 2-3GB) dado o
    total de 12GB de RAM da máquina.

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

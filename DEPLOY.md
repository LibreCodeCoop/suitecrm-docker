# Deploy do SuiteCRM 8

Este documento é genérico. Não versione endereços de produção, credenciais,
backups, chaves nem definições de rede exclusivas da infraestrutura.

## Pré-requisitos

- Docker Compose; proxy HTTPS existente; banco compatível.
- Diretório persistente em `./volumes/suitecrm:/var/www/html`.
- Backup do banco **e** dos arquivos, com restauração testada.
- Rede e credenciais definidas localmente. Veja a
  [matriz oficial](https://docs.suitecrm.com/8.x/admin/compatibility-matrix/).

## Imagem e banco

O Compose usa `ghcr.io/librecodecoop/suitecrm-docker/suite-crm:latest`.
Seu build é feito no GitHub Actions, com smoke checks antes de publicar.
A versão está em `SUITECRM_VERSION` e no label OCI.

O serviço MySQL deste repositório pertence ao profile `dev-db`:
**não o habilite em um servidor que já tenha um banco externo**.
O `php` não depende mais do serviço local `mysql` e pode usar a rede
configurada em override privado.

Exemplo de override, sem dados reais:

```yaml
services:
  php:
    networks: [database]
  messenger:
    networks: [database]
  scheduler:
    networks: [database]
networks:
  database:
    external: true
    name: ${DATABASE_NETWORK:?configure DATABASE_NETWORK locally}
```

O override precisa preservar os vínculos e usar apenas os recursos existentes
na instalação real. A rede `mysql` padrão pode permanecer conectada, mas
não crie nem substitua bases por acidente.

## Configuração inicial de desenvolvimento

```bash
cp .env.example .env
# Configure MYSQL_ROOT_PASSWORD e MYSQL_PASSWORD.
./install.sh
```

O `install.sh` inicia o banco local via profile `dev-db`, aguarda o
healthcheck e depois inicia `php`, `messenger` e `scheduler`.
Não use esse instalador contra produção já existente.

## Implantar os processos de background em produção

Na instalação existente, revise primeiro o Compose/override real e a origem do
volume. **Não atualize o app persistido nem execute migrations nesta etapa.**

```bash
docker compose --profile background config --quiet
docker compose --profile background up -d --no-deps messenger
docker compose --profile background ps
docker compose --profile background logs --tail=100 messenger
```

O serviço `messenger` executa, como `www-data`:

```text
php bin/console messenger:consume internal-async --time-limit=3600 --memory-limit=256M
```

O serviço `scheduler` executa
`php bin/console schedulers:run --no-interaction` a cada 60 segundos.
Ambos usam o **mesmo volume** e a mesma imagem do web. Evite workers
concorrentes sem validar a idempotência das tarefas.

### Migração do cron antigo

1. Examine o agendamento existente do host e confirme se é usado por outros
   serviços; não substitua o crontab completo.
2. Valide a configuração, permissões, imagem e rede do novo serviço ainda sem
   iniciá-lo, e confirme que o worker Messenger está funcionando.
3. Em uma janela de mudança, desative **somente** a entrada antiga do SuiteCRM
   e então inicie `docker compose --profile background up -d --no-deps scheduler`.
4. Confira logs, tarefas no painel **Admin > Schedulers**, status e horários.
   Se o serviço novo falhar, pare-o e restaure a entrada antiga do cron,
   nunca mantendo os dois ativos em paralelo.

A documentação oficial do SuiteCRM 8.9+ recomenda
[bin/console schedulers:run por minuto](https://docs.suitecrm.com/8.x/admin/administration-panel/schedulers/).
O Messenger do 8.10+ deve executar permanentemente. A rotina de
`legacy/cron.php` pode funcionar para tarefas antigas, mas não deve ser
a única estratégia documentada para novas instalações.

## Verificações e atualizações

```bash
docker compose exec -u www-data php php bin/console suitecrm:version
docker compose exec -u www-data php php bin/console doctrine:migrations:status --no-interaction
docker compose --profile background exec messenger php bin/console messenger:stats
```

Confira ainda **Admin > Migrations**, login, agenda, e-mails, anexos e logs.
Este repositório não executa automaticamente migrações manuais de anexos.

Atualizar uma imagem `latest` não atualiza os arquivos de
`volumes/suitecrm`; siga [UPGRADE.md](UPGRADE.md) para versões da aplicação.
Não use `docker compose build` na produção como parte de um deploy comum.
Builds locais exigem `docker-compose.build.yml` opt-in.

## Backup e rollback

Antes de atualizar a aplicação, valide um par consistente de backup:
um dump do banco e o snapshot dos arquivos. Se uma atualização falhar,
restaure **os dois juntos**. Alterar somente o volume ou só o banco causa
inconsistências. Os scripts não armazenam credenciais de backup.

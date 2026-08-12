# Deploy do SuiteCRM

Este documento contém somente exemplos genéricos. Informações da infraestrutura
de produção, incluindo hostnames, domínios, e-mails, nomes de banco, usuários,
credenciais e caminhos de backup, devem permanecer em documentação privada.

## Pré-requisitos

- Docker Engine e Docker Compose;
- proxy HTTPS ou publicação controlada da porta HTTP;
- banco MySQL/MariaDB compatível;
- backup independente e testado para banco e arquivos.

Consulte a [matriz oficial](https://docs.suitecrm.com/8.x/admin/compatibility-matrix/)
antes de mudar SuiteCRM, PHP ou banco.

## Imagem

O repositório publica a imagem PHP como:

```text
ghcr.io/librecodecoop/suitecrm-docker/suite-crm:latest
```

O número da versão fica em `SUITECRM_VERSION` e no label OCI. A ausência de uma
tag versionada é intencional: atualizações usam sempre o mesmo nome de imagem.

## Configuração

Para desenvolvimento:

```bash
cp .env.example .env
# Preencha os valores obrigatórios sem enviá-los ao Git.
docker compose up -d mysql php
```

O Compose não publica a porta do banco. Se acesso externo for indispensável em
desenvolvimento, crie um override local limitado a `127.0.0.1`.

## Produção com banco externo

Não implante um novo banco quando já existir um banco gerenciado ou compartilhado.
Crie um override privado que:

- mantenha apenas `php`, `messenger` e `scheduler`;
- conecte esses serviços à rede externa apropriada;
- preserve `./volumes/suitecrm:/var/www/html`;
- injete configurações por `.env`, secrets do orquestrador ou outro cofre;
- não contenha valores reais no repositório.

Modelo reduzido, sem dados operacionais:

```yaml
services:
  php:
    image: ghcr.io/librecodecoop/suitecrm-docker/suite-crm:latest
    volumes:
      - ./volumes/suitecrm:/var/www/html
    networks:
      - database

networks:
  database:
    external: true
    name: ${DATABASE_NETWORK:?configure DATABASE_NETWORK locally}
```

Os serviços de background devem receber o mesmo volume e a mesma rede, sem
incluir um serviço de banco no override de produção.

## Instalação

Use o instalador interativo para evitar credenciais padrão ou exemplos que
acabem reutilizados em produção:

```bash
docker compose exec php php bin/console suitecrm:app:install
docker compose --profile background up -d messenger scheduler
```

Depois da instalação:

- configure HTTPS;
- instale e selecione a tradução necessária;
- configure moeda e e-mail;
- confirme a execução do scheduler;
- confirme o Messenger Worker;
- faça um backup completo e teste a restauração.

## Atualizações

Para atualizar somente o runtime:

```bash
docker compose pull php messenger scheduler
docker compose --profile background up -d --no-deps php messenger scheduler
```

Isso não atualiza os arquivos existentes em `volumes/suitecrm`. Para atualizar a
aplicação e o schema, siga [UPGRADE.md](UPGRADE.md).

## Operação

```bash
docker compose --profile background ps
docker compose logs -f php messenger scheduler
docker compose exec php php bin/console app:version:status
docker compose exec php php bin/console cache:clear
```

O scheduler usa `public/legacy/cron.php`. O Messenger consome `internal-async`
como `www-data`, conforme recomendado para SuiteCRM 8.10+.

## Backups

Não há script de dump com credenciais neste repositório porque produção pode
usar banco local, externo ou gerenciado. A solução adotada deve:

1. gerar um dump consistente somente do banco da aplicação;
2. criar snapshot de `volumes/suitecrm` no mesmo ponto lógico;
3. registrar sucesso ou falha;
4. aplicar retenção fora do diretório versionado;
5. testar periodicamente uma restauração completa.

Antes de um upgrade, confirme que os dois artefatos existem e são legíveis. O
script de upgrade pode chamar a integração local através de `BACKUP_COMMAND`.

## Verificação e rollback

Após mudanças:

```bash
docker compose exec php php bin/console app:version:status
docker compose exec php php bin/console doctrine:migrations:status --no-interaction
docker compose logs --since=10m php
```

Valide também autenticação, operações essenciais e **Admin > Migrations**. Para
rollback, restaure sempre o par correspondente de arquivos e banco; não combine
snapshots de momentos diferentes.

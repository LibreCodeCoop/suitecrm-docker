# SuiteCRM Docker

Imagem e serviços Docker para SuiteCRM 8, PHP Apache e banco de desenvolvimento
opcional. A versão do SuiteCRM está em `SUITECRM_VERSION` (hoje `v8.10.2`).
A imagem publicada é
`ghcr.io/librecodecoop/suitecrm-docker/suite-crm:latest`; a revisão e versão
são registradas nos metadados OCI.

## Serviço e responsabilidades

- `php`: PHP/Apache para a aplicação. A imagem é consumida diretamente.
- `mysql`: banco apenas de desenvolvimento/instalação inicial (`dev-db`).
  **Não** é iniciado por `docker compose up -d`.
- `messenger`: consumidor `internal-async` como `www-data`, reinício automático.
- `scheduler`: executa `bin/console schedulers:run` a cada 60 segundos como
  `www-data`, com reinício em caso de falha.

Os processos de background pertencem ao profile `background`; para ativá-los,
use explicitamente:

```bash
docker compose --profile background up -d php messenger
# Ative scheduler só na janela de migração, após desativar o cron antigo.
docker compose --profile background ps
docker compose --profile background logs --tail=100 messenger
```

Em produção, conecte os serviços ao banco **já existente** e use a mesma pasta
persistente montada em `/var/www/html`. Não inicialize o banco de desenvolvimento
em produção. Consulte [DEPLOY.md](DEPLOY.md) antes de ativar os serviços: o
agendador externo antigo deve ser desativado **somente após** o novo serviço
ter sido validado, para evitar duplicidade.

## Instalação de desenvolvimento

```bash
cp .env.example .env
# Preencha os dois segredos MYSQL_*; nunca os versione.
./install.sh
```

O instalador espera o MySQL de desenvolvimento ficar saudável, inicia a aplicação
e depois sobe os serviços `messenger` e `scheduler`. Para construir a imagem
localmente, use o override **explícito**:

```bash
docker compose -f docker-compose.yml -f docker-compose.build.yml build php
docker compose -f docker-compose.yml -f docker-compose.build.yml up -d php
```

O Compose padrão não possui instruções `build`: a implantação usa apenas as
imagens publicadas e verificadas.

## Atualização e configuração de PHP

A imagem usa PHP 8.4, a linha mais recente documentada como compatível com
SuiteCRM 8.10 na [matriz oficial](https://docs.suitecrm.com/8.x/admin/compatibility-matrix/).
A atualização de correções de segurança é feita pelo **Dependabot**: a
versão de patch e o digest ficam no Dockerfile, e os PRs de atualização passam
pelos testes Bats e pelo build do CI. Mudanças de linha PHP dependem de
revisão da matriz; não é necessário manter números de versão em testes.

Limites configurados na imagem: `memory_limit=512M`,
`upload_max_filesize=30M`, `post_max_size=36M`,
`display_errors=off`, `log_errors=On`. Logs não devem conter segredos.

O diretório `volumes/suitecrm` é persistente: atualizar a imagem **não**
atualiza automaticamente os arquivos já instalados. Leia
[UPGRADE.md](UPGRADE.md) para o procedimento de versão e backup.

## Comandos de consulta

```bash
docker compose exec -u www-data php php bin/console suitecrm:version
docker compose exec -u www-data php php bin/console doctrine:migrations:status --no-interaction
docker compose --profile background exec messenger php bin/console messenger:stats --no-interaction
docker compose --profile background logs --tail=100 scheduler messenger
```

Reveja **Admin > Migrations** antes de disparar migrações manuais; elas podem
exigir um Messenger funcional. Use [DEPLOY.md](DEPLOY.md) para verificações
de produção e [UPGRADE.md](UPGRADE.md) para rollback.

## Testes e CI

```bash
bash -n install.sh scripts/upgrade-suitecrm.sh .docker/php/scripts/entrypoint.sh
bats tests/scripts.bats tests/compose.bats
# Após construir a imagem local (somente ambiente de teste):
SUITECRM_TEST_IMAGE=suitecrm-ci:verify bats tests/image.bats
```

Os testes Bats exercitam os scripts com comandos simulados, sem tocar
instalações reais. Os testes de imagem usam contêineres descartáveis sem
volumes de produção. O CI constrói a imagem, verifica extensões/limites e
comportamento do entrypoint e **só depois** publica no GHCR. Um build bem-
sucedido não substitui testes de migração em homologação com dados sintéticos.

## Segurança

Nunca versione `.env`, bancos, backups ou configurações locais do servidor.
Não implante operações SQL de migração no entrypoint da imagem.
Aplicações comerciais não podem ser modificadas apenas pela inicialização
dos serviços.

Licença: AGPLv3. Documentação oficial:
[instalação](https://docs.suitecrm.com/8.x/admin/installation-guide/),
[scheduler](https://docs.suitecrm.com/8.x/admin/administration-panel/schedulers/),
[Messenger](https://docs.suitecrm.com/8.x/admin/async-tasks/messenger-setup/).

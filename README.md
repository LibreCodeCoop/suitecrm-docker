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

A imagem usa PHP 8.3.36, compatível com SuiteCRM 8.10. A [matriz oficial](https://docs.suitecrm.com/8.x/admin/compatibility-matrix/)
lista PHP 8.2, 8.3 e 8.4 para esta versão; PHP 8.5 não está listado.
Dependabot propõe automaticamente patches da linha selecionada, mas não
mudanças de série PHP sem revisão explícita da compatibilidade.

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
python3 scripts/check-runtime-compatibility.py
python3 -m unittest discover -s tests -v
```

Os testes de scripts usam comandos simulados, sem tocar instalações reais.
O CI também constrói uma imagem, verifica PHP/extensões/limites e **só depois**
publica no GHCR. Um build que passa não substitui testes de migração em
homologação com dados sintéticos.

## Segurança

Nunca versione `.env`, bancos, backups ou configurações locais do servidor.
Não implante operações SQL de migração no entrypoint da imagem.
Aplicações comerciais não podem ser modificadas apenas pela inicialização
dos serviços.

Licença: AGPLv3. Documentação oficial:
[instalação](https://docs.suitecrm.com/8.x/admin/installation-guide/),
[scheduler](https://docs.suitecrm.com/8.x/admin/administration-panel/schedulers/),
[Messenger](https://docs.suitecrm.com/8.x/admin/async-tasks/messenger-setup/).

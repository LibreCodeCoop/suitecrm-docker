# SuiteCRM Docker

Ambiente Docker para SuiteCRM 8 com PHP 8.3, Apache e MySQL. A versão do
SuiteCRM incluída na imagem é definida em `SUITECRM_VERSION`; atualmente,
`v8.10.2`.

O workflow publica somente:

```text
ghcr.io/librecodecoop/suitecrm-docker/suite-crm:latest
```

A versão permanece disponível no label OCI `org.opencontainers.image.version`.

## Início rápido

1. Prepare a configuração local:

   ```bash
   cp .env.example .env
   ```

2. Preencha `MYSQL_ROOT_PASSWORD` e `MYSQL_PASSWORD` com valores aleatórios.
   O arquivo `.env` não é versionado.
3. Execute a instalação interativa:

   ```bash
   ./install.sh
   ```

O instalador do SuiteCRM solicitará as credenciais do banco e do administrador
sem que o repositório defina senhas padrão.

## Serviços

- `php`: PHP 8.3, Apache e extensões necessárias ao SuiteCRM.
- `mysql`: MySQL 8.4 para desenvolvimento; a porta não é publicada no host.
- `messenger`: worker obrigatório para tarefas assíncronas do SuiteCRM 8.10+.
- `scheduler`: executa `public/legacy/cron.php` a cada cinco minutos.

Os dois serviços de background usam um profile e devem ser iniciados depois da
instalação:

```bash
docker compose --profile background up -d
```

Em produção, o banco pode ser externo. Use um override local para remover o
serviço `mysql` e conectar `php`, `messenger` e `scheduler` à rede apropriada;
não versione nomes, endereços ou credenciais da infraestrutura.

## Persistência e atualizações

`./volumes/suitecrm` é montado em `/var/www/html`. Por isso, trocar ou baixar a
imagem `latest` não altera uma instalação já existente nesse volume.

Consulte [UPGRADE.md](UPGRADE.md) antes de qualquer atualização. O fluxo exige
backup do banco e dos arquivos e executa tanto `suitecrm:app:upgrade` quanto
`suitecrm:app:upgrade-finalize`.

## Comandos úteis

```bash
docker compose --profile background ps
docker compose logs -f php
docker compose exec php php bin/console app:version:status
docker compose exec php php bin/console cache:clear
docker compose exec php php bin/console doctrine:migrations:status --no-interaction
docker compose exec mysql sh -c 'mysql -u"$MYSQL_USER" -p "$MYSQL_DATABASE"'
```

Evite `docker exec` com nomes fixos de containers; os nomes podem variar entre
projetos. Execute cron, worker e comandos da aplicação como `www-data`.

## Desenvolvimento

Para alterar o runtime localmente:

```bash
docker compose build php
docker compose up -d php
```

O Xdebug fica desabilitado por padrão. Configure `XDEBUG_CONFIG` no `.env` e
ajuste `.docker/php/config/php.ini` somente no ambiente de desenvolvimento.

## Segurança

- Nunca versione `.env`, `.env.local`, dumps, backups ou arquivos de configuração
  da instalação.
- Não coloque credenciais em argumentos documentados ou no Compose.
- Não publique a porta do banco por padrão.
- Use HTTPS, backups testados e credenciais exclusivas em produção.
- Trate exemplos de produção como arquivos locais ou templates com placeholders.

## Documentação

- [Deploy genérico](DEPLOY.md)
- [Atualização](UPGRADE.md)
- [Matriz oficial de compatibilidade](https://docs.suitecrm.com/8.x/admin/compatibility-matrix/)
- [Guia oficial de instalação](https://docs.suitecrm.com/8.x/admin/installation-guide/)
- [Guia oficial de upgrade](https://docs.suitecrm.com/8.x/admin/upgrading/)
- [Messenger Worker](https://docs.suitecrm.com/8.x/admin/async-tasks/messenger-setup/)
- [Traduções](https://crowdin.com/project/suitecrmtranslations)

## Licença

SuiteCRM é distribuído sob AGPLv3. Consulte `LICENSE`.

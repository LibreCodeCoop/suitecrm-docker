# Atualização do SuiteCRM

Este guia cobre instalações que persistem `/var/www/html` em
`./volumes/suitecrm`. Nesse cenário, atualizar a imagem Docker não atualiza os
arquivos da aplicação: o volume encobre o conteúdo incluído na imagem.

## Antes de atualizar

1. Leia o `SUITECRM_VERSION` e confira a versão instalada:

   ```bash
   cat SUITECRM_VERSION
   docker compose exec php php bin/console app:version:status
   ```

2. Revise a [matriz de compatibilidade](https://docs.suitecrm.com/8.x/admin/compatibility-matrix/),
   as [notas da versão](https://docs.suitecrm.com/8.x/admin/releases/) e o
   [guia oficial](https://docs.suitecrm.com/8.x/admin/upgrading/).
3. Confirme que a aplicação usa `APP_ENV=prod`.
4. Crie e valide backups independentes do banco e de `volumes/suitecrm`.
   Este repositório não conhece a topologia nem as credenciais do banco de
   produção, portanto não tenta descobri-las ou armazená-las.
5. Teste o procedimento em uma cópia antes de aplicá-lo em produção. O upgrade
   pode remover arquivos não-core.

## Atualizar a imagem

```bash
docker compose pull php
docker compose up -d --no-deps php
```

Isso atualiza o runtime e a versão usada em instalações novas. Para uma
instalação persistida, execute também o upgrade da aplicação.

## Atualizar a aplicação persistida

Após verificar os backups:

```bash
scripts/upgrade-suitecrm.sh --backup-confirmed
```

Para integrar o script ao backup da sua infraestrutura, forneça um comando que
só termine com sucesso depois de criar e validar os dois backups:

```bash
BACKUP_COMMAND='/caminho/para/um/comando-local-de-backup' \
  scripts/upgrade-suitecrm.sh
```

Não coloque esse comando, credenciais ou caminhos internos no Git. O script:

- lê a versão de destino em `SUITECRM_VERSION`;
- baixa o pacote instalável oficial e valida o ZIP;
- corrige as permissões;
- executa `suitecrm:app:upgrade`;
- executa obrigatoriamente `suitecrm:app:upgrade-finalize`;
- revisa as migrations e a versão instalada;
- reinicia somente o serviço web.

Em instalações cujo serviço ou volume tenham outros nomes:

```bash
SUITECRM_SERVICE=web \
SUITECRM_VOLUME_PATH=/caminho/persistente \
  scripts/upgrade-suitecrm.sh --backup-confirmed
```

## Verificações posteriores

```bash
docker compose exec php php bin/console app:version:status
docker compose exec php php bin/console doctrine:migrations:status --no-interaction
docker compose logs --since=10m php
```

Depois, autentique-se na interface e abra **Admin > Migrations**. A partir do
SuiteCRM 8.10, tarefas manuais usam Symfony Messenger e ficam pendentes sem um
worker. No Compose deste repositório:

```bash
docker compose --profile background up -d messenger scheduler
docker compose --profile background ps
```

O worker deve executar como o mesmo usuário do servidor web (`www-data`).

## Rollback

Não improvise um rollback parcial. Pare o serviço web, restaure em conjunto o
snapshot dos arquivos e o dump correspondente do banco, e só então inicie o
serviço novamente. Os comandos concretos dependem da solução de backup e não
devem conter credenciais no repositório.

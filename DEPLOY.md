# Deploy para VPS

Guia completo para fazer deploy do SuiteCRM Docker na sua VPS.

## Pré-requisitos na VPS

1. **Docker e Docker Compose instalados**
2. **Git instalado**
3. **Porta 80 liberada no firewall**
4. **Acesso SSH à VPS**

## Instalação de Dependências na VPS

Se a VPS ainda não tiver Docker instalado:

```bash
# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar dependências
sudo apt install -y curl git

# Instalar Docker
curl -fsSL https://get.docker.com | sh

# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Relogar ou executar
newgrp docker
```

## Método 1: Deploy via Git (Recomendado)

### 1. Commitar e Fazer Push das Mudanças Locais

No seu computador local:

```bash
# Adicionar todas as mudanças
git add -A

# Fazer commit
git commit -m "Add automatic bug fixes and improved documentation"

# Fazer push para o repositório remoto
git push origin main
```

### 2. Clonar na VPS

Conecte-se à VPS via SSH e execute:

```bash
# Clonar o repositório
git clone <URL_DO_SEU_REPOSITORIO> suitecrm-docker
cd suitecrm-docker

# Dar permissão de execução ao script de instalação
chmod +x install.sh

# Executar instalação
./install.sh
```

### 3. Aplicar Correções de Bugs (Se Necessário)

Se o entrypoint não aplicou as correções automaticamente, execute:

```bash
# Aplicar correções manualmente
chmod +x fix-bugs.sh
./fix-bugs.sh
```

Ou aplicar diretamente:

```bash
docker compose exec php sed -i '644d' public/legacy/modules/AOW_WorkFlow/aow_utils.php
docker compose exec php sed -i '294d' public/legacy/include/InlineEditing/InlineEditing.php
docker compose exec php sed -i 's|RewriteBase localhostlegacy/|RewriteBase /legacy/|' public/legacy/.htaccess
```

### 4. Completar Instalação

```bash
# Instalar SuiteCRM
docker compose exec php bin/console suitecrm:app:install \
  -U root \
  -P root \
  -H mysql \
  -Z 3306 \
  -N root \
  -u admin \
  -p SuaSenhaSegura123 \
  -S seu-dominio.com \
  -d no \
  -W true
```

**Importante**: Troque `admin` e `SuaSenhaSegura123` por credenciais seguras!

### 4. Atualizar Deploy

Para atualizar quando fizer mudanças:

```bash
# Na VPS
cd suitecrm-docker
git pull origin main
docker compose down
docker compose up -d --build
```

## Método 2: Deploy via rsync

Se você não estiver usando Git ou quiser sincronizar diretamente:

### 1. Do Local para VPS

```bash
# Sincronizar arquivos (excluindo volumes)
rsync -avz --exclude 'volumes/' \
  --exclude '.git/' \
  --exclude '.env' \
  /home/mohr/lixo/suitecrm-docker/ \
  usuario@ip-da-vps:/caminho/destino/suitecrm-docker/

# Conectar na VPS
ssh usuario@ip-da-vps

# Entrar no diretório
cd /caminho/destino/suitecrm-docker

# Executar instalação
chmod +x install.sh
./install.sh
```

## Método 3: Deploy via SCP

Para transferência simples de arquivos:

```bash
# Compactar projeto (excluindo volumes)
tar -czf suitecrm-docker.tar.gz \
  --exclude='volumes/' \
  --exclude='.git/' \
  -C /home/mohr/lixo suitecrm-docker/

# Transferir para VPS
scp suitecrm-docker.tar.gz usuario@ip-da-vps:/tmp/

# Na VPS
ssh usuario@ip-da-vps
cd ~
tar -xzf /tmp/suitecrm-docker.tar.gz
cd suitecrm-docker
chmod +x install.sh
./install.sh
```

## Configuração de Domínio

### 1. Nginx Reverse Proxy (Recomendado)

Se você quiser usar um domínio com HTTPS:

```bash
# Instalar Nginx
sudo apt install -y nginx certbot python3-certbot-nginx

# Criar configuração
sudo nano /etc/nginx/sites-available/suitecrm
```

Conteúdo do arquivo:

```nginx
server {
    listen 80;
    server_name seu-dominio.com;

    location / {
        proxy_pass http://localhost:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
# Ativar site
sudo ln -s /etc/nginx/sites-available/suitecrm /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# Instalar certificado SSL
sudo certbot --nginx -d seu-dominio.com
```

### 2. Mudar Porta do Docker (Alternativa)

Se preferir não usar reverse proxy:

Edite `docker-compose.yml`:

```yaml
services:
  php:
    ports:
      - "8080:80"  # Mude para porta diferente
```

## Configuração de Produção

### Variáveis de Ambiente

Crie um arquivo `.env` na VPS:

```bash
nano .env
```

Conteúdo:

```env
VERSION_SUITECRM=v8.8.0
TZ=America/Sao_Paulo
XDEBUG_CONFIG=off
```

### Backup Automático

Crie um script de backup:

```bash
nano backup.sh
```

Conteúdo:

```bash
#!/bin/bash
BACKUP_DIR="/backup/suitecrm"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup do banco
docker compose exec -T mysql mysqldump -uroot -proot root > $BACKUP_DIR/db_$DATE.sql

# Backup dos arquivos
tar -czf $BACKUP_DIR/files_$DATE.tar.gz volumes/suitecrm

# Manter apenas últimos 7 backups
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup concluído: $DATE"
```

```bash
chmod +x backup.sh

# Adicionar ao crontab (backup diário às 2h)
crontab -e
# Adicione: 0 2 * * * /caminho/para/backup.sh
```

## Monitoramento

### Verificar Status

```bash
# Status dos containers
docker compose ps

# Logs em tempo real
docker compose logs -f

# Uso de recursos
docker stats
```

### Restart Automático

O `docker-compose.yml` já está configurado com `restart: always`, garantindo que os containers reiniciem automaticamente.

## Solução de Problemas

### Container não inicia

```bash
# Ver logs de erro
docker compose logs php
docker compose logs mysql

# Reconstruir
docker compose down
docker compose up -d --build --force-recreate
```

### Banco de dados corrompido

```bash
# Restaurar do backup
docker compose exec -T mysql mysql -uroot -proot root < /backup/suitecrm/db_XXXXXXXX.sql
```

### Liberar espaço

```bash
# Remover imagens não utilizadas
docker system prune -a

# Remover volumes órfãos
docker volume prune
```

## Segurança

### Recomendações Importantes

1. **Mude as senhas padrão**: Nunca use admin/admin em produção
2. **Configure firewall**: Use UFW para limitar acesso
   ```bash
   sudo ufw allow 22/tcp
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw enable
   ```
3. **Use HTTPS**: Sempre configure SSL/TLS
4. **Backups regulares**: Configure o script de backup
5. **Atualizações**: Mantenha sistema e Docker atualizados
6. **Monitore logs**: Verifique logs regularmente

## Comandos Úteis

```bash
# Reiniciar tudo
docker compose restart

# Parar tudo
docker compose down

# Ver uso de disco
docker system df

# Acessar MySQL
docker compose exec mysql mysql -uroot -proot root

# Executar comandos SuiteCRM
docker compose exec php bin/console list

# Limpar cache
docker compose exec php bash -c "rm -rf cache/prod/* public/legacy/cache/*"
docker compose restart php
```

## Checklist de Deploy

- [ ] VPS com Docker instalado
- [ ] Repositório clonado ou arquivos transferidos
- [ ] Firewall configurado
- [ ] `./install.sh` executado com sucesso
- [ ] Bugs verificados (3/3 ✓)
- [ ] SuiteCRM instalado via `bin/console`
- [ ] Senha de admin alterada
- [ ] Domínio apontado (se aplicável)
- [ ] SSL configurado (se aplicável)
- [ ] Backup configurado
- [ ] Sistema testado e funcionando

## Suporte

Para problemas específicos, consulte:
- README.md - Instruções detalhadas
- CHANGELOG.md - Histórico de mudanças
- logs/prod/prod.log - Logs da aplicação

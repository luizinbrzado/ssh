#!/bin/bash

# === CONFIGURAÇÕES ===
PROJECT_DIR="/var/www/agendaeduk"
GIT_REPO="https://github.com/seurepo/agendaeduk.git"  # altere se necessário
DB_NAME="agendaeduk"
DB_USER="agenda_user"
DB_PASS="RHYpoR57tuCJyKST-p83Fg"
APP_URL="https://agenda.unieduk.com.br"
DOMAIN="agenda.unieduk.com.br"

# === ATUALIZAÇÃO DO SISTEMA ===
apt update && apt upgrade -y

# === INSTALAR DEPENDÊNCIAS PHP/APACHE/MARIADB ===
apt install -y apache2 php php-cli php-mbstring php-xml php-curl php-mysql php-sqlite3 php-bcmath php-zip libapache2-mod-php \
    mariadb-server mariadb-client git unzip curl composer

# === INSTALAR NODE.JS 18 ===
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# === INSTALAR CERTBOT (SSL) ===
apt install -y certbot python3-certbot-apache

# === CLONAR O PROJETO ===
git clone "$GIT_REPO" "$PROJECT_DIR"
cd "$PROJECT_DIR" || exit 1

# === INSTALAR DEPENDÊNCIAS DO LARAVEL ===
composer install
cp .env.example .env
php artisan key:generate

# === CONFIGURAR .ENV ===
sed -i "s|APP_ENV=.*|APP_ENV=production|" .env
sed -i "s|APP_DEBUG=.*|APP_DEBUG=false|" .env
sed -i "s|APP_URL=.*|APP_URL=$APP_URL|" .env
sed -i "s|DB_DATABASE=.*|DB_DATABASE=$DB_NAME|" .env
sed -i "s|DB_USERNAME=.*|DB_USERNAME=$DB_USER|" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|" .env

# === PERMISSÕES ===
chown -R www-data:www-data "$PROJECT_DIR"
chmod -R 775 "$PROJECT_DIR/storage" "$PROJECT_DIR/bootstrap/cache"

# === CRIAR BANCO DE DADOS ===
mysql -u root <<MYSQL
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL

# === MIGRATIONS E SEEDS ===
php artisan migrate --seed

# === COMPILAR ASSETS ===
npm install
npm run build

# === OTIMIZAÇÃO PARA PRODUÇÃO ===
php artisan config:cache
php artisan route:cache
php artisan view:cache

# === CONFIGURAR VIRTUALHOST DO APACHE ===
cat <<EOF > /etc/apache2/sites-available/agendaeduk.conf
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot $PROJECT_DIR/public

    <Directory $PROJECT_DIR/public>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/agenda_error.log
    CustomLog \${APACHE_LOG_DIR}/agenda_access.log combined
</VirtualHost>
EOF

# === ATIVAR SITE E MÓDULOS DO APACHE ===
a2ensite agendaeduk
a2enmod rewrite
systemctl reload apache2

# === ATIVAR HTTPS COM CERTBOT ===
certbot --apache -d "$DOMAIN" --non-interactive --agree-tos -m suporte@unieduk.com.br

# === FINAL ===
echo "✅ Deploy completo com HTTPS ativado!"
echo "🌐 Acesse: $APP_URL"

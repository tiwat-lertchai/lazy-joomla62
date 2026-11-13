#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Secure Joomla 6.2.0 bootstrap for a fresh Ubuntu 24.04 server.
# Installs Apache, PHP-FPM, MariaDB, UFW, and the official Joomla package.

JOOMLA_VERSION="6.2.0"
JOOMLA_ARCHIVE="Joomla_6-2-0-Stable-Full_Package.zip"
JOOMLA_URL="https://downloads.joomla.org/cms/joomla6/6-2-0/${JOOMLA_ARCHIVE}?format=zip"
JOOMLA_SHA1="67a107c83b3084701a1a4acb151cd0452e5deaaf"

WEB_ROOT="/var/www/html"
DB_NAME="joomla"
DB_USER="joomla"
FTP_USER=""
RESET_FIREWALL=false
EDITOR_GROUP="joomla-editors"
BACKUP_ROOT="/var/backups/joomla-setup"
PHP_TIMEZONE="Asia/Bangkok"

usage() {
  cat <<'EOF'
Usage:
  sudo bash setup-joomla-6.2-ubuntu.sh [options]

Options:
  --web-root PATH        Joomla document root (default: /var/www/html)
  --db-name NAME         Database name (default: joomla)
  --db-user NAME         Database user (default: joomla)
  --ftp-user NAME        Existing FTP/SFTP user allowed to edit Joomla files
  --reset-firewall       Remove existing UFW rules, then allow only the
                         detected SSH port(s), TCP 80, and TCP 443
  -h, --help             Show this help

The database password is generated automatically and saved root-only in:
  /root/joomla-install-credentials.txt

Examples:
  sudo bash setup-joomla-6.2-ubuntu.sh --ftp-user ftpuser
  sudo bash setup-joomla-6.2-ubuntu.sh --db-name joomla62 \
    --db-user joomla62 --ftp-user ftpuser --reset-firewall
EOF
}

log() {
  printf '\n\033[1;34m==> %s\033[0m\n' "$*"
}

die() {
  printf '\nERROR: %s\n' "$*" >&2
  exit 1
}

require_value() {
  [[ $# -ge 2 && -n "${2:-}" ]] || die "Missing value for $1"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --web-root)
      require_value "$@"
      WEB_ROOT="$2"
      shift 2
      ;;
    --db-name)
      require_value "$@"
      DB_NAME="$2"
      shift 2
      ;;
    --db-user)
      require_value "$@"
      DB_USER="$2"
      shift 2
      ;;
    --ftp-user)
      require_value "$@"
      FTP_USER="$2"
      shift 2
      ;;
    --reset-firewall)
      RESET_FIREWALL=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

[[ ${EUID} -eq 0 ]] || die "Run this script as root (sudo)."
[[ "$WEB_ROOT" == /* ]] || die "--web-root must be an absolute path."
[[ "$WEB_ROOT" != "/" ]] || die "Refusing to use / as the web root."
[[ "$WEB_ROOT" =~ ^/[A-Za-z0-9._/-]+$ ]] || die "The web root contains unsupported characters."
[[ "$DB_NAME" =~ ^[A-Za-z0-9_]+$ ]] || die "Invalid database name."
[[ "$DB_USER" =~ ^[A-Za-z0-9_]+$ ]] || die "Invalid database user."
[[ -z "$FTP_USER" || "$FTP_USER" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] || die "Invalid FTP username."

[[ -r /etc/os-release ]] || die "Cannot identify the operating system."
# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == "ubuntu" ]] || die "This script supports Ubuntu only."

if [[ -n "$FTP_USER" ]]; then
  getent passwd "$FTP_USER" >/dev/null || die "User '$FTP_USER' does not exist. Create it first."
fi

TEMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf -- "$TEMP_DIR"
}
trap cleanup EXIT

export DEBIAN_FRONTEND=noninteractive

log "Installing Apache, PHP-FPM, MariaDB, and firewall packages"
apt-get update
apt-get install -y \
  apache2 mariadb-server ufw curl unzip ca-certificates openssl \
  php php-cli php-fpm php-mysql php-xml php-gd php-curl php-mbstring \
  php-zip php-intl php-bcmath php-opcache

PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
dpkg --compare-versions "$PHP_VERSION" ge 8.3 \
  || die "Joomla 6 requires PHP 8.3 or newer; installed version is $PHP_VERSION."

PHP_FPM_SERVICE="php${PHP_VERSION}-fpm"
PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"
[[ -f "$PHP_INI" ]] || die "PHP-FPM configuration not found: $PHP_INI"

set_ini() {
  local key="$1"
  local value="$2"
  if grep -Eq "^[[:space:];]*${key}[[:space:]]*=" "$PHP_INI"; then
    sed -Ei "s|^[[:space:];]*${key}[[:space:]]*=.*|${key} = ${value}|" "$PHP_INI"
  else
    printf '%s = %s\n' "$key" "$value" >>"$PHP_INI"
  fi
}

log "Configuring PHP ${PHP_VERSION}"
set_ini "expose_php" "Off"
set_ini "memory_limit" "256M"
set_ini "upload_max_filesize" "64M"
set_ini "post_max_size" "80M"
set_ini "max_execution_time" "120"
set_ini "max_input_time" "120"
set_ini "max_input_vars" "5000"
set_ini "date.timezone" "$PHP_TIMEZONE"
set_ini "session.cookie_httponly" "1"
set_ini "session.cookie_samesite" "Lax"
set_ini "opcache.enable" "1"
set_ini "opcache.validate_timestamps" "1"

systemctl enable --now "$PHP_FPM_SERVICE"

log "Configuring MariaDB for local-only access"
install -d -m 0755 /etc/mysql/mariadb.conf.d
cat >/etc/mysql/mariadb.conf.d/60-joomla-bind.cnf <<'EOF'
[mysqld]
bind-address = 127.0.0.1
skip-name-resolve
local-infile = 0
EOF

systemctl enable --now mariadb
systemctl restart mariadb

DB_PASSWORD="$(openssl rand -hex 24)"
SQL_PASSWORD="${DB_PASSWORD//\\/\\\\}"
SQL_PASSWORD="${SQL_PASSWORD//\'/\'\'}"

if mariadb --protocol=socket --batch --skip-column-names \
  -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${DB_NAME}'" \
  | grep -Fxq "$DB_NAME"; then
  die "Database '$DB_NAME' already exists. Choose another --db-name; existing data was not changed."
fi

if mariadb --protocol=socket --batch --skip-column-names \
  -e "SELECT User FROM mysql.user WHERE User='${DB_USER}' AND Host='localhost'" \
  | grep -Fxq "$DB_USER"; then
  die "Database user '$DB_USER'@'localhost' already exists. Choose another --db-user; its password was not changed."
fi

mariadb --protocol=socket <<SQL
DROP USER IF EXISTS ''@'localhost';
DROP DATABASE IF EXISTS test;
CREATE DATABASE \`${DB_NAME}\`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${SQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

log "Downloading and verifying Joomla ${JOOMLA_VERSION}"
ARCHIVE_PATH="${TEMP_DIR}/${JOOMLA_ARCHIVE}"
curl --fail --location --proto '=https' --tlsv1.2 \
  --retry 3 --retry-delay 2 \
  --output "$ARCHIVE_PATH" "$JOOMLA_URL"

printf '%s  %s\n' "$JOOMLA_SHA1" "$ARCHIVE_PATH" | sha1sum --check --status \
  || die "Joomla archive checksum verification failed."

install -d -m 0750 "$BACKUP_ROOT"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
install -d -m 0750 "$BACKUP_DIR"

systemctl stop apache2 || true

if [[ -e "$WEB_ROOT" ]]; then
  log "Moving the previous web root into ${BACKUP_DIR}"
  mv -- "$WEB_ROOT" "${BACKUP_DIR}/web-root"
fi

install -d -o root -g root -m 0755 "$WEB_ROOT"
unzip -q "$ARCHIVE_PATH" -d "$WEB_ROOT"

log "Applying least-privilege Joomla filesystem permissions"
getent group "$EDITOR_GROUP" >/dev/null || groupadd --system "$EDITOR_GROUP"
if [[ -n "$FTP_USER" ]]; then
  usermod -aG "$EDITOR_GROUP" "$FTP_USER"
fi

chown -R root:"$EDITOR_GROUP" "$WEB_ROOT"
if [[ -n "$FTP_USER" ]]; then
  find "$WEB_ROOT" -type d -exec chmod 2775 {} +
  find "$WEB_ROOT" -type f -exec chmod 0664 {} +
else
  find "$WEB_ROOT" -type d -exec chmod 2755 {} +
  find "$WEB_ROOT" -type f -exec chmod 0644 {} +
fi

# Joomla runtime paths. The web server may write here, but not into PHP source.
for runtime_path in \
  "$WEB_ROOT/cache" \
  "$WEB_ROOT/tmp" \
  "$WEB_ROOT/images" \
  "$WEB_ROOT/administrator/cache" \
  "$WEB_ROOT/administrator/logs"; do
  install -d -o www-data -g www-data -m 2775 "$runtime_path"
  chown -R www-data:www-data "$runtime_path"
  find "$runtime_path" -type d -exec chmod 2775 {} +
  find "$runtime_path" -type f -exec chmod 0664 {} +
done

# Let the web installer write the initial Joomla configuration. Lock it after setup.
install -o www-data -g www-data -m 0660 /dev/null "$WEB_ROOT/configuration.php"

log "Installing the safe post-install cleanup command"
cat >/usr/local/sbin/joomla-finish-install <<FINISH_INSTALL
#!/usr/bin/env bash
set -Eeuo pipefail

WEB_ROOT='${WEB_ROOT}'
EDITOR_GROUP='${EDITOR_GROUP}'
INSTALL_DIR="\${WEB_ROOT}/installation"
CONFIG_FILE="\${WEB_ROOT}/configuration.php"

die() {
  printf 'ERROR: %s\n' "\$*" >&2
  exit 1
}

[[ \${EUID} -eq 0 ]] || die "Run this command with sudo."
[[ "\$WEB_ROOT" != "/" && "\$INSTALL_DIR" == "\$WEB_ROOT/installation" ]] \
  || die "Unsafe installation directory path."
[[ -s "\$CONFIG_FILE" ]] \
  || die "Joomla is not installed yet: configuration.php is empty or missing."
grep -Eq 'class[[:space:]]+JConfig' "\$CONFIG_FILE" \
  || die "configuration.php does not look like a completed Joomla configuration."

if [[ -d "\$INSTALL_DIR" ]]; then
  rm -rf -- "\$INSTALL_DIR"
fi

chown root:"\$EDITOR_GROUP" "\$CONFIG_FILE"
chmod 0640 "\$CONFIG_FILE"

printf '\nYeah! Joomla installation completed! 🎉\n'
printf 'Deleted: %s\n' "\$INSTALL_DIR"
printf 'Locked: %s (root:%s, mode 0640)\n' "\$CONFIG_FILE" "\$EDITOR_GROUP"
FINISH_INSTALL
chmod 0755 /usr/local/sbin/joomla-finish-install

log "Configuring Apache and PHP-FPM"
a2enmod proxy_fcgi setenvif rewrite headers ssl >/dev/null
a2enconf "php${PHP_VERSION}-fpm" >/dev/null

cat >/etc/apache2/conf-available/joomla-security.conf <<'APACHE_SECURITY'
ServerTokens Prod
ServerSignature Off
TraceEnable Off
APACHE_SECURITY
a2enconf joomla-security >/dev/null

if [[ -f /etc/apache2/sites-available/joomla.conf ]]; then
  cp -a /etc/apache2/sites-available/joomla.conf "${BACKUP_DIR}/joomla.conf.previous"
fi

cat >/etc/apache2/sites-available/joomla.conf <<APACHE_VHOST
<VirtualHost *:80>
    DocumentRoot ${WEB_ROOT}

    <Directory ${WEB_ROOT}>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch "^(configuration\\.php|README\\.txt|LICENSE\\.txt|htaccess\\.txt|web\\.config\\.txt)$">
        Require all denied
    </FilesMatch>

    <FilesMatch "^\\.">
        Require all denied
    </FilesMatch>

    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    Header always set Permissions-Policy "camera=(), microphone=(), geolocation=()"

    ErrorLog \${APACHE_LOG_DIR}/joomla-error.log
    CustomLog \${APACHE_LOG_DIR}/joomla-access.log combined
</VirtualHost>
APACHE_VHOST

a2dissite 000-default >/dev/null || true
a2ensite joomla >/dev/null
apache2ctl configtest
systemctl enable --now apache2
systemctl restart apache2

log "Configuring UFW"
if [[ "$RESET_FIREWALL" == true ]]; then
  ufw --force reset
fi

ufw default deny incoming
ufw default allow outgoing

mapfile -t SSH_PORTS < <(/usr/sbin/sshd -T 2>/dev/null | awk '$1 == "port" {print $2}' | sort -nu)
if [[ ${#SSH_PORTS[@]} -eq 0 ]]; then
  SSH_PORTS=(22)
fi

for ssh_port in "${SSH_PORTS[@]}"; do
  ufw allow "${ssh_port}/tcp" comment 'SSH'
done
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw --force enable

log "Writing root-only installation credentials"
umask 077
cat >/root/joomla-install-credentials.txt <<CREDS
Joomla URL: http://SERVER-IP/installation/index.php
Database type: MySQLi
Database host: localhost
Database name: ${DB_NAME}
Database username: ${DB_USER}
Database password: ${DB_PASSWORD}
CREDS
chmod 0600 /root/joomla-install-credentials.txt

log "Running final checks"
systemctl is-active --quiet apache2
systemctl is-active --quiet "$PHP_FPM_SERVICE"
systemctl is-active --quiet mariadb
apache2ctl configtest >/dev/null
php -r 'foreach (["json","SimpleXML","dom","zlib","gd","mysqli","mbstring"] as $m) { if (!extension_loaded($m)) { fwrite(STDERR, "Missing PHP module: $m\n"); exit(1); } }'

cat <<EOF

Yeah! Joomla ${JOOMLA_VERSION} server setup is ready! 🎉

Open in a browser:
  http://SERVER-IP/installation/index.php

Joomla database credentials
----------------------------
Database type : MySQLi
Database host : localhost
Database name : ${DB_NAME}
Username      : ${DB_USER}
Password      : ${DB_PASSWORD}

A root-only copy is saved at:
  /root/joomla-install-credentials.txt

After the browser installer finishes, only one final command remains:
  sudo joomla-finish-install

Don't forget: this safely deletes ${WEB_ROOT}/installation and locks
configuration.php. It refuses to run until Joomla installation is complete.

If --ftp-user was used, disconnect and reconnect the FTP/SFTP session so the
new group membership becomes active.

This script does not change the system hostname or configure a domain name.
HTTPS is not enabled until the server owner adds a domain and valid certificate;
TCP port 443 is only reserved in UFW.

Firewall status:
EOF
ufw status verbose

if [[ "$RESET_FIREWALL" == false ]]; then
  cat <<'EOF'

Note: Existing UFW allow rules were preserved. To guarantee that only SSH,
HTTP, and HTTPS are allowed, review `sudo ufw status numbered`, or rerun this
script on a fresh server with --reset-firewall.
EOF
fi

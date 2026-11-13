# คู่มือติดตั้ง Joomla 6.2 บน Ubuntu 24.04 ฉบับสมบูรณ์

คู่มือนี้อธิบายการติดตั้ง **Joomla 6.2.0** บน Ubuntu 24.04 โดยใช้ Apache, PHP-FPM, MariaDB และ UFW ตั้งแต่เครื่องเปล่าจนพร้อมใช้งาน รวมถึง permission, SFTP, HTTPS, phpMyAdmin แบบ optional, การตรวจสอบ และการแก้ปัญหาที่พบบ่อย

> [!IMPORTANT]
> เลือกเพียงทางเดียว: **ติดตั้งด้วยสคริปต์** หรือ **ติดตั้งด้วยมือ** ไม่ควรทำสองวิธีซ้ำกันกลางทาง เพราะฐานข้อมูล VirtualHost และ permission อาจชนกัน

## สารบัญ

1. [สถาปัตยกรรม](#1-สถาปัตยกรรม)
2. [ข้อกำหนด](#2-ข้อกำหนด)
3. [ติดตั้งด้วยสคริปต์](#3-ติดตั้งด้วยสคริปต์)
4. [ติดตั้งด้วยมือ](#4-ติดตั้งด้วยมือ)
5. [ติดตั้งผ่านหน้าเว็บ](#5-ติดตั้งผ่านหน้าเว็บ)
6. [ปิดงานหลังติดตั้ง](#6-ปิดงานหลังติดตั้ง)
7. [FTP/SFTP user](#7-ftpsftp-user)
8. [HTTPS](#8-https)
9. [phpMyAdmin แบบ Optional](#9-phpmyadmin-แบบ-optional)
10. [ตรวจสอบความปลอดภัย](#10-ตรวจสอบความปลอดภัย)
11. [สำรองและกู้คืน](#11-สำรองและกู้คืน)
12. [แก้ปัญหาที่พบบ่อย](#12-แก้ปัญหาที่พบบ่อย)
13. [Checklist](#13-checklist)

---

## 1. สถาปัตยกรรม

```text
ผู้ใช้งาน
   │ HTTP :80 / HTTPS :443
   ▼
Apache 2.4 → PHP-FPM 8.3+ → Joomla 6.2.0
                                  │
                                  ▼
                         MariaDB 127.0.0.1:3306

ผู้ดูแลระบบ ── SSH/SFTP :22 หรือพอร์ต SSH ที่กำหนดเอง
```

MariaDB ไม่ควรถูก expose ออกสู่เครือข่าย Joomla เชื่อมต่อฐานข้อมูลผ่าน `localhost` เท่านั้น

## 2. ข้อกำหนด

- Ubuntu Server 24.04
- สิทธิ์ `sudo` หรือ `root`
- RAM แนะนำอย่างน้อย 2 GB
- พื้นที่ว่างอย่างน้อย 5 GB
- อินเทอร์เน็ตสำหรับดาวน์โหลดแพ็กเกจ
- Apache 2.4
- PHP 8.3 ขึ้นไป
- MariaDB 10.4 ขึ้นไป

Joomla 6.x ต้องใช้ PHP modules เช่น JSON, SimpleXML, DOM, Zlib, GD และ MySQL driver และแนะนำ Mbstring

ตรวจสอบและอัปเดตระบบ:

```bash
cat /etc/os-release
uname -m
sudo apt update
sudo apt upgrade -y
```

หากเข้าผ่าน SSH ควรเปิด session สำรองไว้อีกหน้าต่างก่อนแก้ firewall

---

## 3. ติดตั้งด้วยสคริปต์

ไฟล์ที่ใช้คือ `setup-joomla-6.2-ubuntu.sh`

### 3.1 ตรวจสคริปต์

```bash
bash -n setup-joomla-6.2-ubuntu.sh
less setup-joomla-6.2-ubuntu.sh
```

### 3.2 เตรียมบัญชี FTP/SFTP (ถ้าต้องการ)

```bash
id ftpuser
```

หากยังไม่มีและต้องการบัญชี local ปกติ:

```bash
sudo adduser ftpuser
```

> [!NOTE]
> `adduser` สร้างบัญชีที่ login shell ได้ด้วย หากต้องการ SFTP-only ควรตั้ง OpenSSH `internal-sftp` และ chroot แยกต่างหาก

### 3.3 รันสคริปต์

เครื่องใหม่ที่ต้องการล้าง UFW rules เดิม:

```bash
sudo bash setup-joomla-6.2-ubuntu.sh \
  --db-name joomla62 \
  --db-user joomla62 \
  --ftp-user ftpuser \
  --reset-firewall
```

ถ้าต้องเก็บ UFW rules เดิม ให้ตัด `--reset-firewall` ออก:

```bash
sudo bash setup-joomla-6.2-ubuntu.sh \
  --db-name joomla62 \
  --db-user joomla62 \
  --ftp-user ftpuser
```

> [!CAUTION]
> `--reset-firewall` ลบ UFW rules เดิมทั้งหมด ก่อนอนุญาต SSH port ที่ตรวจพบ, TCP 80 และ TCP 443

### 3.4 บันทึกข้อมูลฐานข้อมูล

สคริปต์จะแสดง:

```text
Database type : MySQLi
Database host : localhost
Database name : joomla62
Username      : joomla62
Password      : <generated password>
```

สำเนา root-only อยู่ที่:

```bash
sudo cat /root/joomla-install-credentials.txt
```

จากนั้นไปที่ [หัวข้อ 5](#5-ติดตั้งผ่านหน้าเว็บ)

---

## 4. ติดตั้งด้วยมือ

### 4.1 ติดตั้งแพ็กเกจ

```bash
sudo apt update
sudo apt install -y \
  apache2 mariadb-server ufw curl unzip ca-certificates openssl \
  php php-cli php-fpm php-mysql php-xml php-gd php-curl php-mbstring \
  php-zip php-intl php-bcmath php-opcache
```

ตรวจสอบเวอร์ชัน:

```bash
apache2 -v
php -v
mariadb --version
php -r 'exit(version_compare(PHP_VERSION, "8.3.0", ">=") ? 0 : 1);' \
  && echo 'PHP version OK' || echo 'PHP 8.3 or newer is required'
```

### 4.2 ตรวจ PHP modules

```bash
php -r '
foreach (["json", "SimpleXML", "dom", "zlib", "gd", "mysqli", "mbstring"] as $m) {
    printf("%-12s %s\n", $m, extension_loaded($m) ? "OK" : "MISSING");
}'
```

### 4.3 ตั้งค่า PHP-FPM

```bash
PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
sudoedit "/etc/php/${PHP_VERSION}/fpm/php.ini"
```

แก้ค่าบรรทัดเดิม ไม่เพิ่มค่าซ้ำ:

```ini
expose_php = Off
memory_limit = 256M
upload_max_filesize = 64M
post_max_size = 80M
max_execution_time = 120
max_input_time = 120
max_input_vars = 5000
date.timezone = Asia/Bangkok
session.cookie_httponly = 1
session.cookie_samesite = Lax
opcache.enable = 1
opcache.validate_timestamps = 1
```

```bash
sudo systemctl enable --now "php${PHP_VERSION}-fpm"
sudo systemctl restart "php${PHP_VERSION}-fpm"
```

### 4.4 ตั้ง MariaDB ให้รับเฉพาะ localhost

```bash
sudo tee /etc/mysql/mariadb.conf.d/60-joomla-bind.cnf >/dev/null <<'EOF'
[mysqld]
bind-address = 127.0.0.1
skip-name-resolve
local-infile = 0
EOF

sudo systemctl enable --now mariadb
sudo systemctl restart mariadb
sudo ss -lntp | grep ':3306'
```

ผลควรเป็น `127.0.0.1:3306` ไม่ใช่ `0.0.0.0:3306`

### 4.5 สร้างฐานข้อมูลและผู้ใช้

```bash
DB_NAME='joomla62'
DB_USER='joomla62'
DB_PASSWORD="$(openssl rand -hex 24)"
```

ตรวจว่าชื่อยังไม่ถูกใช้:

```bash
sudo mariadb -NBe "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${DB_NAME}'"
sudo mariadb -NBe "SELECT User FROM mysql.user WHERE User='${DB_USER}' AND Host='localhost'"
```

ถ้าไม่มีผลลัพธ์ ให้สร้าง:

```bash
sudo mariadb <<SQL
CREATE DATABASE \`${DB_NAME}\`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

printf 'Database: %s\nUsername: %s\nPassword: %s\n' \
  "$DB_NAME" "$DB_USER" "$DB_PASSWORD"
```

บันทึกรหัสผ่านใน password manager ก่อนปิด shell และห้าม commit รหัสผ่านลง Git

ทดสอบโดยไม่ใส่รหัสผ่านใน command line:

```bash
mariadb -u "$DB_USER" -p -h localhost "$DB_NAME"
```

### 4.6 ดาวน์โหลด Joomla 6.2.0

```bash
cd /tmp
curl --fail --location --proto '=https' --tlsv1.2 \
  --retry 3 --retry-delay 2 \
  --output Joomla_6-2-0-Stable-Full_Package.zip \
  'https://downloads.joomla.org/cms/joomla6/6-2-0/Joomla_6-2-0-Stable-Full_Package.zip?format=zip'
```

ตรวจ checksum ที่ Joomla ประกาศ:

```bash
echo '67a107c83b3084701a1a4acb151cd0452e5deaaf  Joomla_6-2-0-Stable-Full_Package.zip' \
  | sha1sum --check
```

ต้องแสดง `Joomla_6-2-0-Stable-Full_Package.zip: OK` หากไม่ตรง ห้ามติดตั้ง

### 4.7 สำรอง Document Root เดิม

> [!CAUTION]
> ขั้นตอนนี้ย้าย `/var/www/html` เดิม ตรวจให้แน่ใจว่าไม่มีเว็บอื่นอยู่ในโฟลเดอร์นี้

```bash
BACKUP_DIR="/var/backups/joomla-setup/$(date -u +%Y%m%dT%H%M%SZ)"
sudo install -d -m 0750 "$BACKUP_DIR"
sudo systemctl stop apache2

if [ -e /var/www/html ]; then
  sudo mv /var/www/html "$BACKUP_DIR/web-root"
fi

sudo install -d -o root -g root -m 0755 /var/www/html
sudo unzip -q /tmp/Joomla_6-2-0-Stable-Full_Package.zip -d /var/www/html
```

### 4.8 ตั้ง permission

```bash
sudo groupadd --system joomla-editors 2>/dev/null || true
sudo chown -R root:joomla-editors /var/www/html
sudo find /var/www/html -type d -exec chmod 2755 {} +
sudo find /var/www/html -type f -exec chmod 0644 {} +
```

เปิดสิทธิ์เขียนเฉพาะ runtime directories:

```bash
for path in \
  /var/www/html/cache \
  /var/www/html/tmp \
  /var/www/html/images \
  /var/www/html/administrator/cache \
  /var/www/html/administrator/logs; do
  sudo install -d -o www-data -g www-data -m 2775 "$path"
  sudo chown -R www-data:www-data "$path"
  sudo find "$path" -type d -exec chmod 2775 {} +
  sudo find "$path" -type f -exec chmod 0664 {} +
done

sudo install -o www-data -g www-data -m 0660 /dev/null \
  /var/www/html/configuration.php
```

ห้ามใช้ `chmod -R 777 /var/www/html`

### 4.9 ตั้ง Apache และ PHP-FPM

```bash
PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
sudo a2enmod proxy_fcgi setenvif rewrite headers ssl
sudo a2enconf "php${PHP_VERSION}-fpm"
```

ตั้งค่าลดข้อมูล version leakage:

```bash
sudo tee /etc/apache2/conf-available/joomla-security.conf >/dev/null <<'EOF'
ServerTokens Prod
ServerSignature Off
TraceEnable Off
EOF
sudo a2enconf joomla-security
```

สร้าง VirtualHost:

```bash
sudo tee /etc/apache2/sites-available/joomla.conf >/dev/null <<'EOF'
<VirtualHost *:80>
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch "^(configuration\.php|README\.txt|LICENSE\.txt|htaccess\.txt|web\.config\.txt)$">
        Require all denied
    </FilesMatch>

    <FilesMatch "^\.">
        Require all denied
    </FilesMatch>

    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    Header always set Permissions-Policy "camera=(), microphone=(), geolocation=()"

    ErrorLog ${APACHE_LOG_DIR}/joomla-error.log
    CustomLog ${APACHE_LOG_DIR}/joomla-access.log combined
</VirtualHost>
EOF

sudo a2dissite 000-default
sudo a2ensite joomla
sudo apache2ctl configtest
sudo systemctl enable --now apache2
sudo systemctl restart apache2
```

`apache2ctl configtest` ต้องแสดง `Syntax OK`

### 4.10 ตั้ง UFW

ตรวจ SSH port ก่อน:

```bash
sudo sshd -T | awk '$1 == "port" {print $2}'
```

สมมติผลเป็น `22`:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw enable
sudo ufw status verbose
```

ถ้า SSH ใช้พอร์ตอื่น ให้เปิดพอร์ตนั้นแทน `22` ก่อน enable ไม่ต้องเปิด `3306/tcp`

---

## 5. ติดตั้งผ่านหน้าเว็บ

หา IP:

```bash
hostname -I
```

เปิด `http://SERVER-IP/installation/index.php`

### 5.1 ตั้งค่าเว็บไซต์และ Super User

- เลือกภาษาและชื่อเว็บไซต์
- ใช้ Super User username ที่เดายาก ไม่จำเป็นต้องเป็น `admin`
- ใช้รหัสผ่านที่ไม่ซ้ำกับระบบอื่น
- ใช้อีเมลที่ผู้ดูแลเข้าถึงได้

บัญชี Joomla Super User เป็นคนละบัญชีกับ Linux user และ database user

### 5.2 ตั้งฐานข้อมูล

| ช่อง | ค่า |
|---|---|
| Database Type | `MySQLi` |
| Host Name | `localhost` |
| Username | เช่น `joomla62` |
| Password | รหัสที่สร้างไว้ |
| Database Name | เช่น `joomla62` |
| Table Prefix | ใช้ค่าที่ Joomla สุ่มให้ |

Joomla สร้าง Table Prefix ให้ แต่ไม่สร้าง database และ database user ให้

ก่อนกด Install ตรวจว่า PHP version/modules ผ่าน, เชื่อมฐานข้อมูลสำเร็จ และ path ของ log/tmp ไม่ว่าง

---

## 6. ปิดงานหลังติดตั้ง

หากใช้สคริปต์:

```bash
sudo joomla-finish-install
```

หากติดตั้งด้วยมือ ตรวจ configuration ก่อน:

```bash
sudo test -s /var/www/html/configuration.php \
  && sudo grep -q 'class JConfig' /var/www/html/configuration.php \
  && echo 'Joomla configuration found'
```

จากนั้นลบ installation และล็อก configuration:

```bash
sudo rm -rf -- /var/www/html/installation
sudo chown root:joomla-editors /var/www/html/configuration.php
sudo chmod 0640 /var/www/html/configuration.php
```

ตรวจสอบ:

```bash
test ! -d /var/www/html/installation && echo 'installation removed'
ls -l /var/www/html/configuration.php
```

ใน `configuration.php` ควรปิด debug:

```php
public $debug = false;
public $error_reporting = 'default';
```

---

## 7. FTP/SFTP user

แนะนำ **SFTP ผ่าน SSH** แทน FTP เพราะเข้ารหัสและไม่ต้องเปิด port 21/passive ports

```bash
id ftpuser
sudo groupadd --system joomla-editors 2>/dev/null || true
sudo usermod -aG joomla-editors ftpuser
sudo chgrp -R joomla-editors /var/www/html
sudo find /var/www/html -type d -exec chmod 2775 {} +
sudo find /var/www/html -type f -exec chmod 0664 {} +
sudo chmod 0640 /var/www/html/configuration.php
```

ผู้ใช้ต้อง disconnect/reconnect หลังเพิ่ม group ตรวจด้วย:

```bash
id ftpuser
namei -l /var/www/html
```

> [!WARNING]
> ผู้ที่เขียน Document Root ได้สามารถแก้ PHP code และยึดเว็บไซต์ได้ ให้สิทธิ์เฉพาะผู้ดูแลที่เชื่อถือได้

---

## 8. HTTPS

### ระบบที่มี Public Domain

ตั้ง DNS ให้ชี้มายังเซิร์ฟเวอร์ แล้วรัน:

```bash
sudo apt update
sudo apt install -y certbot python3-certbot-apache
sudo certbot --apache -d example.com -d www.example.com
sudo certbot renew --dry-run
```

เมื่อ HTTPS ใช้งานได้จริง ค่อยเปิด Force HTTPS ใน Joomla administrator

### ระบบภายในที่ใช้ Private IP

Let's Encrypt ไม่ออก certificate สำหรับ private IP ทั่วไป ใช้ Internal CA, reverse proxy ขององค์กร หรือ VPN พร้อม internal DNS แทน

อย่าล็อกอิน Joomla administrator ผ่าน HTTP บนเครือข่ายที่ไม่เชื่อถือ

---

## 9. phpMyAdmin แบบ Optional

phpMyAdmin ไม่จำเป็นต่อ Joomla และไม่ติดตั้งเป็นค่าเริ่มต้น เพราะเพิ่ม web login และ attack surface

หากต้องการจริง ควรทำหลังเปิด HTTPS:

```bash
sudo apt update
sudo apt install phpmyadmin
```

ระหว่างติดตั้ง เลือก Apache หากระบบถาม Web Server และห้ามใช้รหัสผ่านเดียวกับ Joomla Super User

จำกัด IP ตัวอย่างสำหรับวงบริหาร `10.1.2.0/24`:

```bash
sudo tee /etc/apache2/conf-available/zz-phpmyadmin-restrict.conf >/dev/null <<'EOF'
<Location /phpmyadmin>
    Require ip 10.1.2.0/24
</Location>
EOF

sudo a2enconf zz-phpmyadmin-restrict
sudo apache2ctl configtest
sudo systemctl reload apache2
```

เปลี่ยน subnet ให้ตรงกับวงบริหารจริง ถ้าไม่แน่ใจให้ใช้ VPN และไม่เปิด phpMyAdmin สู่สาธารณะ

---

## 10. ตรวจสอบความปลอดภัย

### 10.1 บริการที่ listen

```bash
sudo ss -lntup
```

ค่าที่คาดหวัง:

- SSH: เปิดตามพอร์ตที่กำหนด
- HTTP: port 80
- HTTPS: port 443 หลังตั้ง certificate
- MariaDB: `127.0.0.1:3306`

### 10.2 Firewall

```bash
sudo ufw status verbose
sudo ufw status numbered
```

ไม่ควรมี allow `3306/tcp` จากภายนอก

### 10.3 ตรวจจากเครื่องอื่น

```bash
nmap -Pn -sT -sV -p 22,80,443,3306 SERVER-IP
```

คาดหวังให้ SSH/HTTP เปิด, HTTPS เปิดเมื่อพร้อม และ `3306` ปิดหรือ filtered

### 10.4 HTTP headers

```bash
curl -I http://SERVER-IP/
```

ควรเห็นอย่างน้อย:

```text
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
Referrer-Policy: strict-origin-when-cross-origin
```

### 10.5 Permission

```bash
namei -l /var/www/html/configuration.php
sudo find /var/www/html -xdev -type d -perm -0002 -print
sudo find /var/www/html -xdev -type f -perm -0002 -print
```

ไม่ควรมีไฟล์หรือโฟลเดอร์ world-writable

---

## 11. สำรองและกู้คืน

### สำรองฐานข้อมูล

```bash
sudo mariadb-dump --single-transaction --routines --triggers \
  joomla62 | gzip > "joomla62-$(date +%F).sql.gz"
```

### สำรองไฟล์

```bash
sudo tar -C /var/www -czf "joomla-files-$(date +%F).tar.gz" html
```

เก็บ backup นอกเซิร์ฟเวอร์และทดสอบ restore เป็นระยะ

### กู้คืนฐานข้อมูล

```bash
gunzip -c joomla62-YYYY-MM-DD.sql.gz | sudo mariadb joomla62
```

### กู้ Document Root จาก backup ของสคริปต์

```bash
sudo systemctl stop apache2
sudo mv /var/www/html /var/www/html.failed
ls -1 /var/backups/joomla-setup
BACKUP_TIMESTAMP='20261113T080000Z'  # เปลี่ยนเป็นชื่อโฟลเดอร์จริง
sudo mv "/var/backups/joomla-setup/${BACKUP_TIMESTAMP}/web-root" /var/www/html
sudo systemctl start apache2
```

เปลี่ยน `BACKUP_TIMESTAMP` ให้ตรงกับชื่อโฟลเดอร์จริงก่อนรัน `mv`

---

## 12. แก้ปัญหาที่พบบ่อย

### 12.1 เปิดเว็บไม่ได้

```bash
sudo apache2ctl configtest
sudo systemctl status apache2 --no-pager
sudo journalctl -u apache2 -n 100 --no-pager
sudo tail -n 100 /var/log/apache2/joomla-error.log
sudo ufw status verbose
```

### 12.2 PHP แสดงเป็นข้อความหรือดาวน์โหลดไฟล์

```bash
PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
sudo a2enmod proxy_fcgi setenvif
sudo a2enconf "php${PHP_VERSION}-fpm"
sudo systemctl restart "php${PHP_VERSION}-fpm" apache2
```

### 12.3 Joomla เขียน configuration.php ไม่ได้

ระหว่างติดตั้ง:

```bash
sudo touch /var/www/html/configuration.php
sudo chown www-data:www-data /var/www/html/configuration.php
sudo chmod 0660 /var/www/html/configuration.php
```

หลังติดตั้งต้องล็อกกลับเป็น `0640`

### 12.4 Database connection error

```bash
sudo systemctl status mariadb --no-pager
sudo ss -lntp | grep ':3306'
mariadb -u joomla62 -p -h localhost joomla62
sudo mariadb -e "SHOW GRANTS FOR 'joomla62'@'localhost';"
```

### 12.5 `Path must not be empty`

ตรวจ path:

```bash
sudo grep -E 'public \$((log|tmp)_path)' /var/www/html/configuration.php
sudo -u www-data test -w /var/www/html/tmp && echo 'tmp writable'
sudo -u www-data test -w /var/www/html/administrator/logs && echo 'logs writable'
```

ล้าง cache โดยเก็บ `index.html`:

```bash
sudo find /var/www/html/cache -mindepth 1 -maxdepth 1 \
  ! -name index.html -exec rm -rf -- {} +
sudo find /var/www/html/administrator/cache -mindepth 1 -maxdepth 1 \
  ! -name index.html -exec rm -rf -- {} +
```

### 12.6 Upload file ใหญ่ไม่ได้

```bash
PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
grep -E '^(upload_max_filesize|post_max_size|memory_limit)' \
  "/etc/php/${PHP_VERSION}/fpm/php.ini"
sudo systemctl restart "php${PHP_VERSION}-fpm" apache2
```

ตรวจ Media options ใน Joomla ด้วย หาก Joomla จำกัดไว้ต่ำกว่า PHP

### 12.7 FTP/SFTP ลบไฟล์ไม่ได้

การลบขึ้นกับ write/execute permission ของโฟลเดอร์แม่:

```bash
id ftpuser
namei -l /var/www/html/path/to/file
```

หากเพิ่งเพิ่ม group ให้ reconnect ก่อน

### 12.8 เปิด Debug แล้วเข้า Administrator ได้ แต่ปิดแล้วไม่ได้

```bash
sudo tail -n 100 /var/log/apache2/joomla-error.log
sudo -u www-data test -w /var/www/html/cache
sudo -u www-data test -w /var/www/html/administrator/cache
```

หลังแก้ คืนค่า:

```php
public $debug = false;
public $error_reporting = 'default';
```

---

## 13. Checklist

- [ ] Joomla 6.2.0 ติดตั้งสำเร็จ
- [ ] ลบ `/var/www/html/installation` แล้ว
- [ ] `configuration.php` เป็น `0640` และไม่ world-writable
- [ ] Debug Mode ปิด
- [ ] MariaDB bind เฉพาะ `127.0.0.1`
- [ ] UFW ไม่เปิด `3306/tcp`
- [ ] เปิดเฉพาะ SSH, HTTP และ HTTPS ตามจำเป็น
- [ ] ใช้ SSH key สำหรับผู้ดูแลเมื่อทำได้
- [ ] เปิด HTTPS ก่อนให้ผู้ใช้จริงล็อกอิน
- [ ] Joomla Super User ใช้รหัสผ่านไม่ซ้ำและเปิด MFA
- [ ] จำกัด `/administrator` ผ่าน VPN/IP allowlist หากทำได้
- [ ] ไม่ติดตั้ง phpMyAdmin หากไม่จำเป็น
- [ ] ถ้ามี phpMyAdmin ต้องจำกัด IP/VPN และใช้ HTTPS
- [ ] สำรองทั้งฐานข้อมูลและไฟล์เว็บ
- [ ] ทดสอบ restore backup
- [ ] ตั้งรอบอัปเดต Joomla, extensions, Ubuntu และ PHP
- [ ] ตรวจ log และพื้นที่ดิสก์เป็นระยะ

---

## แหล่งข้อมูลอ้างอิง

- [Joomla 6.2.0 Downloads](https://downloads.joomla.org/cms/joomla6/6-2-0)
- [Joomla Technical Requirements](https://manual.joomla.org/docs/next/get-started/technical-requirements/)
- [Joomla Installation Guide](https://guide.joomla.org/user-manual/getting-started/getting-started-installing-joomla/)
- [Ubuntu Server: Apache](https://documentation.ubuntu.com/server/how-to/web-services/install-apache2/)
- [Ubuntu Server: PHP](https://documentation.ubuntu.com/server/how-to/web-services/install-php/)
- [Ubuntu Server: Firewall](https://documentation.ubuntu.com/server/how-to/security/firewalls/)

## หมายเหตุ

คู่มือนี้เป็น baseline สำหรับระบบภายในองค์กรหรือห้องทดลอง ผู้ดูแลต้องปรับ DNS, certificate, IP allowlist, backup retention และ monitoring ให้ตรงกับสภาพแวดล้อมจริง



# Joomla 6.2 Secure Setup Script

[ภาษาไทย](#ภาษาไทย) · [English](#english)

สคริปต์ Bash สำหรับเตรียม Joomla 6.2.0 บน Ubuntu 24.04 พร้อม Apache, PHP-FPM, MariaDB และ UFW โดยเน้นค่าเริ่มต้นที่ปลอดภัยและการติดตั้งผ่านหน้าเว็บของ Joomla

A Bash script for preparing Joomla 6.2.0 on Ubuntu 24.04 with Apache, PHP-FPM, MariaDB, and UFW. It provides secure defaults while leaving the final site configuration to Joomla's browser installer.

> [!WARNING]
> This script is intended for a fresh server. Read the firewall and backup sections before running it on an existing system.

---

## ภาษาไทย

### คุณสมบัติ

- ดาวน์โหลด Joomla 6.2.0 จากแหล่งทางการและตรวจสอบ SHA-1 checksum
- ติดตั้ง Apache, PHP-FPM, MariaDB และ PHP extensions ที่ Joomla ต้องใช้
- กำหนด PHP upload limit เป็น 64 MB, POST limit เป็น 80 MB และ memory limit เป็น 256 MB
- ให้ MariaDB รับการเชื่อมต่อเฉพาะ `127.0.0.1`
- สร้างฐานข้อมูล ผู้ใช้ฐานข้อมูล และรหัสผ่านแบบสุ่ม
- แสดงข้อมูลฐานข้อมูลบนหน้าจอและบันทึกสำเนาแบบ root-only
- สำรอง Document Root เดิมก่อนติดตั้ง Joomla
- ตั้ง permission โดยไม่ใช้ `777`
- รองรับการเพิ่มบัญชี FTP/SFTP ที่มีอยู่แล้วเข้า `joomla-editors`
- ตั้ง Apache security headers และปิด directory listing
- ตั้ง UFW ให้เปิด SSH, HTTP และ HTTPS
- สร้างคำสั่ง `joomla-finish-install` สำหรับลบโฟลเดอร์ installation และล็อก `configuration.php`
- ไม่เปลี่ยน hostname และไม่ตั้ง domain name ให้เครื่อง

### ข้อกำหนด

- Ubuntu 24.04
- สิทธิ์ `root` หรือ `sudo`
- อินเทอร์เน็ตสำหรับดาวน์โหลดแพ็กเกจและ Joomla
- PHP 8.3 ขึ้นไป ซึ่งสคริปต์จะติดตั้งจาก repository ของ Ubuntu
- หากใช้ `--ftp-user` บัญชีนั้นต้องมีอยู่ก่อนแล้ว

### เริ่มใช้งานอย่างรวดเร็ว

ตรวจสอบสคริปต์ก่อนรัน:

```bash
less setup-joomla-6.2-ubuntu.sh
```

ตัวอย่างสำหรับเครื่องใหม่:

```bash
sudo bash setup-joomla-6.2-ubuntu.sh \
  --db-name joomla62 \
  --db-user joomla62 \
  --ftp-user ftpuser \
  --reset-firewall
```

หากไม่ต้องการล้างกฎ UFW เดิม ให้ตัด `--reset-firewall` ออก:

```bash
sudo bash setup-joomla-6.2-ubuntu.sh \
  --db-name joomla62 \
  --db-user joomla62 \
  --ftp-user ftpuser
```

### ตัวเลือก

| ตัวเลือก | ค่าเริ่มต้น | รายละเอียด |
|---|---|---|
| `--web-root PATH` | `/var/www/html` | ตำแหน่งติดตั้ง Joomla |
| `--db-name NAME` | `joomla` | ชื่อฐานข้อมูลที่จะสร้าง |
| `--db-user NAME` | `joomla` | ชื่อผู้ใช้ฐานข้อมูลที่จะสร้าง |
| `--ftp-user NAME` | ไม่กำหนด | เพิ่มบัญชีที่มีอยู่แล้วเข้า `joomla-editors` |
| `--reset-firewall` | ปิด | ล้างกฎ UFW เดิม แล้วเปิดเฉพาะ SSH, TCP 80 และ TCP 443 |
| `-h`, `--help` | — | แสดงวิธีใช้งาน |

### ข้อมูลฐานข้อมูล

สคริปต์สร้างรหัสผ่านแบบสุ่มและแสดงข้อมูลที่ต้องกรอกใน Joomla installer:

```text
Database type : MySQLi
Database host : localhost
Database name : joomla62
Username      : joomla62
Password      : <generated password>
```

สำเนาจะถูกบันทึกไว้ที่:

```text
/root/joomla-install-credentials.txt
```

ไฟล์นี้มี permission `0600` และอ่านได้เฉพาะ root ไม่ควรคัดลอกไฟล์ดังกล่าวเข้า Git

Joomla จะสร้าง Table Prefix ให้เองในหน้า installer สคริปต์ไม่กำหนดค่านี้

### ขั้นตอนหลังรันสคริปต์

1. เปิดเบราว์เซอร์ไปที่:

   ```text
   http://SERVER-IP/installation/index.php
   ```

2. กรอกข้อมูลฐานข้อมูลที่สคริปต์แสดง
3. ตั้งชื่อเว็บไซต์และบัญชี Super User ของ Joomla
4. เมื่อติดตั้งผ่านหน้าเว็บเสร็จแล้ว รัน:

   ```bash
   sudo joomla-finish-install
   ```

คำสั่งนี้จะตรวจว่า `configuration.php` ถูกสร้างสมบูรณ์แล้ว จากนั้นจะ:

- ลบเฉพาะ `/var/www/html/installation` หรือโฟลเดอร์ installation ใต้ `--web-root`
- เปลี่ยนเจ้าของ `configuration.php` เป็น `root:joomla-editors`
- ตั้ง permission ของ `configuration.php` เป็น `0640`

### FTP/SFTP user

ตัวเลือก `--ftp-user`:

- ไม่สร้างบัญชีใหม่
- ไม่เปลี่ยนรหัสผ่านของบัญชี
- ไม่ติดตั้ง FTP server
- เพิ่มบัญชีที่มีอยู่แล้วเข้า group `joomla-editors`
- ตั้ง setgid บนโฟลเดอร์ Joomla เพื่อให้ไฟล์ใหม่สืบทอด group

หลังรันสคริปต์ ผู้ใช้ต้องออกจากระบบแล้วเชื่อมต่อ FTP/SFTP ใหม่ เพื่อให้ group membership ใหม่ทำงาน

หากใช้ SFTP จะเชื่อมต่อผ่าน SSH port เดิม ไม่ต้องเปิด FTP port 21

### Firewall

ค่าเริ่มต้นของ UFW:

- Default incoming: deny
- Default outgoing: allow
- Allow: SSH port ที่ตรวจพบจาก `sshd -T`
- Allow: TCP 80
- Allow: TCP 443

หากไม่ใส่ `--reset-firewall` กฎ allow เดิมจะยังอยู่

> [!CAUTION]
> `--reset-firewall` จะลบกฎ UFW เดิมทั้งหมด ใช้เฉพาะเมื่อแน่ใจว่าเครื่องควรเปิดเพียง SSH, HTTP และ HTTPS เท่านั้น

### Backup และการรันซ้ำ

Document Root เดิมจะถูกย้ายไปยัง:

```text
/var/backups/joomla-setup/<UTC-TIMESTAMP>/web-root
```

สคริปต์จะไม่เขียนทับฐานข้อมูลหรือผู้ใช้ฐานข้อมูลเดิม หากชื่อที่เลือกมีอยู่แล้ว สคริปต์จะหยุดและให้เลือก `--db-name` หรือ `--db-user` ใหม่

สคริปต์นี้จึงไม่ใช่ idempotent provisioner และไม่ควรรันซ้ำโดยไม่ตรวจสอบสถานะของระบบก่อน

### HTTPS

สคริปต์เปิด TCP 443 ใน UFW แต่ไม่ได้ติดตั้ง certificate หรือกำหนด domain name เจ้าของเซิร์ฟเวอร์ต้องตั้ง DNS และออก certificate ภายหลัง

ห้ามเปิด Joomla administrator ให้ผู้ใช้งานล็อกอินผ่าน HTTP บนเครือข่ายที่ไม่เชื่อถือ เพราะข้อมูลล็อกอินจะไม่ถูกเข้ารหัส

### phpMyAdmin

สคริปต์ไม่ติดตั้ง phpMyAdmin เป็นค่าเริ่มต้น เพื่อลดหน้า login และ attack surface ที่เปิดผ่านเว็บ การจัดการ MariaDB ทำผ่าน command line บนเซิร์ฟเวอร์ หากเพิ่ม phpMyAdmin ภายหลัง ควรเปิดผ่าน HTTPS และจำกัดการเข้าถึงด้วย VPN หรือ IP allowlist

### ตรวจสอบสถานะ

```bash
sudo systemctl status apache2
sudo systemctl status php8.3-fpm
sudo systemctl status mariadb
sudo ufw status verbose
sudo apache2ctl configtest
```

---

## English

### Features

- Downloads the official Joomla 6.2.0 package and verifies its SHA-1 checksum
- Installs Apache, PHP-FPM, MariaDB, and the PHP extensions required by Joomla
- Configures a 64 MB upload limit, 80 MB POST limit, and 256 MB PHP memory limit
- Binds MariaDB to `127.0.0.1` only
- Creates a database, database user, and random password
- Prints the database credentials and saves a root-only copy
- Backs up the existing Document Root before deploying Joomla
- Applies filesystem permissions without using `777`
- Optionally adds an existing FTP/SFTP account to `joomla-editors`
- Adds Apache security headers and disables directory listing
- Configures UFW for SSH, HTTP, and HTTPS
- Installs `joomla-finish-install` to remove the installer and lock `configuration.php`
- Does not change the system hostname or configure a domain name

### Requirements

- Ubuntu 24.04
- `root` or `sudo` privileges
- Internet access for packages and Joomla download
- PHP 8.3 or newer; the script installs the Ubuntu repository version
- An existing local account when using `--ftp-user`

### Quick start

Review the script before running it:

```bash
less setup-joomla-6.2-ubuntu.sh
```

Example for a fresh server:

```bash
sudo bash setup-joomla-6.2-ubuntu.sh \
  --db-name joomla62 \
  --db-user joomla62 \
  --ftp-user ftpuser \
  --reset-firewall
```

Omit `--reset-firewall` to preserve existing UFW allow rules:

```bash
sudo bash setup-joomla-6.2-ubuntu.sh \
  --db-name joomla62 \
  --db-user joomla62 \
  --ftp-user ftpuser
```

### Options

| Option | Default | Description |
|---|---|---|
| `--web-root PATH` | `/var/www/html` | Joomla installation path |
| `--db-name NAME` | `joomla` | Database to create |
| `--db-user NAME` | `joomla` | Database account to create |
| `--ftp-user NAME` | unset | Add an existing account to `joomla-editors` |
| `--reset-firewall` | disabled | Reset UFW, then allow only SSH, TCP 80, and TCP 443 |
| `-h`, `--help` | — | Display usage information |

### Database credentials

The script generates a random password and prints the values required by the Joomla installer:

```text
Database type : MySQLi
Database host : localhost
Database name : joomla62
Username      : joomla62
Password      : <generated password>
```

A copy is stored at:

```text
/root/joomla-install-credentials.txt
```

The file is created with mode `0600` and is readable only by root. Never commit it to Git.

Joomla generates its own table prefix in the browser installer. The script does not set one.

### After running the script

1. Open:

   ```text
   http://SERVER-IP/installation/index.php
   ```

2. Enter the database credentials printed by the script
3. Configure the site name and Joomla Super User account
4. After the browser installer finishes, run:

   ```bash
   sudo joomla-finish-install
   ```

This command verifies that `configuration.php` contains a completed Joomla configuration, then:

- Deletes only `/var/www/html/installation`, or the installation directory below the configured `--web-root`
- Changes `configuration.php` ownership to `root:joomla-editors`
- Sets `configuration.php` mode to `0640`

### FTP/SFTP account

The `--ftp-user` option:

- Does not create a new account
- Does not change the account password
- Does not install an FTP server
- Adds an existing account to the `joomla-editors` group
- Uses setgid directories so newly created files inherit the group

The user must disconnect and reconnect after the script completes for the new group membership to take effect.

SFTP uses the existing SSH port, so FTP port 21 does not need to be exposed.

### Firewall

UFW defaults:

- Default incoming: deny
- Default outgoing: allow
- Allow: SSH port(s) detected by `sshd -T`
- Allow: TCP 80
- Allow: TCP 443

Existing allow rules are preserved unless `--reset-firewall` is supplied.

> [!CAUTION]
> `--reset-firewall` removes all existing UFW rules. Use it only when the server should expose SSH, HTTP, and HTTPS exclusively.

### Backups and repeated runs

The existing Document Root is moved to:

```text
/var/backups/joomla-setup/<UTC-TIMESTAMP>/web-root
```

The script does not overwrite an existing database or database account. If a selected name already exists, it exits and asks for a different `--db-name` or `--db-user`.

This is not an idempotent provisioner. Do not rerun it without reviewing the current server state.

### HTTPS

The script allows TCP 443 through UFW, but it does not configure a domain or install a certificate. The server owner must configure DNS and TLS separately.

Do not allow users to sign in to the Joomla administrator over plain HTTP on an untrusted network because login credentials will not be encrypted in transit.

### phpMyAdmin

phpMyAdmin is not installed by default to avoid exposing another web login and increasing the attack surface. MariaDB administration is performed from the server command line. If phpMyAdmin is added later, serve it over HTTPS and restrict it through a VPN or an IP allowlist.

### Status checks

```bash
sudo systemctl status apache2
sudo systemctl status php8.3-fpm
sudo systemctl status mariadb
sudo ufw status verbose
sudo apache2ctl configtest
```

## Repository contents

```text
.
├── README.md
└── setup-joomla-6.2-ubuntu.sh
```

## License

No license has been selected yet. Add a `LICENSE` file before distributing the project if you want to grant reuse rights.

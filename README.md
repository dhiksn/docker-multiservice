# 🐳 TechCorp Multi-Service Docker Container

Container Debian yang menjalankan **Apache2**, **vsftpd**, dan **OpenSSH** secara bersamaan — siap pakai tanpa konfigurasi manual.

---

## 📁 Struktur File

```
docker-multiservice/
├── Dockerfile              # Image definition
├── docker-compose.yml      # Compose configuration
├── entrypoint.sh           # Service startup script
├── README.md               # Dokumentasi ini
├── config/
│   ├── vsftpd.conf         # Konfigurasi FTP server
│   ├── sshd_config         # Konfigurasi SSH server
│   └── authorized_keys     # SSH public key (GANTI dengan key Anda!)
└── html/
    └── index.html          # Halaman web profile perusahaan
```

---

## ⚡ Quick Start

### 1. Siapkan SSH Key

**WAJIB** — ganti placeholder key di `config/authorized_keys` dengan public key Anda:

```bash
# Generate key baru (jika belum punya)
ssh-keygen -t ed25519 -C "admin@techcorp.id"

# Copy public key ke config
cat ~/.ssh/id_ed25519.pub > config/authorized_keys
```

### 2. Build & Jalankan

```bash
# Masuk ke direktori project
cd docker-multiservice

# Build dan jalankan (background)
docker compose up -d --build

# Lihat log startup
docker compose logs -f
```

### 3. Cek Status

```bash
docker compose ps
docker exec techcorp-server ps aux
```

---

## 🌐 Akses Layanan

### Web (Apache2)
```
http://localhost:80              → Halaman profile perusahaan
http://localhost:80/wordpress    → WordPress (opsional)
```

### FTP (vsftpd)
```bash
# Menggunakan command line
ftp localhost 21
# Username: admin
# Password: admin123

# Menggunakan FileZilla
# Host: localhost | Port: 21 | Protocol: FTP
# User: admin | Pass: admin123
# Encryption: Only use plain FTP

# Upload file
ftp> cd ftp
ftp> put myfile.txt
```

### SSH (OpenSSH — key-based only)
```bash
# Login dengan private key
ssh -i ~/.ssh/id_ed25519 admin@localhost -p 22

# Atau jika key sudah di default location
ssh admin@localhost -p 22

# SFTP
sftp -i ~/.ssh/id_ed25519 admin@localhost
```

---

## 🔧 Manajemen Container

```bash
# Start
docker compose up -d

# Stop
docker compose down

# Restart
docker compose restart

# Lihat log real-time
docker compose logs -f

# Masuk ke container
docker exec -it techcorp-server bash

# Lihat log startup service
docker exec techcorp-server cat /var/log/services/startup.log
```

---

## 📦 Volumes

| Volume        | Path di Container       | Keterangan              |
|---------------|-------------------------|-------------------------|
| `webroot`     | `/var/www/html`         | File web Apache         |
| `ftpdata`     | `/home/admin/ftp`       | Upload/download FTP     |
| `logs`        | `/var/log/services`     | Log startup container   |
| `apache_logs` | `/var/log/apache2`      | Log Apache              |

```bash
# Lihat semua volume
docker volume ls

# Inspect volume
docker volume inspect docker-multiservice_webroot
```

---

## 🔒 Keamanan

- SSH: **password login dinonaktifkan**, hanya key-based
- SSH: root login dinonaktifkan
- FTP: user di-chroot ke home directory
- FTP: anonymous login dinonaktifkan
- SSH: cipher suite yang di-hardened

---

## 🛠️ Kustomisasi

### Ganti halaman web
```bash
# Edit langsung di volume
docker exec -it techcorp-server nano /var/www/html/index.html

# Atau copy file dari host
docker cp mypage.html techcorp-server:/var/www/html/index.html
```

### Tambah SSH user baru
```bash
docker exec -it techcorp-server bash
useradd -m -s /bin/bash newuser
mkdir -p /home/newuser/.ssh
echo "ssh-ed25519 AAAA... user@host" >> /home/newuser/.ssh/authorized_keys
chmod 700 /home/newuser/.ssh
chmod 600 /home/newuser/.ssh/authorized_keys
chown -R newuser:newuser /home/newuser/.ssh
```

### Ganti password FTP
```bash
docker exec -it techcorp-server bash
echo "admin:newpassword" | chpasswd
```

---

## 🐛 Troubleshooting

### FTP tidak bisa connect dari luar
Tambahkan `pasv_address` di `config/vsftpd.conf`:
```
pasv_address=YOUR_PUBLIC_IP
```

### SSH ditolak
```bash
# Cek authorized_keys sudah benar
docker exec techcorp-server cat /home/admin/.ssh/authorized_keys

# Cek permission
docker exec techcorp-server ls -la /home/admin/.ssh/
```

### Apache tidak start
```bash
docker exec techcorp-server apache2ctl configtest
docker exec techcorp-server cat /var/log/apache2/error.log
```

---

## 📋 Port Summary

| Service | Port | Protocol |
|---------|------|----------|
| HTTP    | 80   | TCP      |
| SSH     | 22   | TCP      |
| FTP     | 21   | TCP      |
| FTP Data| 20   | TCP      |
| FTP Passive | 21100-21110 | TCP |

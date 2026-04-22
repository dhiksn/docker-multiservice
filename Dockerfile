FROM debian:latest

LABEL maintainer="admin@techcorp.id"
LABEL description="Multi-service container: Apache2, vsftpd, OpenSSH"

# ─── Environment Variables ───────────────────────────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive \
    FTP_USER=admin \
    FTP_PASS=123 \
    APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data \
    APACHE_LOG_DIR=/var/log/apache2

# ─── Install semua package dalam satu layer ──────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        apache2 \
        vsftpd \
        openssh-server \
        curl \
        wget \
        php \
        php-mysql \
        php-curl \
        php-gd \
        php-mbstring \
        php-xml \
        php-zip \
        libapache2-mod-php \
        mariadb-client \
        unzip \
        ca-certificates \
        procps \
        net-tools \
        vim \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ─── Buat direktori yang diperlukan ──────────────────────────────────────────
RUN mkdir -p \
        /var/run/sshd \
        /var/run/vsftpd/empty \
        /home/${FTP_USER}/ftp \
        /var/log/services \
        /etc/ssh/authorized_keys

# ─── Setup FTP User ──────────────────────────────────────────────────────────
RUN useradd -m -s /bin/bash ${FTP_USER} \
    && echo "${FTP_USER}:${FTP_PASS}" | chpasswd \
    && chown root:root /home/${FTP_USER} \
    && chmod 755 /home/${FTP_USER} \
    && chown ${FTP_USER}:${FTP_USER} /home/${FTP_USER}/ftp \
    && chmod 755 /home/${FTP_USER}/ftp

# ─── Copy konfigurasi ────────────────────────────────────────────────────────
COPY config/vsftpd.conf /etc/vsftpd.conf
COPY config/sshd_config /etc/ssh/sshd_config
COPY config/authorized_keys /etc/ssh/authorized_keys/admin_key.pub
COPY html/index.html /var/www/html/index.html

# ─── Setup SSH authorized_keys ───────────────────────────────────────────────
# Filter baris komentar, hanya ambil baris key yang valid
RUN mkdir -p /root/.ssh /home/${FTP_USER}/.ssh \
    && grep -v '^#' /etc/ssh/authorized_keys/admin_key.pub | grep -v '^$' > /root/.ssh/authorized_keys || true \
    && grep -v '^#' /etc/ssh/authorized_keys/admin_key.pub | grep -v '^$' > /home/${FTP_USER}/.ssh/authorized_keys || true \
    && chmod 700 /root/.ssh \
    && chmod 600 /root/.ssh/authorized_keys \
    && chmod 700 /home/${FTP_USER}/.ssh \
    && chmod 600 /home/${FTP_USER}/.ssh/authorized_keys \
    && chown -R ${FTP_USER}:${FTP_USER} /home/${FTP_USER}/.ssh

# ─── Generate SSH Host Keys ──────────────────────────────────────────────────
RUN ssh-keygen -A

# ─── Setup Apache ────────────────────────────────────────────────────────────
RUN a2enmod rewrite \
    && PHP_MOD=$(ls /etc/apache2/mods-available/ | grep -oP 'php\d+\.\d+' | head -1) \
    && [ -n "$PHP_MOD" ] && a2enmod "$PHP_MOD" || true \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

# ─── Optional: Download WordPress ────────────────────────────────────────────
RUN cd /tmp \
    && wget -q https://wordpress.org/latest.tar.gz \
    && tar -xzf latest.tar.gz \
    && mv wordpress /var/www/html/wordpress \
    && chown -R www-data:www-data /var/www/html/wordpress \
    && chmod -R 755 /var/www/html/wordpress \
    && rm -f latest.tar.gz

# ─── Copy entrypoint ─────────────────────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ─── Expose ports ────────────────────────────────────────────────────────────
EXPOSE 22 21 80

# ─── Healthcheck ─────────────────────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

ENTRYPOINT ["/entrypoint.sh"]

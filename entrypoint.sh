#!/bin/bash
set -e

# ─── Warna untuk logging ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

LOG_FILE="/var/log/services/startup.log"
mkdir -p /var/log/services

log() {
    local level=$1
    shift
    local msg="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${msg}" | tee -a "$LOG_FILE"
}

log_info()    { log "${GREEN}INFO${NC} " "$@"; }
log_warn()    { log "${YELLOW}WARN${NC} " "$@"; }
log_error()   { log "${RED}ERROR${NC}" "$@"; }
log_section() { echo -e "\n${BLUE}══════════════════════════════════════${NC}"; log "${BLUE}....${NC}" "$@"; echo -e "${BLUE}══════════════════════════════════════${NC}"; }

# ─── Banner ───────────────────────────────────────────────────────────────────
echo -e "${BLUE}"
cat << 'EOF'
  ████████╗███████╗ ██████╗██╗  ██╗ ██████╗ ██████╗ ██████╗ 
  ╚══██╔══╝██╔════╝██╔════╝██║  ██║██╔════╝██╔═══██╗██╔══██╗
     ██║   █████╗  ██║     ███████║██║     ██║   ██║██████╔╝
     ██║   ██╔══╝  ██║     ██╔══██║██║     ██║   ██║██╔══██╗
     ██║   ███████╗╚██████╗██║  ██║╚██████╗╚██████╔╝██║  ██║
     ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝
  Multi-Service Container | Apache2 + vsftpd + OpenSSH
EOF
echo -e "${NC}"

log_info "Container starting up..."
log_info "Timestamp: $(date)"

# ─── 1. Start SSH Server ──────────────────────────────────────────────────────
log_section "Starting SSH Server (OpenSSH)"

# Pastikan host keys ada
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    log_warn "SSH host keys not found, generating..."
    ssh-keygen -A
fi

# Pastikan direktori run ada
mkdir -p /var/run/sshd

/usr/sbin/sshd -D &
SSH_PID=$!

sleep 1
if kill -0 $SSH_PID 2>/dev/null; then
    log_info "SSH Server started successfully (PID: $SSH_PID, Port: 22)"
else
    log_error "SSH Server failed to start!"
fi

# ─── 2. Start FTP Server ──────────────────────────────────────────────────────
log_section "Starting FTP Server (vsftpd)"

# Pastikan direktori vsftpd ada
mkdir -p /var/run/vsftpd/empty

# Pastikan user FTP ada
if ! id "${FTP_USER}" &>/dev/null; then
    log_warn "FTP user '${FTP_USER}' not found, creating..."
    useradd -m -s /bin/bash "${FTP_USER}"
    echo "${FTP_USER}:${FTP_PASS}" | chpasswd
fi

# Fix permission chroot — /home/admin harus root:root 755, TIDAK writable user
chown root:root /home/${FTP_USER}
chmod 755 /home/${FTP_USER}

# Pastikan subdirektori ftp/ ada dan dimiliki user
mkdir -p /home/${FTP_USER}/ftp
chown ${FTP_USER}:${FTP_USER} /home/${FTP_USER}/ftp
chmod 755 /home/${FTP_USER}/ftp

# Fix PAM vsftpd — gunakan pam_unix langsung (bypass issue PAM di container)
cat > /etc/pam.d/vsftpd << 'PAMEOF'
auth    required pam_unix.so
account required pam_unix.so
PAMEOF

log_info "FTP chroot permissions set correctly"

/usr/sbin/vsftpd /etc/vsftpd.conf &
FTP_PID=$!

sleep 1
if kill -0 $FTP_PID 2>/dev/null; then
    log_info "FTP Server started successfully (PID: $FTP_PID, Port: 21)"
else
    log_error "FTP Server failed to start!"
fi

# ─── 3. Start Apache Web Server ───────────────────────────────────────────────
log_section "Starting Web Server (Apache2)"

# Set ServerName untuk menghindari warning
echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Pastikan direktori log ada
mkdir -p /var/log/apache2

# Start Apache
/usr/sbin/apache2ctl start

sleep 1
if pgrep apache2 > /dev/null; then
    log_info "Apache2 started successfully (Port: 80)"
else
    log_error "Apache2 failed to start!"
fi

# ─── 4. Status Summary ────────────────────────────────────────────────────────
log_section "Service Status Summary"

check_service() {
    local name=$1
    local port=$2
    if ss -tlnp 2>/dev/null | grep -q ":${port}" || netstat -tlnp 2>/dev/null | grep -q ":${port}"; then
        log_info "✓ ${name} is running on port ${port}"
    else
        log_warn "✗ ${name} may not be running on port ${port}"
    fi
}

sleep 2
check_service "SSH"    22
check_service "FTP"    21
check_service "HTTP"   80

echo ""
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "  Web     → http://localhost:80"
log_info "  FTP     → ftp://localhost:21  (user: ${FTP_USER})"
log_info "  SSH     → ssh admin@localhost -p 22"
log_info "  WP      → http://localhost:80/wordpress"
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "Logs: ${LOG_FILE}"
log_info "Container is ready!"

# ─── 5. Keep container alive + monitor services ───────────────────────────────
log_section "Monitoring Services"

while true; do
    # Monitor SSH
    if ! kill -0 $SSH_PID 2>/dev/null; then
        log_warn "SSH died, restarting..."
        /usr/sbin/sshd -D &
        SSH_PID=$!
        log_info "SSH restarted (PID: $SSH_PID)"
    fi

    # Monitor vsftpd
    if ! kill -0 $FTP_PID 2>/dev/null; then
        log_warn "vsftpd died, restarting..."
        /usr/sbin/vsftpd /etc/vsftpd.conf &
        FTP_PID=$!
        log_info "vsftpd restarted (PID: $FTP_PID)"
    fi

    # Monitor Apache
    if ! pgrep apache2 > /dev/null; then
        log_warn "Apache2 died, restarting..."
        /usr/sbin/apache2ctl start
        log_info "Apache2 restarted"
    fi

    sleep 30
done

#!/bin/bash

# 마스토돈 봇 보안 강화 스크립트
# GCE 인스턴스에서 봇을 안전하게 운영하기 위한 보안 설정

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 로그 함수
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 권한 확인
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        log_error "이 스크립트는 root 권한이 필요합니다. sudo를 사용해주세요."
        exit 1
    fi
}

# 시스템 업데이트
update_system() {
    log_step "시스템 업데이트 중..."
    apt update && apt upgrade -y
    apt autoremove -y
    log_info "시스템 업데이트 완료"
}

# 불필요한 서비스 비활성화
disable_unnecessary_services() {
    log_step "불필요한 서비스 비활성화..."
    
    services_to_disable=(
        "bluetooth"
        "cups"
        "avahi-daemon"
        "whoopsie"
    )
    
    for service in "${services_to_disable[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            systemctl disable "$service" && log_info "$service 비활성화"
        fi
        if systemctl is-active "$service" &>/dev/null; then
            systemctl stop "$service" && log_info "$service 중지"
        fi
    done
}

# 방화벽 설정 (UFW)
configure_firewall() {
    log_step "방화벽 설정 중..."
    
    # UFW 설치 (이미 설치되어 있을 수 있음)
    apt install -y ufw
    
    # 기본 정책 설정
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # SSH 포트 허용 (현재 연결 유지를 위해)
    SSH_PORT=$(grep -E "^Port\s" /etc/ssh/sshd_config | awk '{print $2}' || echo "22")
    ufw allow "$SSH_PORT"/tcp comment 'SSH'
    
    # 로컬 루프백 허용
    ufw allow in on lo
    ufw allow out on lo
    
    # 방화벽 활성화
    ufw --force enable
    
    log_info "방화벽 설정 완료"
    ufw status verbose
}

# SSH 보안 강화
secure_ssh() {
    log_step "SSH 보안 설정 중..."
    
    # SSH 설정 백업
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # SSH 보안 설정
    cat > /etc/ssh/sshd_config.d/99-security.conf << 'EOF'
# SSH 보안 강화 설정

# Root 로그인 비활성화
PermitRootLogin no

# 패스워드 인증 비활성화 (키 기반 인증만 허용)
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# 프로토콜 버전 2만 사용
Protocol 2

# 최대 인증 시도 횟수 제한
MaxAuthTries 3

# 로그인 제한 시간
LoginGraceTime 30

# X11 포워딩 비활성화
X11Forwarding no

# TCP 포워딩 제한
AllowTcpForwarding no
GatewayPorts no

# 사용자별 접근 제한
AllowUsers botuser

# 유휴 연결 종료
ClientAliveInterval 300
ClientAliveCountMax 2

# 배너 설정
Banner /etc/ssh/banner
EOF

    # SSH 배너 생성
    cat > /etc/ssh/banner << 'EOF'
***************************************************************************
                    AUTHORIZED ACCESS ONLY
                    
This system is for authorized users only. All activities on this system
are logged and monitored. Unauthorized access is strictly prohibited.
***************************************************************************
EOF

    # SSH 서비스 재시작
    systemctl restart ssh
    log_info "SSH 보안 설정 완료"
}

# Fail2ban 설정
install_fail2ban() {
    log_step "Fail2ban 설치 및 설정..."
    
    apt install -y fail2ban
    
    # Fail2ban 설정
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[systemd-auth]
enabled = true
filter = systemd-auth
action = iptables-multiport[name=systemd-auth, port="ssh"]
logpath = /var/log/secure
maxretry = 3
bantime = 3600
EOF

    # Fail2ban 서비스 시작 및 활성화
    systemctl enable fail2ban
    systemctl start fail2ban
    
    log_info "Fail2ban 설정 완료"
}

# 파일 권한 강화
secure_file_permissions() {
    log_step "파일 권한 강화 중..."
    
    BOT_USER="botuser"
    BOT_DIR="/home/$BOT_USER/mastodon-bot"
    
    if [[ -d "$BOT_DIR" ]]; then
        # 봇 디렉토리 권한 설정
        chown -R $BOT_USER:$BOT_USER "$BOT_DIR"
        chmod 750 "$BOT_DIR"
        
        # 민감한 파일 권한 설정
        if [[ -f "$BOT_DIR/.env" ]]; then
            chmod 600 "$BOT_DIR/.env"
            chown $BOT_USER:$BOT_USER "$BOT_DIR/.env"
        fi
        
        if [[ -f "$BOT_DIR/service_account.json" ]]; then
            chmod 600 "$BOT_DIR/service_account.json"
            chown $BOT_USER:$BOT_USER "$BOT_DIR/service_account.json"
        fi
        
        # 스크립트 실행 권한 설정
        find "$BOT_DIR/scripts" -name "*.py" -exec chmod 750 {} \;
        find "$BOT_DIR/scripts" -name "*.sh" -exec chmod 750 {} \;
        
        # 로그 디렉토리 권한
        if [[ -d "$BOT_DIR/logs" ]]; then
            chmod 750 "$BOT_DIR/logs"
            chown -R $BOT_USER:$BOT_USER "$BOT_DIR/logs"
        fi
        
        log_info "봇 파일 권한 설정 완료"
    else
        log_warn "봇 디렉토리를 찾을 수 없습니다: $BOT_DIR"
    fi
    
    # 시스템 파일 권한 강화
    chmod 644 /etc/passwd
    chmod 600 /etc/shadow
    chmod 644 /etc/group
    chmod 600 /etc/gshadow
    
    log_info "시스템 파일 권한 강화 완료"
}

# 네트워크 보안 설정
configure_network_security() {
    log_step "네트워크 보안 설정 중..."
    
    # 커널 매개변수 보안 강화
    cat > /etc/sysctl.d/99-security.conf << 'EOF'
# 네트워크 보안 강화 설정

# IP 포워딩 비활성화
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# ICMP 리다이렉트 무시
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# 소스 라우팅 패킷 무시
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# SYN flood 공격 방어
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 3

# ICMP ping 응답 비활성화 (선택사항)
# net.ipv4.icmp_echo_ignore_all = 1

# 로그 마팅 공격 방어
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# 역방향 경로 필터링 활성화
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# IPv6 라우터 광고 무시
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
EOF

    # 설정 적용
    sysctl -p /etc/sysctl.d/99-security.conf
    
    log_info "네트워크 보안 설정 완료"
}

# 로그 모니터링 강화
enhance_logging() {
    log_step "로그 모니터링 강화 중..."
    
    # rsyslog 설정 강화
    cat >> /etc/rsyslog.conf << 'EOF'

# 보안 로그 강화
auth,authpriv.*                 /var/log/auth.log
*.*;auth,authpriv.none          /var/log/syslog
daemon.*                        /var/log/daemon.log
kern.*                          /var/log/kern.log
mail.*                          /var/log/mail.log
user.*                          /var/log/user.log
*.emerg                         :omusrmsg:*

# 원격 로깅 (필요시 주석 해제)
# *.* @@remote-log-server:514
EOF

    # 로그로테이션 설정
    cat > /etc/logrotate.d/mastodon-bot-security << 'EOF'
/var/log/auth.log
/var/log/syslog
/var/log/daemon.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF

    systemctl restart rsyslog
    log_info "로그 모니터링 설정 완료"
}

# 자동 보안 업데이트 설정
configure_automatic_updates() {
    log_step "자동 보안 업데이트 설정 중..."
    
    # unattended-upgrades 설치
    apt install -y unattended-upgrades apt-listchanges
    
    # 자동 업데이트 설정
    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

    # unattended-upgrades 상세 설정
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::Package-Blacklist {
    // "vim";
    // "libc6-dev";
};

Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";

Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailOnlyOnError "true";
EOF

    # 서비스 활성화
    systemctl enable unattended-upgrades
    systemctl start unattended-upgrades
    
    log_info "자동 보안 업데이트 설정 완료"
}

# AppArmor 설정 (추가 보안 계층)
configure_apparmor() {
    log_step "AppArmor 설정 중..."
    
    apt install -y apparmor-utils
    
    # AppArmor 상태 확인 및 활성화
    if ! aa-enabled &>/dev/null; then
        log_warn "AppArmor가 비활성화되어 있습니다. 수동으로 활성화해주세요."
    else
        # 기본 프로파일들을 enforce 모드로 설정
        aa-enforce /etc/apparmor.d/* 2>/dev/null || true
        log_info "AppArmor 프로파일 적용 완료"
    fi
}

# ClamAV 안티바이러스 설치 (선택사항)
install_antivirus() {
    if [[ "${1:-}" == "--with-antivirus" ]]; then
        log_step "ClamAV 안티바이러스 설치 중..."
        
        apt install -y clamav clamav-daemon
        
        # 바이러스 정의 업데이트
        freshclam
        
        # 주간 스캔 cron 작업 추가
        cat > /etc/cron.weekly/clamav-scan << 'EOF'
#!/bin/bash
# 주간 바이러스 스캔

SCAN_LOG="/var/log/clamav/weekly-scan.log"
SCAN_DIR="/home /etc /var/www"

echo "=== ClamAV 주간 스캔 시작: $(date) ===" >> "$SCAN_LOG"
clamscan -r --infected --remove=yes $SCAN_DIR >> "$SCAN_LOG" 2>&1
echo "=== 스캔 완료: $(date) ===" >> "$SCAN_LOG"
EOF

        chmod +x /etc/cron.weekly/clamav-scan
        
        systemctl enable clamav-daemon
        systemctl start clamav-daemon
        
        log_info "ClamAV 안티바이러스 설치 완료"
    fi
}

# 보안 모니터링 도구 설치
install_security_tools() {
    log_step "보안 모니터링 도구 설치 중..."
    
    # 기본 보안 도구들
    apt install -y \
        rkhunter \
        chkrootkit \
        lynis \
        auditd \
        psmisc \
        lsof \
        netstat-nat
    
    # rkhunter 설정 업데이트
    rkhunter --update
    rkhunter --propupd
    
    # 주간 보안 스캔 cron 작업
    cat > /etc/cron.weekly/security-scan << 'EOF'
#!/bin/bash
# 주간 보안 스캔

SCAN_LOG="/var/log/security-scan.log"

echo "=== 보안 스캔 시작: $(date) ===" >> "$SCAN_LOG"

echo "--- RKHunter 스캔 ---" >> "$SCAN_LOG"
rkhunter --check --skip-keypress --report-warnings-only >> "$SCAN_LOG" 2>&1

echo "--- Chkrootkit 스캔 ---" >> "$SCAN_LOG"
chkrootkit >> "$SCAN_LOG" 2>&1

echo "=== 보안 스캔 완료: $(date) ===" >> "$SCAN_LOG"
echo "" >> "$SCAN_LOG"
EOF

    chmod +x /etc/cron.weekly/security-scan
    
    # auditd 서비스 활성화
    systemctl enable auditd
    systemctl start auditd
    
    log_info "보안 모니터링 도구 설치 완료"
}

# 보안 상태 점검
security_audit() {
    log_step "보안 상태 점검 중..."
    
    echo "=== 보안 설정 점검 결과 ==="
    
    # 서비스 상태 확인
    echo "1. 중요 서비스 상태:"
    services=("ssh" "ufw" "fail2ban" "unattended-upgrades")
    for service in "${services[@]}"; do
        if systemctl is-active "$service" &>/dev/null; then
            echo "  ✅ $service: 활성"
        else
            echo "  ❌ $service: 비활성"
        fi
    done
    
    # 방화벽 상태
    echo -e "\n2. 방화벽 상태:"
    ufw status | head -5
    
    # SSH 설정 확인
    echo -e "\n3. SSH 보안 설정:"
    if grep -q "PermitRootLogin no" /etc/ssh/sshd_config* 2>/dev/null; then
        echo "  ✅ Root 로그인 비활성화됨"
    else
        echo "  ❌ Root 로그인 활성화됨"
    fi
    
    if grep -q "PasswordAuthentication no" /etc/ssh/sshd_config* 2>/dev/null; then
        echo "  ✅ 패스워드 인증 비활성화됨"
    else
        echo "  ❌ 패스워드 인증 활성화됨"
    fi
    
    # 업데이트 상태
    echo -e "\n4. 시스템 업데이트:"
    UPDATES=$(apt list --upgradable 2>/dev/null | grep -c "upgradable")
    echo "  업데이트 가능한 패키지: $UPDATES개"
    
    echo -e "\n=== 점검 완료 ==="
}

# 사용법 출력
usage() {
    cat << EOF
마스토돈 봇 보안 강화 스크립트

사용법: $0 [옵션]

옵션:
    --full              전체 보안 설정 적용
    --basic             기본 보안 설정만 적용
    --firewall-only     방화벽 설정만 적용
    --ssh-only          SSH 보안 설정만 적용
    --audit             보안 상태 점검만 실행
    --with-antivirus    안티바이러스 포함하여 설치
    --help              도움말 표시

예시:
    sudo $0 --full
    sudo $0 --basic
    sudo $0 --audit
EOF
}

# 메인 함수
main() {
    log_info "=== 마스토돈 봇 보안 강화 스크립트 ==="
    
    case "${1:-}" in
        --full)
            check_permissions
            update_system
            disable_unnecessary_services
            configure_firewall
            secure_ssh
            install_fail2ban
            secure_file_permissions
            configure_network_security
            enhance_logging
            configure_automatic_updates
            configure_apparmor
            install_security_tools
            security_audit
            log_info "=== 전체 보안 설정 완료 ==="
            ;;
        --full-with-av)
            check_permissions
            update_system
            disable_unnecessary_services
            configure_firewall
            secure_ssh
            install_fail2ban
            secure_file_permissions
            configure_network_security
            enhance_logging
            configure_automatic_updates
            configure_apparmor
            install_security_tools
            install_antivirus --with-antivirus
            security_audit
            log_info "=== 전체 보안 설정 (안티바이러스 포함) 완료 ==="
            ;;
        --basic)
            check_permissions
            update_system
            configure_firewall
            secure_ssh
            install_fail2ban
            secure_file_permissions
            log_info "=== 기본 보안 설정 완료 ==="
            ;;
        --firewall-only)
            check_permissions
            configure_firewall
            ;;
        --ssh-only)
            check_permissions
            secure_ssh
            ;;
        --audit)
            security_audit
            ;;
        --help|*)
            usage
            ;;
    esac
}

main "$@"
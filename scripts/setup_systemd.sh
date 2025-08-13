#!/bin/bash

# 마스토돈 봇 systemd 서비스 설정 스크립트

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 로그 함수들
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 설정 변수
BOT_USER="botuser"
BOT_DIR="/home/$BOT_USER/mastodon-bot"
SERVICE_NAME="mastodon-bot"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

# 권한 확인
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        log_error "이 스크립트는 root 권한이 필요합니다. sudo를 사용해주세요."
        exit 1
    fi
}

# 사용자 존재 확인
check_user() {
    if ! id "$BOT_USER" &>/dev/null; then
        log_error "사용자 '$BOT_USER'가 존재하지 않습니다."
        log_info "사용자 생성 중..."
        useradd -m -s /bin/bash $BOT_USER
        usermod -aG sudo $BOT_USER
        log_info "사용자 '$BOT_USER' 생성 완료"
    else
        log_info "사용자 '$BOT_USER' 확인됨"
    fi
}

# 디렉토리 및 파일 확인
check_bot_files() {
    if [[ ! -d "$BOT_DIR" ]]; then
        log_error "봇 디렉토리가 존재하지 않습니다: $BOT_DIR"
        exit 1
    fi
    
    required_files=("$BOT_DIR/main.py" "$BOT_DIR/.env" "$BOT_DIR/scripts/start_bot.py")
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "필수 파일이 없습니다: $file"
            exit 1
        fi
    done
    
    log_info "봇 파일들 확인 완료"
}

# 로그 디렉토리 생성
setup_log_directory() {
    local log_dir="$BOT_DIR/logs"
    
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir"
        chown $BOT_USER:$BOT_USER "$log_dir"
        log_info "로그 디렉토리 생성: $log_dir"
    fi
}

# systemd 서비스 파일 생성
create_service_file() {
    log_info "systemd 서비스 파일 생성 중..."
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Mastodon Spreadsheet Bot with Gacha System
Documentation=https://github.com/yourusername/mastodon-bot
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=$BOT_USER
Group=$BOT_USER
WorkingDirectory=$BOT_DIR
Environment=PATH=$BOT_DIR/venv/bin
Environment=PYTHONPATH=$BOT_DIR
Environment=BOT_DIR=$BOT_DIR

# 봇 매니저 스크립트 실행
ExecStart=$BOT_DIR/venv/bin/python $BOT_DIR/scripts/start_bot.py

# 재시작 정책
Restart=always
RestartSec=15
StartLimitBurst=5
StartLimitIntervalSec=300

# 로그 설정
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

# 보안 설정
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$BOT_DIR

# 프로세스 제한
LimitNOFILE=1024
LimitNPROC=512

# 환경 변수 파일
EnvironmentFile=$BOT_DIR/.env

[Install]
WantedBy=multi-user.target
EOF

    log_info "서비스 파일 생성 완료: $SERVICE_FILE"
}

# 파일 권한 설정
set_permissions() {
    log_info "파일 권한 설정 중..."
    
    # 봇 디렉토리 소유권 설정
    chown -R $BOT_USER:$BOT_USER "$BOT_DIR"
    
    # 실행 권한 설정
    chmod +x "$BOT_DIR/scripts/start_bot.py"
    chmod +x "$BOT_DIR/main.py"
    
    # 보안 파일 권한 설정
    chmod 600 "$BOT_DIR/.env" 2>/dev/null || true
    chmod 600 "$BOT_DIR/service_account.json" 2>/dev/null || true
    
    log_info "권한 설정 완료"
}

# systemd 서비스 활성화
enable_service() {
    log_info "systemd 서비스 설정 중..."
    
    # systemd 데몬 리로드
    systemctl daemon-reload
    
    # 서비스 활성화 (부팅 시 자동 시작)
    systemctl enable $SERVICE_NAME
    
    log_info "서비스 활성화 완료"
}

# 서비스 상태 확인
check_service_status() {
    log_info "서비스 상태 확인..."
    
    if systemctl is-enabled $SERVICE_NAME &>/dev/null; then
        log_info "✓ 서비스가 활성화되었습니다"
    else
        log_warn "✗ 서비스가 활성화되지 않았습니다"
    fi
    
    if systemctl is-active $SERVICE_NAME &>/dev/null; then
        log_info "✓ 서비스가 실행 중입니다"
    else
        log_warn "✗ 서비스가 실행 중이 아닙니다"
    fi
}

# 로그로테이션 설정
setup_logrotate() {
    log_info "로그 로테이션 설정 중..."
    
    cat > /etc/logrotate.d/mastodon-bot << EOF
$BOT_DIR/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 $BOT_USER $BOT_USER
    postrotate
        systemctl reload-or-restart $SERVICE_NAME > /dev/null 2>&1 || true
    endscript
}
EOF

    log_info "로그 로테이션 설정 완료"
}

# 모니터링 스크립트 생성
create_monitoring_script() {
    local monitor_script="$BOT_DIR/scripts/monitor_bot.sh"
    
    log_info "모니터링 스크립트 생성 중..."
    
    mkdir -p "$(dirname "$monitor_script")"
    
    cat > "$monitor_script" << 'EOF'
#!/bin/bash

# 마스토돈 봇 모니터링 스크립트

SERVICE_NAME="mastodon-bot"
LOG_FILE="/home/botuser/mastodon-bot/logs/monitor.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# 로그 함수
log_message() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

# 서비스 상태 확인
check_service() {
    if systemctl is-active $SERVICE_NAME > /dev/null 2>&1; then
        return 0  # 활성
    else
        return 1  # 비활성
    fi
}

# 메인 모니터링 로직
main() {
    if check_service; then
        log_message "OK: 마스토돈 봇이 정상 작동 중입니다."
        
        # 메모리 사용량 확인 (선택사항)
        MEMORY_USAGE=$(ps -o pid,ppid,%mem,%cpu,cmd -C python | grep mastodon-bot | awk '{print $3}')
        if [[ -n "$MEMORY_USAGE" ]]; then
            log_message "메모리 사용량: ${MEMORY_USAGE}%"
        fi
    else
        log_message "WARNING: 마스토돈 봇이 비활성 상태입니다. 재시작을 시도합니다."
        
        # 서비스 재시작 시도
        systemctl restart $SERVICE_NAME
        sleep 10
        
        if check_service; then
            log_message "SUCCESS: 봇이 성공적으로 재시작되었습니다."
        else
            log_message "ERROR: 봇 재시작에 실패했습니다. 수동 확인이 필요합니다."
            
            # 오류 로그 수집
            journalctl -u $SERVICE_NAME --since "5 minutes ago" >> "$LOG_FILE"
        fi
    fi
}

main "$@"
EOF

    chmod +x "$monitor_script"
    chown $BOT_USER:$BOT_USER "$monitor_script"
    
    log_info "모니터링 스크립트 생성 완료: $monitor_script"
}

# crontab 설정
setup_crontab() {
    log_info "crontab 모니터링 설정 중..."
    
    local monitor_script="$BOT_DIR/scripts/monitor_bot.sh"
    local cron_line="*/5 * * * * $monitor_script"
    
    # 기존 crontab 확인 및 추가
    if ! crontab -u $BOT_USER -l 2>/dev/null | grep -q "$monitor_script"; then
        (crontab -u $BOT_USER -l 2>/dev/null; echo "$cron_line") | crontab -u $BOT_USER -
        log_info "crontab에 모니터링 작업 추가됨 (5분마다 실행)"
    else
        log_info "crontab 모니터링이 이미 설정되어 있습니다"
    fi
}

# 사용법 출력
usage() {
    cat << EOF
사용법: $0 [옵션]

옵션:
    --install       systemd 서비스 설치 및 설정
    --start         서비스 시작
    --stop          서비스 중지
    --restart       서비스 재시작
    --status        서비스 상태 확인
    --logs          실시간 로그 보기
    --uninstall     서비스 제거
    --help          이 도움말 표시

예시:
    sudo $0 --install
    sudo $0 --start
    $0 --status
    $0 --logs
EOF
}

# 메인 실행 함수
main() {
    case "${1:-}" in
        --install)
            log_info "=== 마스토돈 봇 systemd 서비스 설치 시작 ==="
            check_permissions
            check_user
            check_bot_files
            setup_log_directory
            create_service_file
            set_permissions
            enable_service
            setup_logrotate
            create_monitoring_script
            setup_crontab
            check_service_status
            log_info "=== 설치 완료 ==="
            log_info "서비스를 시작하려면: sudo systemctl start $SERVICE_NAME"
            log_info "로그를 보려면: sudo journalctl -u $SERVICE_NAME -f"
            ;;
        --start)
            systemctl start $SERVICE_NAME
            log_info "서비스 시작됨"
            ;;
        --stop)
            systemctl stop $SERVICE_NAME
            log_info "서비스 중지됨"
            ;;
        --restart)
            systemctl restart $SERVICE_NAME
            log_info "서비스 재시작됨"
            ;;
        --status)
            systemctl status $SERVICE_NAME
            ;;
        --logs)
            journalctl -u $SERVICE_NAME -f
            ;;
        --uninstall)
            check_permissions
            systemctl stop $SERVICE_NAME 2>/dev/null || true
            systemctl disable $SERVICE_NAME 2>/dev/null || true
            rm -f "$SERVICE_FILE"
            systemctl daemon-reload
            log_info "서비스 제거 완료"
            ;;
        --help|*)
            usage
            ;;
    esac
}

main "$@"
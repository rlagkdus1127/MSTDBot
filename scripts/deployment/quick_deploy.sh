#!/bin/bash

# 마스토돈 봇 빠른 배포 스크립트
# GCE 인스턴스에서 봇을 빠르게 설정하고 실행하는 스크립트

set -e

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 설정 변수
BOT_USER="botuser"
BOT_DIR="/home/$BOT_USER/mastodon-bot"
VENV_DIR="$BOT_DIR/venv"
SERVICE_NAME="mastodon-bot"

# 권한 확인
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        log_error "이 스크립트는 일반 사용자로 실행해야 합니다. root로 실행하지 마세요."
        exit 1
    fi
    
    # botuser인지 확인
    if [[ $(whoami) != "$BOT_USER" ]]; then
        log_error "이 스크립트는 '$BOT_USER' 사용자로 실행해야 합니다."
        log_info "다음 명령어를 실행하세요: sudo su - $BOT_USER"
        exit 1
    fi
}

# 디렉토리 설정
setup_directories() {
    log_step "디렉토리 설정 중..."
    
    # 봇 디렉토리 생성
    mkdir -p "$BOT_DIR"
    cd "$BOT_DIR"
    
    # 필요한 하위 디렉토리 생성
    mkdir -p logs logs/health_reports
    mkdir -p scripts/monitoring scripts/security scripts/deployment
    
    log_info "디렉토리 설정 완료"
}

# Python 가상환경 설정
setup_python_environment() {
    log_step "Python 가상환경 설정 중..."
    
    # Python3와 pip 설치 확인
    if ! command -v python3 &> /dev/null; then
        log_error "Python3가 설치되어 있지 않습니다."
        log_info "다음 명령어로 설치하세요: sudo apt install python3 python3-pip python3-venv"
        exit 1
    fi
    
    # 가상환경 생성
    if [[ ! -d "$VENV_DIR" ]]; then
        python3 -m venv "$VENV_DIR"
        log_info "가상환경 생성 완료"
    fi
    
    # 가상환경 활성화
    source "$VENV_DIR/bin/activate"
    
    # pip 업그레이드
    pip install --upgrade pip
    
    # requirements.txt 확인 및 패키지 설치
    if [[ -f "$BOT_DIR/requirements.txt" ]]; then
        log_info "필요한 패키지 설치 중..."
        pip install -r "$BOT_DIR/requirements.txt"
    else
        log_warn "requirements.txt 파일을 찾을 수 없습니다."
        log_info "수동으로 패키지를 설치하세요."
    fi
    
    log_info "Python 환경 설정 완료"
}

# 환경 변수 설정 확인
check_environment_variables() {
    log_step "환경 변수 확인 중..."
    
    if [[ ! -f "$BOT_DIR/.env" ]]; then
        log_warn ".env 파일이 없습니다."
        
        if [[ -f "$BOT_DIR/.env.example" ]]; then
            log_info ".env.example을 복사합니다."
            cp "$BOT_DIR/.env.example" "$BOT_DIR/.env"
            log_warn ".env 파일을 편집하여 실제 값들을 설정해주세요:"
            log_info "nano $BOT_DIR/.env"
        else
            log_error ".env.example 파일도 없습니다. 환경 변수를 수동으로 설정해야 합니다."
        fi
        
        return 1
    fi
    
    # 필수 환경 변수 확인
    source "$BOT_DIR/.env"
    
    required_vars=(
        "MASTODON_ACCESS_TOKEN"
        "MASTODON_API_BASE_URL" 
        "GOOGLE_SERVICE_ACCOUNT_FILE"
        "SPREADSHEET_ID"
    )
    
    missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "다음 환경 변수들이 설정되지 않았습니다:"
        for var in "${missing_vars[@]}"; do
            log_error "  - $var"
        done
        return 1
    fi
    
    log_info "환경 변수 확인 완료"
    return 0
}

# 구글 서비스 계정 키 확인
check_google_credentials() {
    log_step "구글 서비스 계정 키 확인 중..."
    
    source "$BOT_DIR/.env"
    
    if [[ ! -f "$GOOGLE_SERVICE_ACCOUNT_FILE" ]]; then
        log_error "구글 서비스 계정 키 파일을 찾을 수 없습니다: $GOOGLE_SERVICE_ACCOUNT_FILE"
        log_info "다음 단계를 수행하세요:"
        log_info "1. Google Cloud Console에서 서비스 계정 키 다운로드"
        log_info "2. 키 파일을 $BOT_DIR/service_account.json에 저장"
        log_info "3. .env 파일에서 GOOGLE_SERVICE_ACCOUNT_FILE 경로 확인"
        return 1
    fi
    
    # 파일 권한 설정
    chmod 600 "$GOOGLE_SERVICE_ACCOUNT_FILE"
    
    log_info "구글 서비스 계정 키 확인 완료"
    return 0
}

# 봇 테스트 실행
test_bot() {
    log_step "봇 테스트 실행 중..."
    
    cd "$BOT_DIR"
    source "$VENV_DIR/bin/activate"
    
    # 간단한 연결 테스트 (타임아웃 적용)
    timeout 30s python3 -c "
import os
import sys
sys.path.append('.')
from google_sheets import GoogleSheetsManager
from mastodon_bot import MastodonBot

print('구글 시트 연결 테스트...')
google_sheets = GoogleSheetsManager(
    os.getenv('GOOGLE_SERVICE_ACCOUNT_FILE'),
    os.getenv('SPREADSHEET_ID')
)

keywords = google_sheets.get_keywords_data(os.getenv('KEYWORDS_SHEET_NAME', 'keywords'))
print(f'키워드 {len(keywords)}개 로드됨')

gacha_items = google_sheets.get_gacha_items(os.getenv('GACHA_SHEET_NAME', '가챠'))
print(f'가챠 아이템 {len(gacha_items)}개 로드됨')

print('마스토돈 API 연결 테스트...')
from mastodon import Mastodon
mastodon = Mastodon(
    access_token=os.getenv('MASTODON_ACCESS_TOKEN'),
    api_base_url=os.getenv('MASTODON_API_BASE_URL')
)
account = mastodon.me()
print(f'봇 계정: @{account[\"username\"]}')

print('✅ 모든 테스트 통과!')
" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        log_info "✅ 봇 테스트 성공!"
        return 0
    else
        log_error "❌ 봇 테스트 실패"
        log_info "설정을 다시 확인해주세요."
        return 1
    fi
}

# systemd 서비스 설정 (sudo 권한 필요)
setup_systemd_service() {
    log_step "systemd 서비스 설정 중..."
    
    if [[ -f "$BOT_DIR/scripts/setup_systemd.sh" ]]; then
        log_info "setup_systemd.sh 스크립트를 실행합니다..."
        sudo "$BOT_DIR/scripts/setup_systemd.sh" --install
    else
        log_warn "setup_systemd.sh 스크립트를 찾을 수 없습니다."
        log_info "수동으로 systemd 서비스를 설정해야 합니다."
        return 1
    fi
    
    log_info "systemd 서비스 설정 완료"
    return 0
}

# 모니터링 도구 설정
setup_monitoring() {
    log_step "모니터링 도구 설정 중..."
    
    # 헬스체크 스크립트 권한 설정
    if [[ -f "$BOT_DIR/scripts/monitoring/health_check.py" ]]; then
        chmod +x "$BOT_DIR/scripts/monitoring/health_check.py"
        
        # 필요한 패키지 설치 (가상환경에서)
        source "$VENV_DIR/bin/activate"
        pip install psutil requests 2>/dev/null || true
    fi
    
    # crontab에 헬스체크 추가
    if ! crontab -l 2>/dev/null | grep -q "health_check.py"; then
        (crontab -l 2>/dev/null; echo "*/5 * * * * $VENV_DIR/bin/python $BOT_DIR/scripts/monitoring/health_check.py >> $BOT_DIR/logs/health_monitor.log 2>&1") | crontab -
        log_info "헬스체크 모니터링이 crontab에 추가됨 (5분마다 실행)"
    fi
    
    log_info "모니터링 설정 완료"
}

# 사용법 출력
usage() {
    cat << EOF
마스토돈 봇 빠른 배포 스크립트

사용법: $0 [옵션]

옵션:
    --setup-only        환경 설정만 수행 (서비스 시작 안함)
    --test-only         봇 테스트만 실행
    --start-service     서비스 시작
    --full-deploy       전체 배포 수행
    --help              도움말 표시

단계별 실행:
    1. $0 --setup-only   # 환경 설정
    2. .env 파일 편집 및 서비스 계정 키 업로드
    3. $0 --test-only    # 테스트
    4. $0 --start-service # 서비스 시작

한번에 실행:
    $0 --full-deploy

EOF
}

# 메인 함수
main() {
    log_info "=== 마스토돈 봇 빠른 배포 스크립트 ==="
    
    case "${1:---full-deploy}" in
        --setup-only)
            check_permissions
            setup_directories
            setup_python_environment
            log_info "=== 환경 설정 완료 ==="
            log_warn "이제 .env 파일을 편집하고 구글 서비스 계정 키를 업로드하세요."
            log_info "완료 후 다음 명령어로 테스트: $0 --test-only"
            ;;
            
        --test-only)
            check_permissions
            if check_environment_variables && check_google_credentials; then
                test_bot
                if [[ $? -eq 0 ]]; then
                    log_info "테스트 통과! 다음 명령어로 서비스 시작: $0 --start-service"
                fi
            else
                log_error "환경 설정에 문제가 있습니다."
            fi
            ;;
            
        --start-service)
            check_permissions
            if setup_systemd_service; then
                setup_monitoring
                sudo systemctl start $SERVICE_NAME
                sleep 3
                
                if sudo systemctl is-active $SERVICE_NAME >/dev/null; then
                    log_info "✅ 봇 서비스가 성공적으로 시작되었습니다!"
                    log_info "상태 확인: sudo systemctl status $SERVICE_NAME"
                    log_info "로그 보기: sudo journalctl -u $SERVICE_NAME -f"
                else
                    log_error "❌ 서비스 시작 실패"
                    log_info "로그 확인: sudo journalctl -u $SERVICE_NAME -n 50"
                fi
            fi
            ;;
            
        --full-deploy)
            log_info "전체 배포를 시작합니다..."
            
            check_permissions
            setup_directories
            setup_python_environment
            
            if ! check_environment_variables; then
                log_error "환경 변수 설정이 필요합니다. .env 파일을 확인하세요."
                exit 1
            fi
            
            if ! check_google_credentials; then
                log_error "구글 서비스 계정 키 설정이 필요합니다."
                exit 1
            fi
            
            if test_bot; then
                setup_systemd_service
                setup_monitoring
                
                log_info "봇 서비스를 시작합니다..."
                sudo systemctl start $SERVICE_NAME
                sleep 3
                
                if sudo systemctl is-active $SERVICE_NAME >/dev/null; then
                    log_info "🎉 마스토돈 봇이 성공적으로 배포되었습니다!"
                    log_info ""
                    log_info "📊 상태 확인: sudo systemctl status $SERVICE_NAME"
                    log_info "📋 로그 보기: sudo journalctl -u $SERVICE_NAME -f"
                    log_info "💊 헬스체크: $VENV_DIR/bin/python $BOT_DIR/scripts/monitoring/health_check.py"
                    log_info ""
                    log_info "봇이 24시간 자동으로 실행됩니다."
                else
                    log_error "서비스 시작 실패. 로그를 확인하세요."
                    sudo journalctl -u $SERVICE_NAME -n 20
                fi
            else
                log_error "봇 테스트 실패. 설정을 확인하세요."
                exit 1
            fi
            ;;
            
        --help|*)
            usage
            ;;
    esac
}

main "$@"
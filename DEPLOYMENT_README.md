# 🚀 GCE 24시간 운영 가이드 - 빠른 시작

구글 컴퓨팅 엔진(GCE)에서 마스토돈 봇을 24시간 안전하고 안정적으로 운영하는 완전한 가이드입니다.

## 📋 목차

1. [빠른 시작 (5분 배포)](#빠른-시작)
2. [상세 설정 가이드](#상세-설정-가이드)  
3. [보안 강화](#보안-강화)
4. [모니터링 및 관리](#모니터링-및-관리)
5. [트러블슈팅](#트러블슈팅)

---

## 🚀 빠른 시작

### 1단계: GCE 인스턴스 생성

```bash
# gcloud CLI 설치 및 로그인
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init

# 인스턴스 생성 (e2-micro는 무료 티어)
gcloud compute instances create mastodon-bot \
    --zone=us-central1-a \
    --machine-type=e2-micro \
    --image=ubuntu-2004-focal-v20231213 \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=20GB \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --tags=mastodon-bot

# 인스턴스 접속
gcloud compute ssh mastodon-bot --zone=us-central1-a
```

### 2단계: 봇 사용자 및 기본 환경 설정

```bash
# 시스템 업데이트
sudo apt update && sudo apt upgrade -y

# 필수 패키지 설치
sudo apt install -y python3 python3-pip python3-venv git htop vim curl wget unzip

# 봇 전용 사용자 생성
sudo useradd -m -s /bin/bash botuser
sudo usermod -aG sudo botuser

# 타임존 설정 (한국시간)
sudo timedatectl set-timezone Asia/Seoul

# botuser로 전환
sudo su - botuser
```

### 3단계: 봇 코드 배포

```bash
# 홈 디렉토리에 봇 설정
cd ~
mkdir mastodon-bot
cd mastodon-bot

# 방법 1: Git에서 클론 (추천)
git clone [YOUR_REPOSITORY_URL] .

# 방법 2: 로컬에서 파일 직접 복사
# 로컬 터미널에서 실행:
# gcloud compute scp --recurse ./newbot/* mastodon-bot:~/mastodon-bot/ --zone=us-central1-a
```

### 4단계: 환경 설정

```bash
# 빠른 배포 스크립트 실행 권한 부여
chmod +x scripts/deployment/quick_deploy.sh

# 1단계: 기본 환경 설정
./scripts/deployment/quick_deploy.sh --setup-only
```

### 5단계: 설정 파일 편집

```bash
# 환경 변수 설정
nano .env
```

**.env 파일 내용 예시:**
```env
# 마스토돈 설정 (실제 값으로 변경하세요)
MASTODON_ACCESS_TOKEN=your_actual_mastodon_access_token
MASTODON_API_BASE_URL=https://your.mastodon.instance

# 구글 스프레드시트 설정
GOOGLE_SERVICE_ACCOUNT_FILE=/home/botuser/mastodon-bot/service_account.json
SPREADSHEET_ID=your_actual_spreadsheet_id

# 시트 이름 설정
KEYWORDS_SHEET_NAME=keywords
ACQUISITION_LOG_SHEET_NAME=acquisition_log
GACHA_SHEET_NAME=가챠
```

### 6단계: 구글 서비스 계정 키 업로드

**로컬 터미널에서 실행:**
```bash
# 서비스 계정 JSON 키 파일 업로드
gcloud compute scp service_account.json mastodon-bot:~/mastodon-bot/ --zone=us-central1-a
```

**서버에서 실행:**
```bash
# 파일 권한 설정
chmod 600 ~/mastodon-bot/service_account.json
chmod 600 ~/mastodon-bot/.env
```

### 7단계: 테스트 및 실행

```bash
# 봇 연결 테스트
./scripts/deployment/quick_deploy.sh --test-only

# 테스트 성공 시 서비스 시작
./scripts/deployment/quick_deploy.sh --start-service
```

### 🎉 완료!

봇이 정상적으로 시작되었다면 다음 명령어로 상태를 확인할 수 있습니다:

```bash
# 서비스 상태 확인
sudo systemctl status mastodon-bot

# 실시간 로그 보기
sudo journalctl -u mastodon-bot -f

# 헬스체크 실행
~/mastodon-bot/venv/bin/python ~/mastodon-bot/scripts/monitoring/health_check.py
```

---

## 📚 상세 설정 가이드

자세한 설정은 [`GCE_DEPLOYMENT_GUIDE.md`](./GCE_DEPLOYMENT_GUIDE.md)를 참조하세요.

### 주요 구성 요소

1. **systemd 서비스**: 자동 시작 및 재시작
2. **로그 관리**: 로그로테이션 및 모니터링
3. **헬스체크**: 5분마다 봇 상태 확인
4. **보안 설정**: 방화벽, SSH 보안, 권한 관리

### 파일 구조

```
/home/botuser/mastodon-bot/
├── main.py                     # 메인 봇 코드
├── mastodon_bot.py            # 마스토돈 봇 클래스
├── google_sheets.py           # 구글 시트 매니저
├── gacha_system.py           # 가챠 시스템
├── .env                       # 환경 변수 (비밀)
├── service_account.json       # 구글 서비스 계정 키 (비밀)
├── requirements.txt           # Python 의존성
├── logs/                      # 로그 파일들
├── scripts/
│   ├── start_bot.py          # 봇 관리자 래퍼
│   ├── setup_systemd.sh      # systemd 서비스 설정
│   ├── monitoring/
│   │   ├── health_check.py   # 헬스체크 스크립트
│   │   └── health_config.json # 모니터링 설정
│   ├── security/
│   │   └── secure_setup.sh   # 보안 설정 스크립트
│   └── deployment/
│       └── quick_deploy.sh   # 빠른 배포 스크립트
```

---

## 🔒 보안 강화

### 기본 보안 설정

```bash
# 보안 스크립트 실행 권한 부여
chmod +x ~/mastodon-bot/scripts/security/secure_setup.sh

# 기본 보안 설정 적용
sudo ~/mastodon-bot/scripts/security/secure_setup.sh --basic

# 전체 보안 설정 적용 (권장)
sudo ~/mastodon-bot/scripts/security/secure_setup.sh --full
```

### 주요 보안 기능

- ✅ UFW 방화벽 설정
- ✅ SSH 키 기반 인증 강화
- ✅ Fail2ban 브루트포스 방어
- ✅ 자동 보안 업데이트
- ✅ 파일 권한 강화
- ✅ 네트워크 보안 커널 매개변수
- ✅ 로그 모니터링 강화

### 보안 상태 점검

```bash
# 보안 설정 확인
sudo ~/mastodon-bot/scripts/security/secure_setup.sh --audit

# 방화벽 상태 확인
sudo ufw status verbose

# 로그인 시도 확인
sudo tail -f /var/log/auth.log
```

---

## 📊 모니터링 및 관리

### 헬스체크 시스템

```bash
# 헬스체크 수동 실행
~/mastodon-bot/venv/bin/python ~/mastodon-bot/scripts/monitoring/health_check.py

# JSON 형태로 결과 출력
~/mastodon-bot/venv/bin/python ~/mastodon-bot/scripts/monitoring/health_check.py --json

# 연속 모니터링 (데몬 모드)
~/mastodon-bot/venv/bin/python ~/mastodon-bot/scripts/monitoring/health_check.py --daemon
```

### 로그 관리

```bash
# 서비스 로그 보기
sudo journalctl -u mastodon-bot -f

# 최근 1시간 로그
sudo journalctl -u mastodon-bot --since "1 hour ago"

# 에러 로그만 필터링
sudo journalctl -u mastodon-bot | grep ERROR

# 봇 자체 로그 파일
tail -f ~/mastodon-bot/logs/mastodon_bot.log
```

### 서비스 관리 명령어

```bash
# 서비스 시작/중지/재시작
sudo systemctl start mastodon-bot
sudo systemctl stop mastodon-bot  
sudo systemctl restart mastodon-bot

# 서비스 상태 확인
sudo systemctl status mastodon-bot

# 부팅 시 자동 시작 설정/해제
sudo systemctl enable mastodon-bot
sudo systemctl disable mastodon-bot
```

### 성능 모니터링

```bash
# 시스템 리소스 확인
htop

# 디스크 사용량
df -h

# 메모리 사용량
free -h

# 네트워크 연결 상태
netstat -tuln

# 봇 프로세스 확인
ps aux | grep python
```

---

## 🛠 트러블슈팅

### 일반적인 문제들

#### 1. 서비스가 시작되지 않는 경우

```bash
# 상세 로그 확인
sudo journalctl -u mastodon-bot -n 50

# 수동으로 봇 실행해보기
cd ~/mastodon-bot
source venv/bin/activate
python main.py
```

#### 2. 환경 변수 문제

```bash
# .env 파일 권한 확인
ls -la ~/.env

# 환경 변수 로드 테스트
source ~/.env && echo $MASTODON_ACCESS_TOKEN
```

#### 3. 구글 시트 연결 실패

```bash
# 서비스 계정 키 파일 확인
ls -la ~/mastodon-bot/service_account.json

# 구글 API 연결 테스트
curl -s "https://sheets.googleapis.com/v4/spreadsheets" | head
```

#### 4. 메모리 부족

```bash
# 스왑 파일 생성
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

#### 5. 방화벽 문제

```bash
# 방화벽 상태 확인
sudo ufw status

# 필요시 SSH 포트 다시 허용
sudo ufw allow ssh

# 봇의 아웃바운드 연결 허용 확인
sudo ufw status verbose
```

### 긴급 복구 절차

1. **서비스 완전 재시작**
   ```bash
   sudo systemctl stop mastodon-bot
   sudo systemctl daemon-reload
   sudo systemctl start mastodon-bot
   ```

2. **설정 초기화**
   ```bash
   cd ~/mastodon-bot
   ./scripts/deployment/quick_deploy.sh --setup-only
   ```

3. **로그 초기화**
   ```bash
   sudo journalctl --rotate
   sudo journalctl --vacuum-time=1d
   ```

### 원격 지원 및 디버깅

```bash
# 시스템 정보 수집
~/mastodon-bot/venv/bin/python ~/mastodon-bot/scripts/monitoring/health_check.py --json > system_info.json

# 로그 압축
tar -czf bot_logs_$(date +%Y%m%d).tar.gz ~/mastodon-bot/logs/

# 설정 백업 (민감한 정보 제외)
tar -czf bot_config_$(date +%Y%m%d).tar.gz \
    ~/mastodon-bot/requirements.txt \
    ~/mastodon-bot/.env.example \
    ~/mastodon-bot/scripts/
```

---

## 📞 추가 도움말

### 유용한 명령어 모음

```bash
# 봇 상태 한눈에 보기
echo "=== 서비스 상태 ===" && sudo systemctl status mastodon-bot --no-pager
echo -e "\n=== 최근 로그 ===" && sudo journalctl -u mastodon-bot -n 5 --no-pager  
echo -e "\n=== 리소스 사용량 ===" && free -h && df -h /

# 성능 모니터링 원라이너
watch -n 5 'echo "CPU: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk "{print 100 - \$1}")% | MEM: $(free | grep Mem | awk "{printf \"%.1f%%\", \$3/\$2 * 100.0}") | DISK: $(df -h / | awk "NR==2{print \$5}")"'

# 로그 실시간 모니터링 (색상 구분)
sudo journalctl -u mastodon-bot -f | grep --color=always -E "ERROR|WARNING|INFO"
```

### 백업 및 복원

```bash
# 전체 백업 (민감 정보 포함)
tar -czf mastodon_bot_full_backup_$(date +%Y%m%d).tar.gz \
    ~/mastodon-bot/ \
    /etc/systemd/system/mastodon-bot.service

# 복원
tar -xzf mastodon_bot_full_backup_YYYYMMDD.tar.gz -C ~/
sudo systemctl daemon-reload
```

---

## 🎯 성공 체크리스트

배포가 완료되면 다음 항목들을 확인하세요:

- [ ] ✅ GCE 인스턴스가 정상 실행 중
- [ ] ✅ 봇 서비스가 활성 상태 (`sudo systemctl status mastodon-bot`)
- [ ] ✅ 마스토돈에서 봇 멘션 테스트 성공
- [ ] ✅ 가챠 기능 정상 동작
- [ ] ✅ 구글 스프레드시트 연동 정상
- [ ] ✅ 로그가 정상적으로 기록됨
- [ ] ✅ 헬스체크가 5분마다 실행됨
- [ ] ✅ 방화벽 및 보안 설정 완료
- [ ] ✅ 자동 재시작 기능 동작 확인

**축하합니다! 🎉 마스토돈 봇이 성공적으로 24시간 운영 환경에서 구동되고 있습니다.**

---

## 📚 추가 자료

- [상세 배포 가이드](./GCE_DEPLOYMENT_GUIDE.md)
- [봇 기능 설명서](./README.md)  
- [보안 설정 가이드](./scripts/security/)
- [모니터링 도구 가이드](./scripts/monitoring/)

문제가 발생하면 로그를 확인하고, GitHub Issues에 문의하거나 헬스체크 결과와 함께 상세한 오류 내용을 공유해 주세요.
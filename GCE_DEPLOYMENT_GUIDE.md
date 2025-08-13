# 구글 컴퓨팅 엔진(GCE)에서 마스토돈 봇 24시간 운영 가이드

이 가이드는 마스토돈 스프레드시트 봇을 구글 컴퓨팅 엔진에서 24시간 안정적으로 운영하는 방법을 설명합니다.

## 목차
1. [GCE 인스턴스 생성 및 기본 설정](#1-gce-인스턴스-생성-및-기본-설정)
2. [봇 애플리케이션 배포](#2-봇-애플리케이션-배포)
3. [환경 변수 및 보안 설정](#3-환경-변수-및-보안-설정)
4. [systemd 서비스 설정](#4-systemd-서비스-설정)
5. [로깅 및 모니터링](#5-로깅-및-모니터링)
6. [자동 재시작 및 오류 복구](#6-자동-재시작-및-오류-복구)
7. [보안 강화](#7-보안-강화)
8. [트러블슈팅](#8-트러블슈팅)

## 1. GCE 인스턴스 생성 및 기본 설정

### 1.1 인스턴스 생성
```bash
# gcloud CLI 설치 및 인증 (로컬에서 실행)
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init

# 프로젝트 설정
gcloud config set project [YOUR_PROJECT_ID]

# 인스턴스 생성
gcloud compute instances create mastodon-bot \
    --zone=us-central1-a \
    --machine-type=e2-micro \
    --network-tier=PREMIUM \
    --image=ubuntu-2004-focal-v20231213 \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=20GB \
    --boot-disk-type=pd-balanced \
    --boot-disk-device-name=mastodon-bot \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --tags=mastodon-bot
```

### 1.2 인스턴스 접속 및 기본 설정
```bash
# 인스턴스 접속
gcloud compute ssh mastodon-bot --zone=us-central1-a

# 시스템 업데이트
sudo apt update && sudo apt upgrade -y

# 필수 패키지 설치
sudo apt install -y python3 python3-pip python3-venv git htop vim curl wget unzip

# 타임존 설정 (한국시간)
sudo timedatectl set-timezone Asia/Seoul

# 사용자 생성 (보안을 위해)
sudo useradd -m -s /bin/bash botuser
sudo usermod -aG sudo botuser
```

## 2. 봇 애플리케이션 배포

### 2.1 프로젝트 배포
```bash
# botuser로 전환
sudo su - botuser

# 홈 디렉토리에 프로젝트 폴더 생성
mkdir -p ~/mastodon-bot
cd ~/mastodon-bot

# 프로젝트 파일 업로드 (방법 1: git 사용)
git clone [YOUR_REPOSITORY_URL] .

# 또는 방법 2: 직접 파일 복사
# gcloud compute scp --recurse ./newbot/* mastodon-bot:~/mastodon-bot/ --zone=us-central1-a
```

### 2.2 Python 가상환경 설정
```bash
# 가상환경 생성
python3 -m venv venv

# 가상환경 활성화
source venv/bin/activate

# 의존성 설치
pip install -r requirements.txt

# 권한 설정
chmod +x main.py
```

## 3. 환경 변수 및 보안 설정

### 3.1 환경 변수 파일 생성
```bash
# .env 파일 생성
cp .env.example .env
nano .env
```

### 3.2 .env 파일 내용 설정
```env
# 마스토돈 설정
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

### 3.3 구글 서비스 계정 키 설정
```bash
# 서비스 계정 JSON 키 파일 업로드
# 로컬에서 실행:
# gcloud compute scp service_account.json mastodon-bot:~/mastodon-bot/ --zone=us-central1-a

# 권한 설정 (인스턴스에서 실행)
chmod 600 ~/mastodon-bot/service_account.json
chmod 600 ~/mastodon-bot/.env
```

## 4. systemd 서비스 설정

### 4.1 서비스 파일 생성
```bash
# 서비스 파일 생성 (root 권한 필요)
sudo nano /etc/systemd/system/mastodon-bot.service
```

### 4.2 서비스 파일 내용
```ini
[Unit]
Description=Mastodon Spreadsheet Bot
After=network.target

[Service]
Type=simple
User=botuser
Group=botuser
WorkingDirectory=/home/botuser/mastodon-bot
Environment=PATH=/home/botuser/mastodon-bot/venv/bin
ExecStart=/home/botuser/mastodon-bot/venv/bin/python main.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=mastodon-bot

# 환경 변수 보안
EnvironmentFile=/home/botuser/mastodon-bot/.env

[Install]
WantedBy=multi-user.target
```

### 4.3 서비스 활성화
```bash
# systemd 리로드
sudo systemctl daemon-reload

# 서비스 활성화 (부팅 시 자동 시작)
sudo systemctl enable mastodon-bot

# 서비스 시작
sudo systemctl start mastodon-bot

# 상태 확인
sudo systemctl status mastodon-bot
```

## 5. 로깅 및 모니터링

### 5.1 로그 확인 명령어
```bash
# 실시간 로그 보기
sudo journalctl -u mastodon-bot -f

# 최근 로그 보기
sudo journalctl -u mastodon-bot --since "1 hour ago"

# 오늘 로그 보기
sudo journalctl -u mastodon-bot --since today

# 로그 검색
sudo journalctl -u mastodon-bot | grep "ERROR"
```

### 5.2 로그 로테이션 설정
```bash
# 로그 로테이션 설정 파일 생성
sudo nano /etc/logrotate.d/mastodon-bot
```

```ini
/var/log/mastodon-bot/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 botuser botuser
    postrotate
        systemctl reload mastodon-bot
    endscript
}
```

### 5.3 모니터링 스크립트 생성
```bash
# 상태 모니터링 스크립트
nano ~/monitor_bot.sh
```

```bash
#!/bin/bash

BOT_STATUS=$(systemctl is-active mastodon-bot)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

if [ "$BOT_STATUS" != "active" ]; then
    echo "[$TIMESTAMP] WARNING: 마스토돈 봇이 비활성 상태입니다. 재시작을 시도합니다."
    sudo systemctl restart mastodon-bot
    sleep 10
    
    NEW_STATUS=$(systemctl is-active mastodon-bot)
    if [ "$NEW_STATUS" = "active" ]; then
        echo "[$TIMESTAMP] SUCCESS: 봇이 성공적으로 재시작되었습니다."
    else
        echo "[$TIMESTAMP] ERROR: 봇 재시작에 실패했습니다. 수동 확인이 필요합니다."
    fi
else
    echo "[$TIMESTAMP] OK: 마스토돈 봇이 정상 작동 중입니다."
fi
```

```bash
# 스크립트 실행 권한 부여
chmod +x ~/monitor_bot.sh

# crontab에 5분마다 모니터링 추가
crontab -e
# 다음 라인 추가:
# */5 * * * * /home/botuser/monitor_bot.sh >> /home/botuser/bot_monitor.log 2>&1
```

## 6. 자동 재시작 및 오류 복구

### 6.1 향상된 main.py 래퍼 스크립트 생성
```bash
nano ~/mastodon-bot/start_bot.py
```

```python
#!/usr/bin/env python3
import os
import sys
import time
import logging
from datetime import datetime

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/home/botuser/mastodon-bot/bot.log'),
        logging.StreamHandler()
    ]
)

def restart_bot():
    """봇 재시작 함수"""
    max_retries = 5
    retry_count = 0
    
    while retry_count < max_retries:
        try:
            logging.info(f"봇 시작 시도 #{retry_count + 1}")
            
            # main.py 실행
            os.chdir('/home/botuser/mastodon-bot')
            sys.path.insert(0, '/home/botuser/mastodon-bot')
            
            import main
            main.main()
            
        except KeyboardInterrupt:
            logging.info("사용자에 의한 종료")
            break
        except Exception as e:
            retry_count += 1
            logging.error(f"오류 발생: {e}")
            
            if retry_count < max_retries:
                wait_time = min(300, 30 * retry_count)  # 최대 5분
                logging.info(f"{wait_time}초 후 재시작 시도...")
                time.sleep(wait_time)
            else:
                logging.error("최대 재시도 횟수에 도달했습니다. 프로그램을 종료합니다.")
                break

if __name__ == "__main__":
    restart_bot()
```

### 6.2 systemd 서비스 파일 수정
```bash
sudo nano /etc/systemd/system/mastodon-bot.service
```

```ini
# ExecStart 라인을 다음과 같이 수정:
ExecStart=/home/botuser/mastodon-bot/venv/bin/python /home/botuser/mastodon-bot/start_bot.py
```

```bash
# 서비스 재시작
sudo systemctl daemon-reload
sudo systemctl restart mastodon-bot
```

## 7. 보안 강화

### 7.1 방화벽 설정
```bash
# ufw 설치 및 활성화
sudo ufw enable

# SSH만 허용 (필요한 경우)
sudo ufw allow ssh

# 봇은 아웃바운드 연결만 필요하므로 인바운드 차단
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 상태 확인
sudo ufw status verbose
```

### 7.2 SSH 보안 강화
```bash
# SSH 설정 수정
sudo nano /etc/ssh/sshd_config

# 다음 설정들 수정:
# PermitRootLogin no
# PasswordAuthentication no  # 키 기반 인증 사용 시
# Port 2222  # 기본 포트 변경 (선택사항)

# SSH 재시작
sudo systemctl restart ssh
```

### 7.3 자동 업데이트 설정
```bash
# unattended-upgrades 설치
sudo apt install unattended-upgrades

# 자동 업데이트 활성화
sudo dpkg-reconfigure unattended-upgrades

# 설정 파일 확인
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

## 8. 트러블슈팅

### 8.1 일반적인 문제 해결

#### 서비스 시작 실패
```bash
# 상세 로그 확인
sudo journalctl -u mastodon-bot -n 50

# 수동으로 봇 테스트
cd /home/botuser/mastodon-bot
source venv/bin/activate
python main.py
```

#### 권한 문제
```bash
# 파일 권한 재설정
sudo chown -R botuser:botuser /home/botuser/mastodon-bot
chmod 600 /home/botuser/mastodon-bot/.env
chmod 600 /home/botuser/mastodon-bot/service_account.json
```

#### 메모리 부족
```bash
# 메모리 사용량 확인
free -h
htop

# 스왑 파일 생성 (필요한 경우)
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 영구 설정
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 8.2 유용한 명령어 모음
```bash
# 서비스 상태 확인
sudo systemctl status mastodon-bot

# 서비스 재시작
sudo systemctl restart mastodon-bot

# 로그 실시간 모니터링
sudo journalctl -u mastodon-bot -f

# 디스크 사용량 확인
df -h

# 프로세스 확인
ps aux | grep python

# 네트워크 연결 확인
netstat -tuln
```

### 8.3 백업 및 복원
```bash
# 설정 파일 백업
tar -czf mastodon-bot-backup-$(date +%Y%m%d).tar.gz \
    /home/botuser/mastodon-bot/.env \
    /home/botuser/mastodon-bot/service_account.json \
    /etc/systemd/system/mastodon-bot.service

# 구글 클라우드 스토리지에 백업 (선택사항)
gsutil cp mastodon-bot-backup-*.tar.gz gs://your-backup-bucket/
```

## 9. 비용 최적화

### 9.1 Preemptible 인스턴스 사용 (선택사항)
```bash
# Preemptible 인스턴스로 재생성 (더 저렴하지만 최대 24시간 후 종료될 수 있음)
gcloud compute instances create mastodon-bot-preempt \
    --zone=us-central1-a \
    --machine-type=e2-micro \
    --preemptible \
    --image=ubuntu-2004-focal-v20231213 \
    --image-project=ubuntu-os-cloud
```

### 9.2 인스턴스 스케줄링 (선택사항)
```bash
# 특정 시간대에만 봇 운영하려는 경우
crontab -e

# 예: 오전 8시에 시작, 오후 11시에 종료
# 0 8 * * * sudo systemctl start mastodon-bot
# 0 23 * * * sudo systemctl stop mastodon-bot
```

## 10. 완료 체크리스트

- [ ] GCE 인스턴스 생성 및 기본 설정 완료
- [ ] 봇 애플리케이션 배포 완료
- [ ] 환경 변수 및 보안 키 설정 완료
- [ ] systemd 서비스 설정 및 활성화 완료
- [ ] 로깅 및 모니터링 설정 완료
- [ ] 자동 재시작 메커니즘 설정 완료
- [ ] 방화벽 및 보안 설정 완료
- [ ] 봇 정상 작동 테스트 완료
- [ ] 백업 및 복구 계획 수립 완료

이 가이드를 따라하면 마스토돈 봇이 GCE에서 안정적으로 24시간 운영됩니다!
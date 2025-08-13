# 🖥️ 윈도우에서 마스토돈 봇 24시간 운영 가이드

윈도우 PC에서 마스토돈 스프레드시트 봇을 24시간 안정적으로 운영하는 완전한 가이드입니다.

## 📋 목차

1. [빠른 시작 (5분 설정)](#빠른-시작)
2. [상세 설정](#상세-설정)  
3. [Windows 서비스로 등록](#windows-서비스로-등록)
4. [예약 작업 설정](#예약-작업-설정)
5. [모니터링 및 관리](#모니터링-및-관리)
6. [트러블슈팅](#트러블슈팅)

---

## 🚀 빠른 시작

### 1단계: 필수 소프트웨어 설치

1. **Python 3.8 이상 설치**
   - https://www.python.org/downloads/ 에서 최신 버전 다운로드
   - 설치 시 **"Add Python to PATH"** 체크박스 ✅ 체크 필수!

2. **Git 설치** (선택사항)
   - https://git-scm.com/download/win

### 2단계: 봇 코드 준비

방법 1: Git 사용 (권장)
```cmd
cd C:\
git clone [YOUR_REPOSITORY_URL] mastodon-bot
cd mastodon-bot
```

방법 2: 직접 복사
- 봇 파일들을 `C:\mastodon-bot` 폴더에 복사

### 3단계: 자동 설정 실행

```cmd
cd C:\mastodon-bot
scripts\windows\setup_bot.bat
```

### 4단계: 환경 설정

자동으로 생성된 `.env` 파일을 편집:
```cmd
notepad .env
```

**.env 파일 예시:**
```env
# 마스토돈 설정
MASTODON_ACCESS_TOKEN=your_actual_mastodon_access_token
MASTODON_API_BASE_URL=https://your.mastodon.instance

# 구글 스프레드시트 설정  
GOOGLE_SERVICE_ACCOUNT_FILE=C:\mastodon-bot\service_account.json
SPREADSHEET_ID=your_actual_spreadsheet_id

# 시트 이름 설정
KEYWORDS_SHEET_NAME=keywords
ACQUISITION_LOG_SHEET_NAME=acquisition_log
GACHA_SHEET_NAME=가챠
```

### 5단계: 구글 서비스 계정 키 설정

구글 클라우드 콘솔에서 다운로드한 JSON 키 파일을 `service_account.json`으로 저장

### 6단계: 연결 테스트

```cmd
scripts\windows\test_bot.bat
```

### 7단계: 봇 시작

```cmd
scripts\windows\start_bot.bat
```

### 🎉 완료!

봇이 정상적으로 실행되면 마스토돈에서 멘션을 보내 테스트해보세요!

---

## 📚 상세 설정

### 폴더 구조

```
C:\mastodon-bot\
├── main.py                    # 메인 봇 코드
├── mastodon_bot.py           # 마스토돈 봇 클래스
├── google_sheets.py          # 구글 시트 매니저
├── gacha_system.py          # 가챠 시스템
├── .env                      # 환경 변수 (비밀)
├── service_account.json      # 구글 서비스 계정 키 (비밀)
├── requirements.txt          # Python 의존성
├── logs\                     # 로그 파일들
├── venv\                     # Python 가상환경
└── scripts\windows\          # 윈도우 전용 스크립트들
    ├── setup_bot.bat         # 초기 설정
    ├── test_bot.bat          # 연결 테스트
    ├── start_bot.bat         # 봇 시작
    ├── health_check.bat      # 상태 점검
    ├── manage_service.bat    # 서비스 관리
    ├── install_service.bat   # 서비스 설치
    └── scheduled_task_setup.bat # 예약 작업 설정
```

### 환경 변수 상세 설정

| 변수명 | 설명 | 예시 |
|--------|------|------|
| `MASTODON_ACCESS_TOKEN` | 마스토돈 액세스 토큰 | `your_token_here` |
| `MASTODON_API_BASE_URL` | 마스토돈 인스턴스 URL | `https://mastodon.social` |
| `GOOGLE_SERVICE_ACCOUNT_FILE` | 구글 서비스 계정 키 파일 경로 | `C:\mastodon-bot\service_account.json` |
| `SPREADSHEET_ID` | 구글 스프레드시트 ID | `1abc...xyz` |
| `KEYWORDS_SHEET_NAME` | 키워드 시트 이름 | `keywords` |
| `GACHA_SHEET_NAME` | 가챠 시트 이름 | `가챠` |
| `ACQUISITION_LOG_SHEET_NAME` | 획득 로그 시트 이름 | `acquisition_log` |

---

## 🔧 Windows 서비스로 등록

### NSSM 방식 (권장)

1. **NSSM 다운로드**
   - https://nssm.cc/download 에서 `nssm.exe` 다운로드
   - `C:\mastodon-bot\scripts\windows\` 폴더에 저장

2. **서비스 설치**
   ```cmd
   # 관리자 권한으로 CMD 실행 후
   cd C:\mastodon-bot
   scripts\windows\install_service.bat
   ```

3. **서비스 관리**
   ```cmd
   # 서비스 시작
   net start "MastodonBot"
   
   # 서비스 중지
   net stop "MastodonBot"
   
   # 서비스 상태 확인
   sc query "MastodonBot"
   ```

### 서비스 관리 GUI

편리한 관리를 위해 제공되는 배치 파일:
```cmd
scripts\windows\manage_service.bat
```

메뉴 기능:
- ✅ 서비스 시작/중지/재시작
- 📊 서비스 상태 확인
- 📋 로그 파일 보기
- 🗑️ 서비스 제거
- 📈 프로세스 모니터링

---

## ⏰ 예약 작업 설정

Windows 작업 스케줄러를 사용한 자동화:

```cmd
# 관리자 권한으로 실행
scripts\windows\scheduled_task_setup.bat
```

### 생성되는 예약 작업들

1. **MastodonBot\AutoStart**
   - **실행 시점**: 시스템 부팅 시 (2분 지연)
   - **기능**: 봇 자동 시작
   - **재시작**: 실패 시 5분마다 최대 3회

2. **MastodonBot\HealthCheck**  
   - **실행 시점**: 5분마다
   - **기능**: 봇 상태 점검 및 로그 기록
   - **숨김**: 백그라운드 실행

3. **MastodonBot\LogCleanup**
   - **실행 시점**: 매일 자정
   - **기능**: 오래된 로그 파일 정리 (30일 이상)
   - **백업**: 대용량 로그 파일 백업 후 초기화

### 예약 작업 관리

```cmd
# 예약 작업 목록 보기
schtasks /query /fo list /tn "MastodonBot\*"

# 특정 작업 수동 실행
schtasks /run /tn "MastodonBot\HealthCheck"

# 작업 비활성화
schtasks /change /tn "MastodonBot\AutoStart" /disable

# 작업 삭제
schtasks /delete /tn "MastodonBot\AutoStart" /f
```

또는 **작업 스케줄러** (`taskschd.msc`) GUI에서 관리 가능

---

## 📊 모니터링 및 관리

### 상태 점검

```cmd
# 종합 상태 점검
scripts\windows\health_check.bat
```

**점검 항목:**
- ✅ 봇 프로세스 실행 상태
- ✅ Windows 서비스 상태  
- ✅ 디스크 공간 확인
- ✅ 로그 파일 상태
- ✅ 최근 에러 로그 분석
- ✅ 네트워크 연결 테스트
- ✅ 시스템 리소스 사용량

### 로그 파일 위치

| 로그 파일 | 경로 | 내용 |
|-----------|------|------|
| 봇 메인 로그 | `logs\mastodon_bot.log` | 봇 실행 및 에러 로그 |
| 서비스 로그 | `logs\service.log` | Windows 서비스 관련 로그 |
| 헬스체크 로그 | `logs\health_monitor.log` | 상태 점검 결과 |
| 정리 로그 | `logs\cleanup.log` | 로그 정리 작업 기록 |

### 실시간 모니터링

**PowerShell로 실시간 로그 보기:**
```powershell
Get-Content "C:\mastodon-bot\logs\mastodon_bot.log" -Tail 10 -Wait
```

**작업 관리자에서 확인:**
- `Ctrl + Shift + Esc` → 세부 정보 탭 → `python.exe` 프로세스 확인

---

## 🔄 자동 재시작 설정

### 방법 1: Windows 서비스 (NSSM)
- 서비스가 중지되면 자동으로 재시작
- 시스템 부팅 시 자동 시작
- 로그 파일 자동 관리

### 방법 2: 예약 작업
- 5분마다 상태 확인
- 프로세스 없으면 자동 재시작
- 더 세밀한 제어 가능

### 방법 3: 배치 파일 루프
간단한 무한 루프 방식:

```cmd
# restart_bot.bat 생성
@echo off
:loop
cd C:\mastodon-bot
call venv\Scripts\activate.bat
python main.py
echo 봇이 종료되었습니다. 10초 후 재시작...
timeout /t 10 /nobreak
goto loop
```

---

## 🚨 트러블슈팅

### 일반적인 문제들

#### 1. Python 인식 안됨
```
'python'은(는) 내부 또는 외부 명령, 실행할 수 있는 프로그램, 또는
배치 파일이 아닙니다.
```
**해결책:**
- Python 재설치 시 "Add Python to PATH" 체크
- 또는 환경 변수 수동 추가: 시스템 → 고급 시스템 설정 → 환경 변수

#### 2. 모듈을 찾을 수 없음
```
ModuleNotFoundError: No module named 'mastodon'
```
**해결책:**
```cmd
cd C:\mastodon-bot
call venv\Scripts\activate.bat
pip install -r requirements.txt
```

#### 3. 가상환경 활성화 실패
**해결책:**
```cmd
# 가상환경 재생성
rmdir /s venv
python -m venv venv
call venv\Scripts\activate.bat
pip install -r requirements.txt
```

#### 4. 구글 시트 연결 실패
- `service_account.json` 파일 경로 확인
- 파일 권한 확인 (읽기 권한 필요)
- 스프레드시트를 서비스 계정과 공유했는지 확인

#### 5. 마스토돈 연결 실패
- 액세스 토큰 확인
- 인스턴스 URL 확인 (https:// 포함)
- 방화벽/안티바이러스 확인

#### 6. 서비스 시작 실패
**로그 확인:**
```cmd
# 이벤트 뷰어에서 확인
eventvwr.msc

# 또는 서비스 로그 확인
type "C:\mastodon-bot\logs\service.log"
```

### 고급 문제 해결

#### Windows Defender 예외 설정
봇 폴더를 Windows Defender 실시간 보호에서 제외:
1. Windows 보안 → 바이러스 및 위협 방지
2. 설정 관리 → 제외 항목 추가
3. `C:\mastodon-bot` 폴더 추가

#### 방화벽 설정
아웃바운드 연결을 위한 방화벽 규칙:
```cmd
# Python을 방화벽에서 허용
netsh advfirewall firewall add rule name="Python Bot Outbound" dir=out action=allow program="C:\Python3x\python.exe"
```

#### 포트 점유 확인
```cmd
netstat -ano | findstr :443
netstat -ano | findstr :80
```

### 성능 최적화

#### 1. 우선순위 설정
```cmd
# 작업 관리자에서 python.exe 우선순위를 "높음"으로 설정
```

#### 2. 메모리 사용량 모니터링
```cmd
# 메모리 사용량 확인
tasklist /FI "IMAGENAME eq python.exe" /FO TABLE
```

#### 3. 디스크 공간 관리
- 로그 파일 정기 정리
- 임시 파일 삭제: `%TEMP%` 폴더 정리
- 가상환경 캐시 정리: `pip cache purge`

---

## 🛡️ 보안 강화

### 1. 파일 권한 설정
```cmd
# 중요 파일 권한 제한
icacls "C:\mastodon-bot\.env" /inheritance:d
icacls "C:\mastodon-bot\.env" /grant:r "%username%":F /t
icacls "C:\mastodon-bot\service_account.json" /inheritance:d
icacls "C:\mastodon-bot\service_account.json" /grant:r "%username%":F /t
```

### 2. Windows 업데이트 자동화
- 설정 → 업데이트 및 보안 → Windows Update
- 자동 업데이트 활성화

### 3. 안티바이러스 설정
- 실시간 보호 활성화
- 봇 폴더를 검사 제외 대상으로 추가 (성능 향상)

---

## 📈 성능 모니터링

### 리소스 모니터링
```cmd
# CPU/메모리 사용량 지속 모니터링
typeperf "\Process(python)\% Processor Time" "\Process(python)\Working Set" -si 5
```

### 네트워크 모니터링
```cmd
# 네트워크 연결 상태 확인
netstat -an | findstr :443
```

### 자동 알림 설정
이메일/SMS 알림은 별도 도구(예: PowerShell 스크립트)나 모니터링 서비스 활용

---

## 🎯 완료 체크리스트

배포가 완료되면 다음 항목들을 확인하세요:

- [ ] ✅ Python 설치 및 PATH 설정 완료
- [ ] ✅ 가상환경 생성 및 의존성 설치 완료
- [ ] ✅ `.env` 파일 설정 완료
- [ ] ✅ 구글 서비스 계정 키 설정 완료
- [ ] ✅ 연결 테스트 성공
- [ ] ✅ 봇 수동 실행 성공
- [ ] ✅ Windows 서비스 등록 완료 (선택)
- [ ] ✅ 예약 작업 설정 완료 (선택)
- [ ] ✅ 마스토돈에서 봇 멘션 테스트 성공
- [ ] ✅ 가챠 기능 정상 동작 확인
- [ ] ✅ 로그 파일 생성 및 기록 확인
- [ ] ✅ 자동 재시작 기능 테스트
- [ ] ✅ 상태 점검 스크립트 동작 확인

---

## 🎉 운영 시작!

모든 설정이 완료되었다면 다음과 같이 봇을 운영할 수 있습니다:

### 일상 관리 명령어

```cmd
# 봇 상태 확인
scripts\windows\health_check.bat

# 서비스 관리 (GUI 메뉴)
scripts\windows\manage_service.bat

# 봇 수동 시작 (테스트용)
scripts\windows\start_bot.bat

# 연결 테스트
scripts\windows\test_bot.bat
```

### 로그 모니터링

**실시간 로그 보기:**
```cmd
powershell -command "Get-Content 'logs\mastodon_bot.log' -Tail 20 -Wait"
```

**에러 로그만 보기:**
```cmd
findstr /i "error" logs\mastodon_bot.log
```

### 백업 및 복원

**설정 백업:**
```cmd
# 중요 파일들을 백업 폴더로 복사
mkdir backup_%date:~0,4%%date:~5,2%%date:~8,2%
copy .env backup_%date:~0,4%%date:~5,2%%date:~8,2%\
copy service_account.json backup_%date:~0,4%%date:~5,2%%date:~8,2%\
```

---

## 🔗 추가 자료

- [봇 기능 설명서](./README.md)
- [GCE 배포 가이드](./GCE_DEPLOYMENT_GUIDE.md) (Linux/클라우드용)
- [Windows 작업 스케줄러 가이드](https://docs.microsoft.com/ko-kr/windows/win32/taskschd/)
- [NSSM 공식 문서](https://nssm.cc/usage)

---

**축하합니다! 🎉 마스토돈 봇이 윈도우에서 24시간 안정적으로 운영됩니다.**

문제가 발생하면 로그 파일을 확인하고, `health_check.bat`으로 상태를 점검해보세요. 추가 도움이 필요하면 GitHub Issues에 상세한 로그와 함께 문의해주세요.
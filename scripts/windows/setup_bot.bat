@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM 마스토돈 스프레드시트 봇 윈도우 설정 스크립트
REM 이 스크립트는 윈도우에서 봇을 설정하고 실행하는데 필요한 모든 과정을 자동화합니다.

echo ================================
echo 마스토돈 스프레드시트 봇 설정
echo ================================
echo.

REM 현재 디렉토리 확인
set "BOT_DIR=%~dp0..\.."
echo 봇 디렉토리: %BOT_DIR%
cd /d "%BOT_DIR%"

REM Python 설치 확인
echo [1/8] Python 설치 확인 중...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Python이 설치되어 있지 않습니다.
    echo Python 3.8 이상을 https://www.python.org/downloads/ 에서 다운로드하여 설치하세요.
    echo 설치 시 "Add Python to PATH" 옵션을 체크해주세요.
    pause
    exit /b 1
) else (
    python --version
    echo ✅ Python 설치 확인됨
)
echo.

REM pip 업그레이드
echo [2/8] pip 업그레이드 중...
python -m pip install --upgrade pip
echo ✅ pip 업그레이드 완료
echo.

REM 가상환경 생성
echo [3/8] 가상환경 생성 중...
if not exist "venv" (
    python -m venv venv
    echo ✅ 가상환경 생성 완료
) else (
    echo ✅ 가상환경이 이미 존재합니다
)
echo.

REM 가상환경 활성화
echo [4/8] 가상환경 활성화 중...
call venv\Scripts\activate.bat
if %errorlevel% neq 0 (
    echo ❌ 가상환경 활성화 실패
    pause
    exit /b 1
)
echo ✅ 가상환경 활성화 완료
echo.

REM 의존성 설치
echo [5/8] 의존성 패키지 설치 중...
if exist "requirements.txt" (
    pip install -r requirements.txt
    echo ✅ 의존성 패키지 설치 완료
) else (
    echo ❌ requirements.txt 파일을 찾을 수 없습니다.
    pause
    exit /b 1
)
echo.

REM 환경 변수 파일 확인
echo [6/8] 환경 설정 파일 확인 중...
if not exist ".env" (
    if exist ".env.example" (
        copy ".env.example" ".env"
        echo ✅ .env.example을 .env로 복사했습니다.
        echo ⚠️ .env 파일을 편집하여 실제 값들을 설정해주세요.
    ) else (
        echo ❌ .env.example 파일이 없습니다.
        pause
        exit /b 1
    )
) else (
    echo ✅ .env 파일이 존재합니다
)
echo.

REM 로그 디렉토리 생성
echo [7/8] 로그 디렉토리 생성 중...
if not exist "logs" mkdir logs
if not exist "logs\health_reports" mkdir logs\health_reports
echo ✅ 로그 디렉토리 생성 완료
echo.

REM 스크립트 권한 설정 (윈도우에서는 불필요하지만 호환성을 위해)
echo [8/8] 설정 완료...

echo.
echo ================================
echo         설정 완료! 🎉
echo ================================
echo.
echo 다음 단계:
echo 1. .env 파일을 편집하여 실제 설정값을 입력하세요
echo 2. 구글 서비스 계정 키 파일을 service_account.json으로 저장하세요
echo 3. test_bot.bat으로 연결 테스트를 실행하세요
echo 4. start_bot.bat으로 봇을 시작하세요
echo.
echo 설정 파일 열기: notepad .env
echo 테스트 실행: scripts\windows\test_bot.bat
echo 봇 시작: scripts\windows\start_bot.bat
echo.
pause
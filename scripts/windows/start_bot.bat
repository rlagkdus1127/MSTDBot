@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM 마스토돈 봇 시작 스크립트

echo ================================
echo     마스토돈 봇 시작
echo ================================
echo.

REM 현재 디렉토리 설정
set "BOT_DIR=%~dp0..\.."
cd /d "%BOT_DIR%"

REM 가상환경 활성화
echo 가상환경 활성화 중...
if exist "venv\Scripts\activate.bat" (
    call venv\Scripts\activate.bat
    echo ✅ 가상환경 활성화 완료
) else (
    echo ❌ 가상환경을 찾을 수 없습니다. setup_bot.bat을 먼저 실행하세요.
    pause
    exit /b 1
)
echo.

REM .env 파일 확인
if not exist ".env" (
    echo ❌ .env 파일이 없습니다. setup_bot.bat을 먼저 실행하세요.
    pause
    exit /b 1
)

REM 필수 파일 확인
if not exist "main.py" (
    echo ❌ main.py 파일을 찾을 수 없습니다.
    pause
    exit /b 1
)

REM 로그 디렉토리 확인
if not exist "logs" mkdir logs

echo 마스토돈 봇을 시작합니다...
echo.
echo ================================
echo        봇 실행 중
echo ================================
echo.
echo 봇을 중지하려면 Ctrl+C를 누르세요.
echo 로그는 logs\mastodon_bot.log 파일에서 확인할 수 있습니다.
echo.

REM 봇 실행
python main.py

echo.
echo 봇이 종료되었습니다.
echo.
pause
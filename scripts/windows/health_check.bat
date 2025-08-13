@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM 마스토돈 봇 헬스체크 스크립트 (윈도우용)

echo ================================
echo    마스토돈 봇 상태 점검
echo ================================
echo.

set "BOT_DIR=%~dp0..\.."
cd /d "%BOT_DIR%"

REM 가상환경 활성화
if exist "venv\Scripts\activate.bat" (
    call venv\Scripts\activate.bat
) else (
    echo ❌ 가상환경을 찾을 수 없습니다.
    pause
    exit /b 1
)

echo 시스템 상태 점검 중...
echo.

REM 날짜/시간 표시
echo ⏰ 점검 시간: %date% %time%
echo.

REM Python 프로세스 확인
echo [1] 봇 프로세스 상태 확인
echo ================================
tasklist /FI "IMAGENAME eq python.exe" /FO TABLE | findstr python >nul
if %errorlevel% equ 0 (
    echo ✅ Python 프로세스 실행 중
    tasklist /FI "IMAGENAME eq python.exe" /FO TABLE
) else (
    echo ❌ Python 프로세스를 찾을 수 없습니다
)
echo.

REM 서비스 상태 확인 (설치된 경우)
echo [2] Windows 서비스 상태
echo ================================
sc query "MastodonBot" >nul 2>&1
if %errorlevel% equ 0 (
    sc query "MastodonBot" | findstr "STATE"
) else (
    echo ℹ️ Windows 서비스가 설치되지 않음
)
echo.

REM 디스크 공간 확인
echo [3] 디스크 공간 확인
echo ================================
for /f "tokens=3" %%i in ('dir /-c "%BOT_DIR%" ^| findstr "bytes free"') do (
    set "free_bytes=%%i"
)
echo 사용 가능한 공간: %free_bytes% bytes
echo.

REM 로그 파일 확인
echo [4] 로그 파일 상태
echo ================================
if exist "logs\mastodon_bot.log" (
    echo ✅ 봇 로그 파일 존재
    for /f %%i in ('"type logs\mastodon_bot.log | find /c /v """') do echo    라인 수: %%i
    for /f "tokens=*" %%i in ('dir "logs\mastodon_bot.log" /TC ^| findstr "mastodon_bot.log"') do (
        echo    마지막 수정: %%i
    )
) else (
    echo ❌ 봇 로그 파일이 없습니다
)

if exist "logs\service.log" (
    echo ✅ 서비스 로그 파일 존재  
    for /f %%i in ('"type logs\service.log | find /c /v """') do echo    라인 수: %%i
) else (
    echo ℹ️ 서비스 로그 파일이 없습니다
)
echo.

REM 최근 로그 에러 확인
echo [5] 최근 로그 에러 확인
echo ================================
if exist "logs\mastodon_bot.log" (
    echo 최근 ERROR/WARNING 로그 (최근 10개):
    type "logs\mastodon_bot.log" | findstr /i "ERROR WARNING" | for /l %%i in (1,1,10) do (
        set /p line=
        if defined line echo    !line!
    )
) else (
    echo 로그 파일이 없어 확인할 수 없습니다
)
echo.

REM 네트워크 연결 테스트
echo [6] 네트워크 연결 테스트
echo ================================
echo Google 연결 테스트:
ping -n 1 8.8.8.8 >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ 인터넷 연결 정상
) else (
    echo ❌ 인터넷 연결 문제
)

echo.
echo 구글 API 연결 테스트:
curl -s https://sheets.googleapis.com/v4/spreadsheets >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ 구글 시트 API 연결 정상
) else (
    echo ⚠️ 구글 시트 API 연결 확인 불가 (curl 필요)
)
echo.

REM 설정 파일 확인
echo [7] 설정 파일 확인
echo ================================
if exist ".env" (
    echo ✅ .env 파일 존재
    for /f "tokens=*" %%i in ('dir ".env" /TC ^| findstr ".env"') do (
        echo    마지막 수정: %%i
    )
) else (
    echo ❌ .env 파일이 없습니다
)

if exist "service_account.json" (
    echo ✅ 구글 서비스 계정 키 존재
) else (
    echo ❌ 구글 서비스 계정 키가 없습니다
)
echo.

REM 메모리 사용량 확인
echo [8] 시스템 리소스 확인
echo ================================

REM 사용 가능한 메모리 확인 (PowerShell 사용)
for /f %%i in ('powershell -command "(Get-WmiObject -Class Win32_OperatingSystem).FreePhysicalMemory"') do (
    set /a free_mem_mb=%%i/1024
)
echo 사용 가능한 메모리: !free_mem_mb! MB

REM CPU 사용률 확인 (간단한 방법)
echo CPU 정보:
wmic cpu get name,loadpercentage /format:list | findstr "LoadPercentage\|Name" | findstr /v "^$"

echo.
echo ================================
echo       상태 점검 완료
echo ================================
echo.

REM 권장 사항 출력
echo 💡 권장 사항:
if not exist "logs\mastodon_bot.log" (
    echo - 봇을 한 번 실행하여 로그 파일을 생성하세요
)
echo - 정기적으로 로그 파일을 확인하여 에러가 없는지 점검하세요
echo - 디스크 공간이 부족하면 로그 파일을 정리하세요
echo - Windows 업데이트를 정기적으로 적용하세요
echo.

echo 상세한 연결 테스트는 test_bot.bat을 실행하세요.
echo.
pause
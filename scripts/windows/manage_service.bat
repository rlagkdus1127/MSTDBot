@echo off
chcp 65001 >nul

REM 마스토돈 봇 서비스 관리 스크립트

:menu
cls
echo ================================
echo  마스토돈 봇 서비스 관리
echo ================================
echo.
echo 1. 서비스 시작
echo 2. 서비스 중지  
echo 3. 서비스 재시작
echo 4. 서비스 상태 확인
echo 5. 서비스 로그 보기
echo 6. 서비스 제거
echo 7. 작업 관리자에서 프로세스 확인
echo 0. 종료
echo.
set /p choice="선택하세요 (0-7): "

if "%choice%"=="1" goto start_service
if "%choice%"=="2" goto stop_service  
if "%choice%"=="3" goto restart_service
if "%choice%"=="4" goto status_service
if "%choice%"=="5" goto logs_service
if "%choice%"=="6" goto remove_service
if "%choice%"=="7" goto show_processes
if "%choice%"=="0" goto exit
goto menu

:start_service
echo.
echo 서비스 시작 중...
net start "MastodonBot"
if %errorlevel% equ 0 (
    echo ✅ 서비스가 시작되었습니다.
) else (
    echo ❌ 서비스 시작 실패. 상태를 확인하세요.
)
echo.
pause
goto menu

:stop_service
echo.
echo 서비스 중지 중...
net stop "MastodonBot"
if %errorlevel% equ 0 (
    echo ✅ 서비스가 중지되었습니다.
) else (
    echo ❌ 서비스 중지 실패. 상태를 확인하세요.
)
echo.
pause
goto menu

:restart_service
echo.
echo 서비스 재시작 중...
echo 1. 서비스 중지...
net stop "MastodonBot"
timeout /t 3 /nobreak >nul
echo 2. 서비스 시작...
net start "MastodonBot"
if %errorlevel% equ 0 (
    echo ✅ 서비스가 재시작되었습니다.
) else (
    echo ❌ 서비스 재시작 실패.
)
echo.
pause
goto menu

:status_service
echo.
echo ================================
echo        서비스 상태
echo ================================
sc query "MastodonBot"
echo.

echo 상세 정보:
sc qc "MastodonBot"
echo.
pause
goto menu

:logs_service
echo.
echo 로그 파일들:
echo ================================
set "BOT_DIR=%~dp0..\.."

if exist "%BOT_DIR%\logs\service.log" (
    echo [서비스 로그] %BOT_DIR%\logs\service.log
    echo 마지막 20줄:
    echo --------------------------------
    for /f "skip=1 tokens=*" %%i in ('type "%BOT_DIR%\logs\service.log"') do (
        set /a count+=1
    )
    if !count! gtr 20 (
        more +!count! "%BOT_DIR%\logs\service.log"
    ) else (
        type "%BOT_DIR%\logs\service.log"
    )
    echo.
) else (
    echo ❌ 서비스 로그 파일이 없습니다.
)

if exist "%BOT_DIR%\logs\mastodon_bot.log" (
    echo.
    echo [봇 로그] %BOT_DIR%\logs\mastodon_bot.log  
    echo 마지막 10줄:
    echo --------------------------------
    powershell -command "Get-Content '%BOT_DIR%\logs\mastodon_bot.log' -Tail 10"
) else (
    echo ❌ 봇 로그 파일이 없습니다.
)

echo.
echo 실시간 로그를 보려면 다음 파일들을 텍스트 에디터로 열어두세요:
echo - %BOT_DIR%\logs\service.log
echo - %BOT_DIR%\logs\mastodon_bot.log
echo.
pause
goto menu

:remove_service
echo.
echo ⚠️ 경고: 서비스를 완전히 제거합니다.
echo 계속하시겠습니까? (Y/N)
set /p confirm="선택: "
if /i not "%confirm%"=="Y" goto menu

echo.
echo 서비스 제거 중...
echo 1. 서비스 중지...
net stop "MastodonBot" >nul 2>&1

echo 2. 서비스 제거...
set "BOT_DIR=%~dp0..\.."
if exist "%BOT_DIR%\scripts\windows\nssm.exe" (
    "%BOT_DIR%\scripts\windows\nssm.exe" remove "MastodonBot" confirm
    echo ✅ 서비스가 제거되었습니다.
) else (
    sc delete "MastodonBot"
    echo ✅ 서비스가 제거되었습니다.
)
echo.
pause
goto menu

:show_processes
echo.
echo ================================
echo     실행 중인 Python 프로세스
echo ================================
tasklist /FI "IMAGENAME eq python.exe" /V
echo.
echo Python 프로세스 상세 정보:
wmic process where "name='python.exe'" get ProcessId,CommandLine,CreationDate
echo.
pause
goto menu

:exit
echo.
echo 프로그램을 종료합니다.
exit /b 0
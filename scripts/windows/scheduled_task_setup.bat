@echo off
chcp 65001 >nul

REM 관리자 권한 확인
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo 이 스크립트는 관리자 권한이 필요합니다.
    echo 우클릭하여 "관리자 권한으로 실행"을 선택해주세요.
    pause
    exit /b 1
)

echo ================================
echo  마스토돈 봇 예약 작업 설정
echo ================================
echo.
echo 이 스크립트는 다음 작업들을 예약 작업으로 등록합니다:
echo 1. 봇 자동 시작 (시스템 시작 시)
echo 2. 상태 점검 (매 5분마다)
echo 3. 로그 정리 (매일 자정)
echo.

set "BOT_DIR=%~dp0..\.."
set "BOT_DIR=%BOT_DIR:\=\\%"

echo 봇 디렉토리: %BOT_DIR%
echo.

REM 1. 봇 자동 시작 작업
echo [1/3] 봇 자동 시작 작업 생성 중...

REM XML 파일 생성
(
echo ^<?xml version="1.0" encoding="UTF-16"?^>
echo ^<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
echo   ^<RegistrationInfo^>
echo     ^<Description^>마스토돈 스프레드시트 봇 자동 시작^</Description^>
echo   ^</RegistrationInfo^>
echo   ^<Triggers^>
echo     ^<BootTrigger^>
echo       ^<Enabled^>true^</Enabled^>
echo       ^<Delay^>PT2M^</Delay^>
echo     ^</BootTrigger^>
echo   ^</Triggers^>
echo   ^<Principals^>
echo     ^<Principal id="Author"^>
echo       ^<LogonType^>ServiceAccount^</LogonType^>
echo       ^<UserId^>S-1-5-18^</UserId^>
echo       ^<RunLevel^>HighestAvailable^</RunLevel^>
echo     ^</Principal^>
echo   ^</Principals^>
echo   ^<Settings^>
echo     ^<MultipleInstancesPolicy^>IgnoreNew^</MultipleInstancesPolicy^>
echo     ^<DisallowStartIfOnBatteries^>false^</DisallowStartIfOnBatteries^>
echo     ^<StopIfGoingOnBatteries^>false^</StopIfGoingOnBatteries^>
echo     ^<AllowHardTerminate^>true^</AllowHardTerminate^>
echo     ^<StartWhenAvailable^>true^</StartWhenAvailable^>
echo     ^<RunOnlyIfNetworkAvailable^>true^</RunOnlyIfNetworkAvailable^>
echo     ^<AllowStartOnDemand^>true^</AllowStartOnDemand^>
echo     ^<Enabled^>true^</Enabled^>
echo     ^<Hidden^>false^</Hidden^>
echo     ^<RunOnlyIfIdle^>false^</RunOnlyIfIdle^>
echo     ^<DisallowStartOnRemoteAppSession^>false^</DisallowStartOnRemoteAppSession^>
echo     ^<UseUnifiedSchedulingEngine^>true^</UseUnifiedSchedulingEngine^>
echo     ^<WakeToRun^>false^</WakeToRun^>
echo     ^<ExecutionTimeLimit^>PT0S^</ExecutionTimeLimit^>
echo     ^<Priority^>7^</Priority^>
echo     ^<RestartOnFailure^>
echo       ^<Interval^>PT5M^</Interval^>
echo       ^<Count^>3^</Count^>
echo     ^</RestartOnFailure^>
echo   ^</Settings^>
echo   ^<Actions Context="Author"^>
echo     ^<Exec^>
echo       ^<Command^>%BOT_DIR%\\scripts\\windows\\start_bot.bat^</Command^>
echo       ^<WorkingDirectory^>%BOT_DIR%^</WorkingDirectory^>
echo     ^</Exec^>
echo   ^</Actions^>
echo ^</Task^>
) > "%TEMP%\MastodonBot_AutoStart.xml"

schtasks /create /tn "MastodonBot\AutoStart" /xml "%TEMP%\MastodonBot_AutoStart.xml" /f
if %errorlevel% equ 0 (
    echo ✅ 자동 시작 작업 생성 완료
) else (
    echo ❌ 자동 시작 작업 생성 실패
)

REM 2. 상태 점검 작업
echo.
echo [2/3] 상태 점검 작업 생성 중...

(
echo ^<?xml version="1.0" encoding="UTF-16"?^>
echo ^<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
echo   ^<RegistrationInfo^>
echo     ^<Description^>마스토돈 봇 상태 점검 (5분마다^)^</Description^>
echo   ^</RegistrationInfo^>
echo   ^<Triggers^>
echo     ^<TimeTrigger^>
echo       ^<Repetition^>
echo         ^<Interval^>PT5M^</Interval^>
echo       ^</Repetition^>
echo       ^<StartBoundary^>2024-01-01T00:00:00^</StartBoundary^>
echo       ^<Enabled^>true^</Enabled^>
echo     ^</TimeTrigger^>
echo   ^</Triggers^>
echo   ^<Principals^>
echo     ^<Principal id="Author"^>
echo       ^<LogonType^>ServiceAccount^</LogonType^>
echo       ^<UserId^>S-1-5-18^</UserId^>
echo     ^</Principal^>
echo   ^</Principals^>
echo   ^<Settings^>
echo     ^<MultipleInstancesPolicy^>IgnoreNew^</MultipleInstancesPolicy^>
echo     ^<DisallowStartIfOnBatteries^>false^</DisallowStartIfOnBatteries^>
echo     ^<StopIfGoingOnBatteries^>false^</StopIfGoingOnBatteries^>
echo     ^<AllowHardTerminate^>true^</AllowHardTerminate^>
echo     ^<StartWhenAvailable^>true^</StartWhenAvailable^>
echo     ^<RunOnlyIfNetworkAvailable^>false^</RunOnlyIfNetworkAvailable^>
echo     ^<AllowStartOnDemand^>true^</AllowStartOnDemand^>
echo     ^<Enabled^>true^</Enabled^>
echo     ^<Hidden^>true^</Hidden^>
echo     ^<RunOnlyIfIdle^>false^</RunOnlyIfIdle^>
echo     ^<DisallowStartOnRemoteAppSession^>false^</DisallowStartOnRemoteAppSession^>
echo     ^<UseUnifiedSchedulingEngine^>true^</UseUnifiedSchedulingEngine^>
echo     ^<WakeToRun^>false^</WakeToRun^>
echo     ^<ExecutionTimeLimit^>PT5M^</ExecutionTimeLimit^>
echo     ^<Priority^>7^</Priority^>
echo   ^</Settings^>
echo   ^<Actions Context="Author"^>
echo     ^<Exec^>
echo       ^<Command^>%BOT_DIR%\\scripts\\windows\\health_check.bat^</Command^>
echo       ^<WorkingDirectory^>%BOT_DIR%^</WorkingDirectory^>
echo     ^</Exec^>
echo   ^</Actions^>
echo ^</Task^>
) > "%TEMP%\MastodonBot_HealthCheck.xml"

schtasks /create /tn "MastodonBot\HealthCheck" /xml "%TEMP%\MastodonBot_HealthCheck.xml" /f
if %errorlevel% equ 0 (
    echo ✅ 상태 점검 작업 생성 완료
) else (
    echo ❌ 상태 점검 작업 생성 실패
)

REM 3. 로그 정리 작업
echo.
echo [3/3] 로그 정리 작업 생성 중...

REM 로그 정리 스크립트 생성
(
echo @echo off
echo REM 로그 정리 스크립트
echo set "BOT_DIR=%BOT_DIR%"
echo cd /d "%%BOT_DIR%%"
echo.
echo REM 30일 이상 된 로그 파일 삭제
echo forfiles /p "logs" /m "*.log" /d -30 /c "cmd /c del @path" 2^>nul
echo.
echo REM 로그 파일 크기 제한 (10MB 이상인 경우 백업 후 초기화)
echo for %%%%f in (logs\*.log^) do (
echo     if %%%%~zf gtr 10485760 (
echo         echo 대용량 로그 파일 발견: %%%%f
echo         copy "%%%%f" "%%%%f.backup.%%date:~0,4%%%%date:~5,2%%%%date:~8,2%%" ^>nul
echo         echo. ^> "%%%%f"
echo     ^)
echo ^)
echo.
echo echo 로그 정리 완료: %%date%% %%time%% ^>^> logs\cleanup.log
) > "%BOT_DIR%\scripts\windows\cleanup_logs.bat"

(
echo ^<?xml version="1.0" encoding="UTF-16"?^>
echo ^<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
echo   ^<RegistrationInfo^>
echo     ^<Description^>마스토돈 봇 로그 정리 (매일 자정^)^</Description^>
echo   ^</RegistrationInfo^>
echo   ^<Triggers^>
echo     ^<CalendarTrigger^>
echo       ^<StartBoundary^>2024-01-01T00:00:00^</StartBoundary^>
echo       ^<Enabled^>true^</Enabled^>
echo       ^<ScheduleByDay^>
echo         ^<DaysInterval^>1^</DaysInterval^>
echo       ^</ScheduleByDay^>
echo     ^</CalendarTrigger^>
echo   ^</Triggers^>
echo   ^<Principals^>
echo     ^<Principal id="Author"^>
echo       ^<LogonType^>ServiceAccount^</LogonType^>
echo       ^<UserId^>S-1-5-18^</UserId^>
echo     ^</Principal^>
echo   ^</Principals^>
echo   ^<Settings^>
echo     ^<MultipleInstancesPolicy^>IgnoreNew^</MultipleInstancesPolicy^>
echo     ^<DisallowStartIfOnBatteries^>false^</DisallowStartIfOnBatteries^>
echo     ^<StopIfGoingOnBatteries^>false^</StopIfGoingOnBatteries^>
echo     ^<AllowHardTerminate^>true^</AllowHardTerminate^>
echo     ^<StartWhenAvailable^>true^</StartWhenAvailable^>
echo     ^<RunOnlyIfNetworkAvailable^>false^</RunOnlyIfNetworkAvailable^>
echo     ^<AllowStartOnDemand^>true^</AllowStartOnDemand^>
echo     ^<Enabled^>true^</Enabled^>
echo     ^<Hidden^>true^</Hidden^>
echo     ^<RunOnlyIfIdle^>false^</RunOnlyIfIdle^>
echo     ^<DisallowStartOnRemoteAppSession^>false^</DisallowStartOnRemoteAppSession^>
echo     ^<UseUnifiedSchedulingEngine^>true^</UseUnifiedSchedulingEngine^>
echo     ^<WakeToRun^>false^</WakeToRun^>
echo     ^<ExecutionTimeLimit^>PT10M^</ExecutionTimeLimit^>
echo     ^<Priority^>7^</Priority^>
echo   ^</Settings^>
echo   ^<Actions Context="Author"^>
echo     ^<Exec^>
echo       ^<Command^>%BOT_DIR%\\scripts\\windows\\cleanup_logs.bat^</Command^>
echo       ^<WorkingDirectory^>%BOT_DIR%^</WorkingDirectory^>
echo     ^</Exec^>
echo   ^</Actions^>
echo ^</Task^>
) > "%TEMP%\MastodonBot_LogCleanup.xml"

schtasks /create /tn "MastodonBot\LogCleanup" /xml "%TEMP%\MastodonBot_LogCleanup.xml" /f
if %errorlevel% equ 0 (
    echo ✅ 로그 정리 작업 생성 완료
) else (
    echo ❌ 로그 정리 작업 생성 실패
)

REM 임시 파일 정리
del "%TEMP%\MastodonBot_*.xml" >nul 2>&1

echo.
echo ================================
echo      예약 작업 설정 완료!
echo ================================
echo.
echo 생성된 예약 작업:
echo 1. MastodonBot\AutoStart - 시스템 시작 시 봇 자동 실행
echo 2. MastodonBot\HealthCheck - 5분마다 상태 점검
echo 3. MastodonBot\LogCleanup - 매일 자정 로그 정리
echo.
echo 예약 작업 관리:
echo - 목록 보기: schtasks /query /fo list /tn "MastodonBot\*"
echo - 작업 실행: schtasks /run /tn "MastodonBot\AutoStart"
echo - 작업 비활성화: schtasks /change /tn "MastodonBot\AutoStart" /disable
echo - 작업 삭제: schtasks /delete /tn "MastodonBot\AutoStart" /f
echo.
echo 작업 스케줄러(taskschd.msc)에서도 관리할 수 있습니다.
echo.
pause
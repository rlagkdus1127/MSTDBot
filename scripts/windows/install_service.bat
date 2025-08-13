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
echo  마스토돈 봇 윈도우 서비스 설치
echo ================================
echo.

set "BOT_DIR=%~dp0..\.."
cd /d "%BOT_DIR%"

REM 현재 디렉토리 확인
echo 봇 디렉토리: %CD%

REM Python 경로 확인
for /f "tokens=*" %%i in ('where python') do set "PYTHON_PATH=%%i"
if "%PYTHON_PATH%"=="" (
    echo ❌ Python을 찾을 수 없습니다. PATH에 Python이 추가되어 있는지 확인하세요.
    pause
    exit /b 1
)
echo Python 경로: %PYTHON_PATH%

REM 서비스 래퍼 스크립트 생성
echo 서비스 래퍼 스크립트 생성 중...

(
echo import os
echo import sys
echo import subprocess
echo import time
echo import logging
echo from pathlib import Path
echo.
echo # 현재 스크립트 경로에서 봇 디렉토리 찾기
echo script_dir = Path(__file__^).parent.absolute()
echo bot_dir = script_dir.parent.parent
echo os.chdir(bot_dir^)
echo.
echo # 가상환경 Python 경로
echo venv_python = bot_dir / "venv" / "Scripts" / "python.exe"
echo main_py = bot_dir / "main.py"
echo.
echo # 로깅 설정
echo log_file = bot_dir / "logs" / "service.log"
echo log_file.parent.mkdir(exist_ok=True^)
echo.
echo logging.basicConfig(
echo     level=logging.INFO,
echo     format='%%(asctime^)s - %%(levelname^)s - %%(message^)s',
echo     handlers=[
echo         logging.FileHandler(log_file, encoding='utf-8'^),
echo         logging.StreamHandler()
echo     ]
echo ^)
echo logger = logging.getLogger(__name__^)
echo.
echo def run_bot():
echo     """봇 실행 함수"""
echo     max_retries = 5
echo     retry_count = 0
echo     
echo     while retry_count ^< max_retries:
echo         try:
echo             logger.info(f"봇 시작 시도 #{retry_count + 1}"^)
echo             
echo             # 가상환경의 Python으로 main.py 실행
echo             result = subprocess.run([
echo                 str(venv_python^),
echo                 str(main_py^)
echo             ], cwd=bot_dir, check=True^)
echo             
echo             logger.info("봇이 정상적으로 종료되었습니다."^)
echo             break
echo             
echo         except subprocess.CalledProcessError as e:
echo             retry_count += 1
echo             logger.error(f"봇 실행 실패 (시도 {retry_count}/{max_retries}^): {e}"^)
echo             
echo             if retry_count ^< max_retries:
echo                 wait_time = min(300, 30 * retry_count^)
echo                 logger.info(f"{wait_time}초 후 재시작..."^)
echo                 time.sleep(wait_time^)
echo             else:
echo                 logger.error("최대 재시도 횟수에 도달했습니다."^)
echo                 
echo         except KeyboardInterrupt:
echo             logger.info("서비스 중지 요청"^)
echo             break
echo         except Exception as e:
echo             retry_count += 1
echo             logger.error(f"예상치 못한 오류: {e}"^)
echo             if retry_count ^< max_retries:
echo                 time.sleep(60^)
echo.
echo if __name__ == "__main__":
echo     logger.info("마스토돈 봇 서비스 시작"^)
echo     run_bot()
echo     logger.info("마스토돈 봇 서비스 종료"^)
) > scripts\windows\service_wrapper.py

echo ✅ 서비스 래퍼 생성 완료

REM NSSM 다운로드 확인
echo.
echo NSSM (Non-Sucking Service Manager) 확인 중...
if not exist "scripts\windows\nssm.exe" (
    echo NSSM을 다운로드해야 합니다.
    echo https://nssm.cc/download 에서 nssm.exe를 다운로드하여
    echo scripts\windows\ 폴더에 저장하고 다시 실행해주세요.
    pause
    exit /b 1
)
echo ✅ NSSM 확인됨

REM 서비스 설치
echo.
echo 마스토돈 봇 서비스 설치 중...
scripts\windows\nssm.exe install "MastodonBot" "%PYTHON_PATH%" "%CD%\scripts\windows\service_wrapper.py"
scripts\windows\nssm.exe set "MastodonBot" AppDirectory "%CD%"
scripts\windows\nssm.exe set "MastodonBot" DisplayName "마스토돈 스프레드시트 봇"
scripts\windows\nssm.exe set "MastodonBot" Description "구글 스프레드시트와 연동된 마스토돈 봇 서비스"
scripts\windows\nssm.exe set "MastodonBot" Start SERVICE_AUTO_START

echo ✅ 서비스 설치 완료

REM 서비스 시작
echo.
echo 서비스를 시작하시겠습니까? (Y/N)
set /p choice="선택: "
if /i "%choice%"=="Y" (
    echo 서비스 시작 중...
    net start "MastodonBot"
    if %errorlevel% equ 0 (
        echo ✅ 서비스가 성공적으로 시작되었습니다!
    ) else (
        echo ❌ 서비스 시작 실패. 로그를 확인하세요.
    )
)

echo.
echo ================================
echo       설치 완료!
echo ================================
echo.
echo 서비스 관리 명령어:
echo - 시작: net start "MastodonBot"
echo - 중지: net stop "MastodonBot"
echo - 상태: sc query "MastodonBot"
echo - 제거: scripts\windows\nssm.exe remove "MastodonBot" confirm
echo.
echo 로그 파일: logs\service.log
echo 서비스는 자동으로 재시작되며, Windows 부팅 시 자동으로 시작됩니다.
echo.
pause
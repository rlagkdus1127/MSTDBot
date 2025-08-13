@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM 마스토돈 봇 연결 테스트 스크립트

echo ================================
echo    마스토돈 봇 연결 테스트
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
echo 환경 설정 파일 확인 중...
if not exist ".env" (
    echo ❌ .env 파일이 없습니다. setup_bot.bat을 먼저 실행하세요.
    pause
    exit /b 1
)
echo ✅ .env 파일 확인됨
echo.

REM 연결 테스트 실행
echo 연결 테스트 실행 중...
echo --------------------------------
echo.

python -c "
import os
import sys
from pathlib import Path

# .env 파일 로드
try:
    with open('.env', 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                os.environ[key.strip()] = value.strip()
except Exception as e:
    print(f'❌ .env 파일 로드 실패: {e}')
    sys.exit(1)

# 필수 환경 변수 확인
required_vars = [
    'MASTODON_ACCESS_TOKEN',
    'MASTODON_API_BASE_URL', 
    'GOOGLE_SERVICE_ACCOUNT_FILE',
    'SPREADSHEET_ID'
]

missing_vars = []
for var in required_vars:
    if not os.getenv(var):
        missing_vars.append(var)

if missing_vars:
    print('❌ 다음 환경 변수들이 설정되지 않았습니다:')
    for var in missing_vars:
        print(f'   - {var}')
    print('\\n.env 파일을 편집하여 값들을 설정해주세요.')
    sys.exit(1)

print('✅ 환경 변수 확인 완료')
print()

# 구글 시트 연결 테스트
print('구글 스프레드시트 연결 테스트...')
try:
    from google_sheets import GoogleSheetsManager
    
    service_account_file = os.getenv('GOOGLE_SERVICE_ACCOUNT_FILE')
    spreadsheet_id = os.getenv('SPREADSHEET_ID')
    
    if not Path(service_account_file).exists():
        print(f'❌ 구글 서비스 계정 키 파일을 찾을 수 없습니다: {service_account_file}')
        sys.exit(1)
    
    google_sheets = GoogleSheetsManager(service_account_file, spreadsheet_id)
    
    # 키워드 데이터 테스트
    keywords_sheet = os.getenv('KEYWORDS_SHEET_NAME', 'keywords')
    keywords = google_sheets.get_keywords_data(keywords_sheet)
    print(f'✅ 키워드 {len(keywords)}개 로드됨')
    
    # 가챠 아이템 테스트
    gacha_sheet = os.getenv('GACHA_SHEET_NAME', '가챠')
    gacha_items = google_sheets.get_gacha_items(gacha_sheet)
    print(f'✅ 가챠 아이템 {len(gacha_items)}개 로드됨')
    
except Exception as e:
    print(f'❌ 구글 스프레드시트 연결 실패: {e}')
    sys.exit(1)

print()

# 마스토돈 API 연결 테스트  
print('마스토돈 API 연결 테스트...')
try:
    from mastodon import Mastodon
    
    mastodon = Mastodon(
        access_token=os.getenv('MASTODON_ACCESS_TOKEN'),
        api_base_url=os.getenv('MASTODON_API_BASE_URL')
    )
    
    account = mastodon.me()
    print(f'✅ 봇 계정 확인: @{account[\"username\"]}')
    print(f'   - 팔로워: {account[\"followers_count\"]}명')
    print(f'   - 팔로잉: {account[\"following_count\"]}명')
    
except Exception as e:
    print(f'❌ 마스토돈 API 연결 실패: {e}')
    sys.exit(1)

print()
print('🎉 모든 연결 테스트가 성공했습니다!')
print()
print('봇을 시작하려면 start_bot.bat을 실행하세요.')
"

if %errorlevel% neq 0 (
    echo.
    echo ❌ 테스트 실패
    echo 설정을 확인하고 다시 시도하세요.
) else (
    echo.
    echo ================================
    echo      테스트 완료! 🎉
    echo ================================
)

echo.
pause
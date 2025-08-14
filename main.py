import os
import sys
import logging
import signal
from datetime import datetime
from dotenv import load_dotenv
from google_sheets import GoogleSheetsManager
from mastodon_bot import MastodonBot

# 전역 변수
bot_instance = None
running = True

def signal_handler(signum, frame):
    """시그널 핸들러"""
    global running, bot_instance
    logging.info(f"시그널 {signum} 수신. 봇을 안전하게 종료합니다...")
    running = False
    if bot_instance:
        # 봇이 실행 중이라면 스트리밍 중지
        try:
            # 마스토돈 스트리밍 중지는 KeyboardInterrupt로 처리됨
            pass
        except:
            pass
    sys.exit(0)

def setup_logging():
    """로깅 설정"""
    log_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "logs")
    os.makedirs(log_dir, exist_ok=True)
    
    log_file = os.path.join(log_dir, "mastodon_bot.log")
    
    # 로그 포맷 설정
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # 파일 핸들러 (INFO 레벨 이상)
    file_handler = logging.FileHandler(log_file, encoding='utf-8')
    file_handler.setLevel(logging.INFO)
    file_handler.setFormatter(formatter)
    
    # 콘솔 핸들러 (INFO 레벨 이상)
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(formatter)
    
    # 루트 로거 설정
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.INFO)
    root_logger.addHandler(file_handler)
    root_logger.addHandler(console_handler)
    
    return logging.getLogger(__name__)

def main():
    global bot_instance, running
    
    # 로깅 설정
    logger = setup_logging()
    logger.info("=== 마스토돈 스프레드시트 봇 시작 ===")
    
    # 시그널 핸들러 등록
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    try:
        # 환경 변수 로드
        load_dotenv()
        logger.info("환경 변수 로드 완료")
        
        # 필수 환경 변수 확인
        required_vars = [
            'MASTODON_ACCESS_TOKEN',
            'MASTODON_API_BASE_URL',
            'GOOGLE_SERVICE_ACCOUNT_FILE',
            'SPREADSHEET_ID',
            'KEYWORDS_SHEET_NAME',
            'ACQUISITION_LOG_SHEET_NAME'
        ]
    
        missing_vars = []
        for var in required_vars:
            if not os.getenv(var):
                missing_vars.append(var)
        
        if missing_vars:
            logger.error("다음 환경 변수들이 설정되지 않았습니다:")
            for var in missing_vars:
                logger.error(f"  - {var}")
            logger.error(".env 파일을 생성하고 필요한 값들을 설정해주세요.")
            logger.error(".env.example 파일을 참고하세요.")
            return 1
    
        # 환경 변수에서 설정 값들 가져오기
        mastodon_token = os.getenv('MASTODON_ACCESS_TOKEN')
        mastodon_url = os.getenv('MASTODON_API_BASE_URL')
        service_account_file = os.getenv('GOOGLE_SERVICE_ACCOUNT_FILE')
        spreadsheet_id = os.getenv('SPREADSHEET_ID')
        keywords_sheet = os.getenv('KEYWORDS_SHEET_NAME')
        acquisition_sheet = os.getenv('ACQUISITION_LOG_SHEET_NAME')
        gacha_sheet = os.getenv('GACHA_SHEET_NAME', '가챠')
        store_sheet = os.getenv('STORE_SHEET_NAME', '상점')
        
        logger.info("환경 변수 확인 완료")
        
        # 구글 시트 매니저 초기화
        logger.info("구글 스프레드시트 연결 중...")
        google_sheets = GoogleSheetsManager(service_account_file, spreadsheet_id)
        
        # 획득 로그 시트 설정
        google_sheets.setup_acquisition_log_sheet(acquisition_sheet)
        logger.info("구글 스프레드시트 연결 완료")
        
        # 마스토돈 봇 초기화
        logger.info("마스토돈 봇 초기화 중...")
        bot_instance = MastodonBot(
            mastodon_token,
            mastodon_url,
            google_sheets,
            keywords_sheet,
            acquisition_sheet,
            gacha_sheet,
            store_sheet
        )
        
        # 초기 키워드 데이터 로드 테스트
        logger.info("키워드 데이터 로드 테스트...")
        keywords_data = google_sheets.get_keywords_data(keywords_sheet)
        logger.info(f"로드된 키워드 수: {len(keywords_data)}")
        
        if keywords_data:
            sample_keywords = list(keywords_data.items())[:3]
            for keyword, response in sample_keywords:
                response_preview = response[:50] + '...' if len(response) > 50 else response
                logger.info(f"키워드 예시: '{keyword}' -> '{response_preview}'")
        
        # 가챠 아이템 데이터 로드 테스트
        logger.info("가챠 아이템 로드 테스트...")
        gacha_items = google_sheets.get_gacha_items(gacha_sheet)
        logger.info(f"로드된 가챠 아이템 수: {len(gacha_items)}")
        
        if gacha_items:
            for i in range(min(5, len(gacha_items))):
                logger.info(f"가챠 아이템 {i+1}: {gacha_items[i]}")
        
        # 상점 아이템 데이터 로드 테스트
        logger.info("상점 아이템 로드 테스트...")
        store_items = google_sheets.get_store_items(store_sheet)
        logger.info(f"로드된 상점 아이템 수: {len(store_items)}")
        
        if store_items:
            for i in range(min(5, len(store_items))):
                item = store_items[i]
                logger.info(f"상점 아이템 {i+1}: {item['name']} - {item['price']} 갈레온")
        
        # 봇 시작 메시지
        logger.info("=== 마스토돈 봇 시작 ===")
        logger.info(f"마스토돈 인스턴스: {mastodon_url}")
        logger.info(f"스프레드시트 ID: {spreadsheet_id}")
        logger.info(f"키워드 시트: {keywords_sheet}")
        logger.info(f"가챠 시트: {gacha_sheet}")
        logger.info(f"상점 시트: {store_sheet}")
        logger.info(f"획득 로그 시트: {acquisition_sheet}")
        logger.info("봇이 실행 중입니다. 종료하려면 SIGTERM/SIGINT 시그널을 보내주세요.")
        
        # 스트리밍 시작
        if running:
            bot_instance.start_streaming()
            
    except KeyboardInterrupt:
        logger.info("키보드 인터럽트로 봇 종료")
        return 0
    except Exception as e:
        logger.error(f"예상치 못한 오류 발생: {e}", exc_info=True)
        return 1
    finally:
        logger.info("=== 마스토돈 스프레드시트 봇 종료 ===")
        
    return 0

if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
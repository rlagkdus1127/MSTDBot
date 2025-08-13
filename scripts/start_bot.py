#!/usr/bin/env python3
"""
마스토돈 봇 자동 재시작 래퍼 스크립트

이 스크립트는 봇이 오류로 인해 종료되어도 자동으로 재시작하도록 합니다.
최대 재시도 횟수와 점진적 대기 시간을 통해 안정성을 높입니다.
"""

import os
import sys
import time
import logging
import signal
from datetime import datetime
from pathlib import Path

class BotManager:
    def __init__(self, bot_dir="/home/botuser/mastodon-bot"):
        self.bot_dir = Path(bot_dir)
        self.max_retries = 5
        self.base_wait_time = 30
        self.max_wait_time = 300
        self.setup_logging()
        self.setup_signal_handlers()
        self.running = True
        
    def setup_logging(self):
        """로깅 설정"""
        log_file = self.bot_dir / "logs" / "bot_manager.log"
        log_file.parent.mkdir(exist_ok=True)
        
        # 로그 포맷 설정
        formatter = logging.Formatter(
            '%(asctime)s - %(levelname)s - [%(name)s] - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        
        # 파일 핸들러
        file_handler = logging.FileHandler(log_file)
        file_handler.setFormatter(formatter)
        file_handler.setLevel(logging.INFO)
        
        # 콘솔 핸들러
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(formatter)
        console_handler.setLevel(logging.INFO)
        
        # 로거 설정
        self.logger = logging.getLogger('BotManager')
        self.logger.setLevel(logging.INFO)
        self.logger.addHandler(file_handler)
        self.logger.addHandler(console_handler)
        
    def setup_signal_handlers(self):
        """시그널 핸들러 설정"""
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
        
    def signal_handler(self, signum, frame):
        """시그널 처리"""
        self.logger.info(f"시그널 {signum} 수신. 봇 매니저를 종료합니다.")
        self.running = False
        
    def check_environment(self):
        """환경 설정 확인"""
        required_files = [
            self.bot_dir / ".env",
            self.bot_dir / "service_account.json",
            self.bot_dir / "main.py"
        ]
        
        for file_path in required_files:
            if not file_path.exists():
                self.logger.error(f"필수 파일이 없습니다: {file_path}")
                return False
                
        # 가상환경 확인
        venv_python = self.bot_dir / "venv" / "bin" / "python"
        if not venv_python.exists():
            self.logger.error(f"가상환경이 설정되지 않았습니다: {venv_python}")
            return False
            
        return True
        
    def run_bot(self):
        """봇 실행"""
        try:
            os.chdir(self.bot_dir)
            
            # 가상환경 Python 경로 추가
            venv_path = str(self.bot_dir / "venv" / "lib" / "python3.8" / "site-packages")
            if venv_path not in sys.path:
                sys.path.insert(0, venv_path)
                
            # 현재 디렉토리를 Python 경로에 추가
            sys.path.insert(0, str(self.bot_dir))
            
            self.logger.info("봇 시작...")
            
            # main 모듈 임포트 및 실행
            import main
            main.main()
            
        except KeyboardInterrupt:
            self.logger.info("사용자에 의한 종료")
            raise
        except ImportError as e:
            self.logger.error(f"모듈 임포트 오류: {e}")
            raise
        except Exception as e:
            self.logger.error(f"봇 실행 중 오류: {e}")
            raise
            
    def calculate_wait_time(self, retry_count):
        """재시작 대기 시간 계산 (지수 백오프)"""
        wait_time = min(self.base_wait_time * (2 ** retry_count), self.max_wait_time)
        return wait_time
        
    def start(self):
        """봇 매니저 시작"""
        self.logger.info("=== 마스토돈 봇 매니저 시작 ===")
        
        # 환경 확인
        if not self.check_environment():
            self.logger.error("환경 설정 확인 실패. 프로그램을 종료합니다.")
            return False
            
        retry_count = 0
        last_restart_time = None
        
        while self.running and retry_count < self.max_retries:
            try:
                current_time = datetime.now()
                
                # 연속 재시작 방지 (1분 이내 재시작 시 카운트 증가)
                if last_restart_time and (current_time - last_restart_time).seconds < 60:
                    retry_count += 1
                else:
                    retry_count = 0
                    
                last_restart_time = current_time
                
                self.logger.info(f"봇 시작 시도 #{retry_count + 1}")
                self.run_bot()
                
                # 정상 종료된 경우
                self.logger.info("봇이 정상적으로 종료되었습니다.")
                break
                
            except KeyboardInterrupt:
                self.logger.info("사용자 중단")
                break
                
            except Exception as e:
                self.logger.error(f"봇 실행 실패: {e}")
                
                if retry_count < self.max_retries - 1 and self.running:
                    wait_time = self.calculate_wait_time(retry_count)
                    self.logger.info(f"{wait_time}초 후 재시작 시도... ({retry_count + 1}/{self.max_retries})")
                    
                    # 대기 (1초마다 종료 시그널 확인)
                    for _ in range(wait_time):
                        if not self.running:
                            break
                        time.sleep(1)
                else:
                    self.logger.error("최대 재시도 횟수 도달 또는 종료 요청")
                    break
                    
        self.logger.info("=== 마스토돈 봇 매니저 종료 ===")
        return True

def main():
    """메인 함수"""
    # 봇 디렉토리 경로 (환경에 따라 수정 필요)
    bot_dir = os.getenv("BOT_DIR", "/home/botuser/mastodon-bot")
    
    # 봇 매니저 시작
    manager = BotManager(bot_dir)
    success = manager.start()
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
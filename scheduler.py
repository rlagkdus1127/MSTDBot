import threading
import time
from datetime import datetime, timedelta
import pytz
import logging

class BotScheduler:
    def __init__(self, mastodon_bot):
        self.mastodon_bot = mastodon_bot
        self.korea_tz = pytz.timezone('Asia/Seoul')
        self.running = True
        self.scheduler_thread = None
        self.attendance_active = False
        self.attendance_start_time = None
        self.logger = logging.getLogger(__name__)
        
    def start(self):
        """스케줄러 시작"""
        if self.scheduler_thread is None or not self.scheduler_thread.is_alive():
            self.running = True
            self.scheduler_thread = threading.Thread(target=self._run_scheduler, daemon=True)
            self.scheduler_thread.start()
            self.logger.info("스케줄러가 시작되었습니다.")
    
    def stop(self):
        """스케줄러 중지"""
        self.running = False
        if self.scheduler_thread:
            self.scheduler_thread.join(timeout=5)
        self.logger.info("스케줄러가 중지되었습니다.")
    
    def _run_scheduler(self):
        """스케줄러 메인 루프"""
        last_curfew_day = None
        last_attendance_day = None
        
        while self.running:
            try:
                now = datetime.now(self.korea_tz)
                current_date = now.date()
                
                # 자정 통금 체크 (00:00)
                if (now.hour == 0 and now.minute == 0 and 
                    last_curfew_day != current_date):
                    self._post_curfew_message()
                    last_curfew_day = current_date
                
                # 오전 7시 출석 체크 (07:00)
                if (now.hour == 7 and now.minute == 0 and 
                    last_attendance_day != current_date):
                    self._post_attendance_message()
                    last_attendance_day = current_date
                
                # 출석 체크 종료 시간 확인 (다음날 자정)
                if self.attendance_active and now.hour == 0 and now.minute == 0:
                    self._end_attendance_check()
                
                # 30초마다 체크
                time.sleep(30)
                
            except Exception as e:
                self.logger.error(f"스케줄러 오류: {e}")
                time.sleep(60)  # 오류 시 1분 대기
    
    def _post_curfew_message(self):
        """통금 메시지 게시"""
        try:
            message = "🌙 통금이 시작되었습니다. 학생들은 기숙사로 돌아가세요."
            self.mastodon_bot.post_status(message)
            self.logger.info("통금 메시지가 게시되었습니다.")
            
            # 출석 체크 종료
            if self.attendance_active:
                self._end_attendance_check()
                
        except Exception as e:
            self.logger.error(f"통금 메시지 게시 오류: {e}")
    
    def _post_attendance_message(self):
        """출석 체크 메시지 게시"""
        try:
            message = "☀️ 아침이 밝았습니다. 출석 체크를 시작합니다.\n\n📢 출석하려면 이 툿에 '출석'을 포함해서 멘션해주세요!"
            self.mastodon_bot.post_status(message)
            
            # 출석 체크 활성화
            self.attendance_active = True
            self.attendance_start_time = datetime.now(self.korea_tz)
            
            self.logger.info("출석 체크 메시지가 게시되고 출석 체크가 활성화되었습니다.")
            
        except Exception as e:
            self.logger.error(f"출석 체크 메시지 게시 오류: {e}")
    
    def _end_attendance_check(self):
        """출석 체크 종료"""
        if self.attendance_active:
            self.attendance_active = False
            self.attendance_start_time = None
            self.logger.info("출석 체크가 종료되었습니다.")
    
    def is_attendance_active(self):
        """출석 체크 활성화 상태 확인"""
        return self.attendance_active
    
    def get_attendance_start_time(self):
        """출석 체크 시작 시간 반환"""
        return self.attendance_start_time
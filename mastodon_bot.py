import os
import time
from mastodon import Mastodon, StreamListener
import re
import random
from gacha_system import GachaSystem

class MastodonBotListener(StreamListener):
    def __init__(self, bot_instance):
        self.bot = bot_instance
        
    def on_notification(self, notification):
        """알림 수신 시 호출"""
        if notification['type'] == 'mention':
            self.bot.handle_mention(notification['status'])
    
    def on_update(self, status):
        """새로운 상태 업데이트 수신 시 호출 (타임라인)"""
        # 멘션된 경우만 처리
        if self.bot.is_mentioned(status):
            self.bot.handle_mention(status)

class MastodonBot:
    def __init__(self, access_token, api_base_url, google_sheets_manager, 
                 keywords_sheet, acquisition_sheet, gacha_sheet=None):
        self.access_token = access_token
        self.api_base_url = api_base_url
        self.google_sheets = google_sheets_manager
        self.keywords_sheet = keywords_sheet
        self.acquisition_sheet = acquisition_sheet
        self.gacha_sheet = gacha_sheet or "가챠"
        
        # 가챠 시스템 초기화
        self.gacha_system = GachaSystem()
        
        # 마스토돈 API 클라이언트 초기화
        self.mastodon = Mastodon(
            access_token=access_token,
            api_base_url=api_base_url
        )
        
        # 봇 계정 정보 가져오기
        self.bot_account = self.mastodon.me()
        self.bot_username = self.bot_account['username']
        
        print(f"봇 계정: @{self.bot_username}")
    
    def is_mentioned(self, status):
        """이 상태에서 봇이 멘션되었는지 확인"""
        mentions = status.get('mentions', [])
        for mention in mentions:
            if mention['username'] == self.bot_username:
                return True
        return False
    
    def extract_keywords(self, text):
        """텍스트에서 키워드 추출"""
        # 멘션 제거
        cleaned_text = re.sub(r'@\w+', '', text).strip()
        return cleaned_text
    
    def handle_mention(self, status):
        """멘션 처리"""
        try:
            user = status['account']['username']
            content = status['content']
            status_id = status['id']
            
            # HTML 태그 제거
            import html
            clean_content = html.unescape(re.sub(r'<[^>]+>', '', content))
            
            print(f"멘션 수신 - @{user}: {clean_content}")
            
            # 키워드 추출
            keywords_text = self.extract_keywords(clean_content)
            
            if not keywords_text:
                return
            
            # 소지품 키워드 확인
            if '소지품' in keywords_text.lower() or '인벤토리' in keywords_text.lower():
                self.handle_inventory(user, status_id)
                return
            
            # 1d100 주사위 키워드 확인
            if '1d100' in keywords_text.lower():
                self.handle_dice(user, status_id)
                return
            
            # 가챠 키워드 확인
            if '가챠' in keywords_text.lower():
                self.handle_gacha(user, status_id)
                return
            
            # 구글 시트에서 키워드 데이터 가져오기
            keywords_data = self.google_sheets.get_keywords_data(self.keywords_sheet)
            
            # 키워드 매칭
            response = self.find_matching_response(keywords_text, keywords_data)
            
            if response:
                # 응답 전송
                reply = f"@{user} {response}"
                self.mastodon.status_post(
                    reply, 
                    in_reply_to_id=status_id,
                    visibility='public'
                )
                
                print(f"응답 전송: {reply}")
                
                # '획득'이 포함된 경우 로그 기록
                if '획득' in response:
                    self.log_acquisition(user, response)
            
        except Exception as e:
            print(f"멘션 처리 중 오류 발생: {e}")
    
    def find_matching_response(self, text, keywords_data):
        """텍스트에서 매칭되는 키워드 찾기"""
        text_lower = text.lower()
        
        # 완전 일치 우선
        for keyword, response in keywords_data.items():
            if keyword.lower() == text_lower:
                return response
        
        # 부분 일치
        for keyword, response in keywords_data.items():
            if keyword.lower() in text_lower:
                return response
        
        return None
    
    def handle_inventory(self, username, status_id):
        """소지품 조회 처리"""
        try:
            # 유저명을 알파벳 단일 문자로 변환 (임시)
            # 실제로는 마스토돈 유저명과 시트명 매핑이 필요
            sheet_username = username[0].upper() if username else 'A'
            
            # 유효한 유저 확인 (A~T)
            valid_users = [chr(ord('A') + i) for i in range(20)]
            if sheet_username not in valid_users:
                sheet_username = 'A'  # 기본값
            
            # 소지품 조회
            inventory = self.google_sheets.get_user_inventory(sheet_username)
            
            if not inventory:
                response = f"소지품이 비어있습니다."
            else:
                response = f"소지품 목록 ({len(inventory)}개):\n"
                for i, item_data in enumerate(inventory[:10]):  # 최대 10개까지 표시
                    item = item_data['item']
                    quantity = item_data['quantity']
                    if quantity > 1:
                        response += f"• {item} x{quantity}\n"
                    else:
                        response += f"• {item}\n"
                
                if len(inventory) > 10:
                    response += f"... 외 {len(inventory) - 10}개"
            
            # 응답 전송
            reply = f"@{username} {response}"
            self.mastodon.status_post(
                reply, 
                in_reply_to_id=status_id,
                visibility='public'
            )
            
            print(f"소지품 조회 - {username} ({sheet_username}): {len(inventory)}개 아이템")
            
        except Exception as e:
            print(f"소지품 조회 중 오류 발생: {e}")
            # 오류 발생 시 사용자에게 알림
            reply = f"@{username} 소지품 조회 중 오류가 발생했습니다. 다시 시도해주세요."
            try:
                self.mastodon.status_post(
                    reply, 
                    in_reply_to_id=status_id,
                    visibility='public'
                )
            except:
                pass
    
    def handle_dice(self, username, status_id):
        """1d100 주사위 처리"""
        try:
            # 1~100 사이의 랜덤 숫자 생성
            result = random.randint(1, 100)
            
            # 응답 메시지 생성
            response = f"{result}이 나왔습니다!"
            
            # 응답 전송
            reply = f"@{username} {response}"
            self.mastodon.status_post(
                reply, 
                in_reply_to_id=status_id,
                visibility='public'
            )
            
            print(f"주사위 결과 - {username}: {result}")
            
        except Exception as e:
            print(f"주사위 처리 중 오류 발생: {e}")
            # 오류 발생 시 사용자에게 알림
            reply = f"@{username} 주사위 처리 중 오류가 발생했습니다. 다시 시도해주세요."
            try:
                self.mastodon.status_post(
                    reply, 
                    in_reply_to_id=status_id,
                    visibility='public'
                )
            except:
                pass

    def handle_gacha(self, username, status_id):
        """가챠 처리"""
        try:
            # 가챠 아이템 데이터 가져오기
            gacha_items = self.google_sheets.get_gacha_items(self.gacha_sheet)
            
            if not gacha_items:
                reply = f"@{username} 가챠 아이템이 설정되지 않았습니다. 관리자에게 문의하세요."
                self.mastodon.status_post(
                    reply, 
                    in_reply_to_id=status_id,
                    visibility='public'
                )
                return
            
            # 가챠 실행
            selected_item, rarity = self.gacha_system.get_random_item(gacha_items)
            response = self.gacha_system.format_gacha_result(selected_item, rarity)
            
            # 응답 전송
            reply = f"@{username} {response}"
            self.mastodon.status_post(
                reply, 
                in_reply_to_id=status_id,
                visibility='public'
            )
            
            print(f"가챠 결과 - {username}: {selected_item} ({rarity})")
            
            # 획득 로그 기록 (모든 가챠 결과는 '획득' 포함)
            self.log_acquisition(username, f"{selected_item} ({rarity})")
            
        except Exception as e:
            print(f"가챠 처리 중 오류 발생: {e}")
            # 오류 발생 시 사용자에게 알림
            reply = f"@{username} 가챠 처리 중 오류가 발생했습니다. 다시 시도해주세요."
            try:
                self.mastodon.status_post(
                    reply, 
                    in_reply_to_id=status_id,
                    visibility='public'
                )
            except:
                pass

    def log_acquisition(self, username, response):
        """획득 로그 기록"""
        try:
            # '획득'과 관련된 아이템 추출 (간단한 방식)
            item = response.replace('획득', '').strip()
            if item.endswith('!'):
                item = item[:-1].strip()
            
            # acquisition_log 시트에 기록
            self.google_sheets.log_acquisition(
                self.acquisition_sheet, 
                username, 
                item
            )
            
            # 유저 소지품 시트에도 직접 추가
            sheet_username = username[0].upper() if username else 'A'
            valid_users = [chr(ord('A') + i) for i in range(20)]
            if sheet_username in valid_users:
                self.google_sheets.add_item_to_user_inventory(sheet_username, item)
            
        except Exception as e:
            print(f"획득 로그 기록 중 오류: {e}")
    
    def start_streaming(self):
        """스트리밍 시작"""
        try:
            print("마스토돈 스트리밍 시작...")
            listener = MastodonBotListener(self)
            
            # 사용자 스트림 시작 (멘션 및 알림 수신)
            self.mastodon.stream_user(listener, run_async=False)
            
        except Exception as e:
            print(f"스트리밍 중 오류 발생: {e}")
            time.sleep(5)
            self.start_streaming()  # 재시작
    
    def post_status(self, message, visibility='public'):
        """상태 게시"""
        try:
            self.mastodon.status_post(message, visibility=visibility)
            print(f"상태 게시: {message}")
        except Exception as e:
            print(f"상태 게시 중 오류: {e}")
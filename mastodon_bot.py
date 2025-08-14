import os
import time
from mastodon import Mastodon, StreamListener
import re
import random
from gacha_system import GachaSystem
from scheduler import BotScheduler

class MastodonBotListener(StreamListener):
    def __init__(self, bot_instance):
        self.bot = bot_instance
        # 처리된 상태 ID를 저장하는 세트 (중복 방지)
        self.processed_status_ids = set()
        
    def on_notification(self, notification):
        """알림 수신 시 호출"""
        if notification['type'] == 'mention':
            status_id = notification['status']['id']
            # 이미 처리된 상태인지 확인
            if status_id not in self.processed_status_ids:
                self.processed_status_ids.add(status_id)
                self.bot.handle_mention(notification['status'])
                
                # 메모리 관리: 1000개 이상이면 오래된 것 제거
                if len(self.processed_status_ids) > 1000:
                    # 세트를 리스트로 변환하여 최근 500개만 유지
                    self.processed_status_ids = set(list(self.processed_status_ids)[-500:])
    
    # on_update 메서드 제거 - 중복 처리 방지
    # def on_update(self, status):
    #     """새로운 상태 업데이트 수신 시 호출 (타임라인)"""
    #     # 멘션된 경우만 처리
    #     if self.bot.is_mentioned(status):
    #         self.bot.handle_mention(status)

class MastodonBot:
    def __init__(self, access_token, api_base_url, google_sheets_manager, 
                 keywords_sheet, acquisition_sheet, gacha_sheet=None, store_sheet=None):
        self.access_token = access_token
        self.api_base_url = api_base_url
        self.google_sheets = google_sheets_manager
        self.keywords_sheet = keywords_sheet
        self.acquisition_sheet = acquisition_sheet
        self.gacha_sheet = gacha_sheet or "가챠"
        self.store_sheet = store_sheet or "상점"
        
        # 가챠 시스템 초기화
        self.gacha_system = GachaSystem()
        
        # 스케줄러 초기화
        self.scheduler = BotScheduler(self)
        
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
            
            print(f"멘션 수신 - @{user}: {clean_content} (ID: {status_id})")
            
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
            
            # 상점 키워드 확인
            if '상점' in keywords_text.lower():
                self.handle_store(user, status_id)
                return
            
            # 구매 키워드 확인
            if keywords_text.lower().startswith('구매'):
                self.handle_purchase(user, status_id, keywords_text)
                return
            
            # 출석 키워드 확인
            if '출석' in keywords_text.lower():
                self.handle_attendance(user, status_id)
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
            user_currency = self.google_sheets.get_user_currency(sheet_username)
            
            if not inventory:
                response = f"소지품이 비어있습니다.\n💰 갈레온: {user_currency}"
            else:
                # 갈레온을 제외한 아이템들만 표시
                items_without_currency = [item for item in inventory if item['item'] != '갈레온']
                
                response = f"🎒 소지품 목록 ({len(items_without_currency)}개):\n"
                for i, item_data in enumerate(items_without_currency[:10]):  # 최대 10개까지 표시
                    item = item_data['item']
                    quantity = item_data['quantity']
                    if quantity > 1:
                        response += f"• {item} x{quantity}\n"
                    else:
                        response += f"• {item}\n"
                
                if len(items_without_currency) > 10:
                    response += f"... 외 {len(items_without_currency) - 10}개\n"
                
                response += f"\n💰 갈레온: {user_currency}"
            
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
            # 유저명을 알파벳 단일 문자로 변환
            sheet_username = username[0].upper() if username else 'A'
            valid_users = [chr(ord('A') + i) for i in range(20)]
            if sheet_username not in valid_users:
                sheet_username = 'A'
            
            # 갈레온 체크 (가챠 비용: 3갈레온)
            current_currency = self.google_sheets.get_user_currency(sheet_username)
            if current_currency < 3:
                reply = f"@{username} 갈레온이 부족합니다! 가챠 이용료는 3갈레온입니다. (보유: {current_currency} 갈레온)"
                self.mastodon.status_post(
                    reply, 
                    in_reply_to_id=status_id,
                    visibility='public'
                )
                return
            
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
            
            # 갈레온 차감
            if not self.google_sheets.update_user_currency(sheet_username, 3, 'subtract'):
                reply = f"@{username} 갈레온 차감 중 오류가 발생했습니다. 다시 시도해주세요."
                self.mastodon.status_post(
                    reply, 
                    in_reply_to_id=status_id,
                    visibility='public'
                )
                return
            
            # 가챠 실행
            selected_item, rarity = self.gacha_system.get_random_item(gacha_items)
            response = self.gacha_system.format_gacha_result(selected_item, rarity)
            
            # 잔액 정보 추가
            new_balance = current_currency - 3
            response += f" (잔액: {new_balance} 갈레온)"
            
            # 응답 전송
            reply = f"@{username} {response}"
            self.mastodon.status_post(
                reply, 
                in_reply_to_id=status_id,
                visibility='public'
            )
            
            print(f"가챠 결과 - {username}: {selected_item} ({rarity}) - 갈레온 3개 차감")
            
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

    def handle_store(self, username, status_id):
        """상점 조회 처리"""
        try:
            # 상점 아이템 조회
            store_items = self.google_sheets.get_store_items(self.store_sheet)
            
            if not store_items:
                response = "상점에 판매 중인 아이템이 없습니다."
            else:
                response = "🏪 상점 아이템 목록:\n\n"
                for item in store_items[:10]:  # 최대 10개까지 표시
                    name = item['name']
                    price = item['price']
                    description = item['description']
                    
                    if description:
                        response += f"• {name} - {price} 갈레온\n  {description}\n\n"
                    else:
                        response += f"• {name} - {price} 갈레온\n"
                
                if len(store_items) > 10:
                    response += f"... 외 {len(store_items) - 10}개"
                
                # 사용자 갈레온 표시
                sheet_username = username[0].upper() if username else 'A'
                valid_users = [chr(ord('A') + i) for i in range(20)]
                if sheet_username in valid_users:
                    user_currency = self.google_sheets.get_user_currency(sheet_username)
                    response += f"\n💰 보유 갈레온: {user_currency}"
                
                response += "\n\n구매하려면 '구매 [아이템명]'을 입력하세요."
            
            # 응답 전송
            reply = f"@{username} {response}"
            self.mastodon.status_post(
                reply, 
                in_reply_to_id=status_id,
                visibility='public'
            )
            
            print(f"상점 조회 - {username}: {len(store_items)}개 아이템")
            
        except Exception as e:
            print(f"상점 조회 중 오류 발생: {e}")
            reply = f"@{username} 상점 조회 중 오류가 발생했습니다. 다시 시도해주세요."
            try:
                self.mastodon.status_post(
                    reply, 
                    in_reply_to_id=status_id,
                    visibility='public'
                )
            except:
                pass

    def handle_purchase(self, username, status_id, keywords_text):
        """아이템 구매 처리"""
        try:
            # '구매' 키워드 제거하고 아이템명 추출
            item_name = keywords_text[2:].strip()  # '구매' 두 글자 제거
            
            if not item_name:
                reply = f"@{username} 구매할 아이템명을 입력해주세요. (예: 구매 검)"
                self.mastodon.status_post(
                    reply, 
                    in_reply_to_id=status_id,
                    visibility='public'
                )
                return
            
            # 유저명을 알파벳 단일 문자로 변환
            sheet_username = username[0].upper() if username else 'A'
            valid_users = [chr(ord('A') + i) for i in range(20)]
            if sheet_username not in valid_users:
                sheet_username = 'A'
            
            # 상점에서 아이템 찾기
            store_items = self.google_sheets.get_store_items(self.store_sheet)
            target_item = None
            
            for item in store_items:
                if item['name'].lower() == item_name.lower():
                    target_item = item
                    break
            
            if not target_item:
                reply = f"@{username} '{item_name}' 아이템을 상점에서 찾을 수 없습니다."
                self.mastodon.status_post(
                    reply, 
                    in_reply_to_id=status_id,
                    visibility='public'
                )
                return
            
            # 구매 처리
            success, message = self.google_sheets.purchase_item(
                sheet_username, 
                target_item['name'], 
                target_item['price']
            )
            
            if success:
                # 구매 성공시 획득 로그에도 기록
                self.log_acquisition(username, f"{target_item['name']} 구매")
            
            # 응답 전송
            reply = f"@{username} {message}"
            self.mastodon.status_post(
                reply, 
                in_reply_to_id=status_id,
                visibility='public'
            )
            
            print(f"구매 시도 - {username} ({sheet_username}): {item_name} - {'성공' if success else '실패'}")
            
        except Exception as e:
            print(f"구매 처리 중 오류 발생: {e}")
            reply = f"@{username} 구매 처리 중 오류가 발생했습니다. 다시 시도해주세요."
            try:
                self.mastodon.status_post(
                    reply, 
                    in_reply_to_id=status_id,
                    visibility='public'
                )
            except:
                pass

    def handle_attendance(self, username, status_id):
        """출석 체크 처리"""
        try:
            # 출석 체크 활성화 상태 확인
            if not self.scheduler.is_attendance_active():
                reply = f"@{username} 현재 출석 체크 시간이 아닙니다. 출석 체크는 매일 오전 7시부터 자정까지입니다."
                self.mastodon.status_post(
                    reply, 
                    in_reply_to_id=status_id,
                    visibility='public'
                )
                return
            
            # 유저명을 알파벳 단일 문자로 변환
            sheet_username = username[0].upper() if username else 'A'
            valid_users = [chr(ord('A') + i) for i in range(20)]
            if sheet_username not in valid_users:
                sheet_username = 'A'
            
            # 갈레온 6개 지급
            if self.google_sheets.update_user_currency(sheet_username, 6, 'add'):
                current_currency = self.google_sheets.get_user_currency(sheet_username)
                reply = f"@{username} 출석 체크 완료! 갈레온 6개를 지급했습니다. (보유: {current_currency} 갈레온)"
                
                # 출석 로그 기록
                self.log_acquisition(username, "출석 체크 (갈레온 6개)")
                
                print(f"출석 체크 - {username} ({sheet_username}): 갈레온 6개 지급")
            else:
                reply = f"@{username} 출석 체크 처리 중 오류가 발생했습니다. 다시 시도해주세요."
            
            # 응답 전송
            self.mastodon.status_post(
                reply, 
                in_reply_to_id=status_id,
                visibility='public'
            )
            
        except Exception as e:
            print(f"출석 체크 처리 중 오류 발생: {e}")
            reply = f"@{username} 출석 체크 처리 중 오류가 발생했습니다. 다시 시도해주세요."
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
            
            # 스케줄러 시작
            self.scheduler.start()
            
            listener = MastodonBotListener(self)
            
            # 사용자 스트림 시작 (멘션 및 알림 수신)
            self.mastodon.stream_user(listener, run_async=False)
            
        except Exception as e:
            print(f"스트리밍 중 오류 발생: {e}")
            time.sleep(5)
            self.start_streaming()  # 재시작
        finally:
            # 스케줄러 중지
            if hasattr(self, 'scheduler'):
                self.scheduler.stop()
    
    def post_status(self, message, visibility='public'):
        """상태 게시"""
        try:
            self.mastodon.status_post(message, visibility=visibility)
            print(f"상태 게시: {message}")
        except Exception as e:
            print(f"상태 게시 중 오류: {e}")
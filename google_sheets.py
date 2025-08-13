import os
from datetime import datetime
from google.auth.transport.requests import Request
from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build
import pandas as pd

class GoogleSheetsManager:
    def __init__(self, service_account_file, spreadsheet_id):
        self.service_account_file = service_account_file
        self.spreadsheet_id = spreadsheet_id
        self.service = self._authenticate()
    
    def _authenticate(self):
        """구글 시트 API 인증"""
        scopes = ['https://www.googleapis.com/auth/spreadsheets']
        creds = Credentials.from_service_account_file(
            self.service_account_file, scopes=scopes
        )
        return build('sheets', 'v4', credentials=creds)
    
    def get_keywords_data(self, sheet_name):
        """키워드 데이터를 가져옴"""
        try:
            sheet = self.service.spreadsheets()
            result = sheet.values().get(
                spreadsheetId=self.spreadsheet_id,
                range=f'{sheet_name}!A:B'
            ).execute()
            
            values = result.get('values', [])
            if not values:
                return {}
            
            # 첫 번째 행은 헤더로 가정하고 스킵
            keywords_dict = {}
            for row in values[1:]:
                if len(row) >= 2:
                    keyword = row[0].strip()
                    response = row[1].strip()
                    keywords_dict[keyword] = response
            
            return keywords_dict
            
        except Exception as e:
            print(f"키워드 데이터를 가져오는 중 오류 발생: {e}")
            return {}
    
    def log_acquisition(self, sheet_name, username, item, timestamp=None):
        """획득 로그를 기록"""
        try:
            if timestamp is None:
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            sheet = self.service.spreadsheets()
            
            # 새로운 행을 추가
            values = [[timestamp, username, item]]
            body = {'values': values}
            
            result = sheet.values().append(
                spreadsheetId=self.spreadsheet_id,
                range=f'{sheet_name}!A:C',
                valueInputOption='RAW',
                body=body
            ).execute()
            
            print(f"획득 로그 기록 완료: {username} - {item}")
            return True
            
        except Exception as e:
            print(f"획득 로그 기록 중 오류 발생: {e}")
            return False
    
    def get_gacha_items(self, sheet_name):
        """가챠 시트에서 아이템 목록을 가져옴"""
        try:
            sheet = self.service.spreadsheets()
            result = sheet.values().get(
                spreadsheetId=self.spreadsheet_id,
                range=f'{sheet_name}!A:A'
            ).execute()
            
            values = result.get('values', [])
            if not values:
                return []
            
            # A열의 모든 값을 리스트로 반환 (빈 셀 제외)
            items = []
            for row in values:
                if row and row[0].strip():  # 빈 값이 아닌 경우만
                    items.append(row[0].strip())
            
            return items
            
        except Exception as e:
            print(f"가챠 아이템 데이터를 가져오는 중 오류 발생: {e}")
            return []
    
    def setup_acquisition_log_sheet(self, sheet_name):
        """획득 로그 시트에 헤더 설정"""
        try:
            sheet = self.service.spreadsheets()
            
            # 헤더 확인
            result = sheet.values().get(
                spreadsheetId=self.spreadsheet_id,
                range=f'{sheet_name}!A1:C1'
            ).execute()
            
            values = result.get('values', [])
            if not values or len(values[0]) < 3:
                # 헤더 추가
                headers = [['시간', '사용자', '획득 아이템']]
                body = {'values': headers}
                
                sheet.values().update(
                    spreadsheetId=self.spreadsheet_id,
                    range=f'{sheet_name}!A1:C1',
                    valueInputOption='RAW',
                    body=body
                ).execute()
                
                print("획득 로그 시트 헤더 설정 완료")
            
        except Exception as e:
            print(f"획득 로그 시트 설정 중 오류 발생: {e}")
    
    def create_user_inventory_sheet(self, username):
        """개별 유저 소지품 시트 생성"""
        try:
            sheet = self.service.spreadsheets()
            
            # 시트 존재 확인
            spreadsheet = sheet.get(spreadsheetId=self.spreadsheet_id).execute()
            sheet_names = [s['properties']['title'] for s in spreadsheet['sheets']]
            
            if username not in sheet_names:
                # 새 시트 생성
                request_body = {
                    'requests': [{
                        'addSheet': {
                            'properties': {
                                'title': username
                            }
                        }
                    }]
                }
                
                sheet.batchUpdate(
                    spreadsheetId=self.spreadsheet_id,
                    body=request_body
                ).execute()
                
                # 헤더 설정
                headers = [['아이템', '획득 날짜', '수량']]
                body = {'values': headers}
                
                sheet.values().update(
                    spreadsheetId=self.spreadsheet_id,
                    range=f'{username}!A1:C1',
                    valueInputOption='RAW',
                    body=body
                ).execute()
                
                print(f"{username} 소지품 시트 생성 완료")
                return True
            else:
                print(f"{username} 소지품 시트 이미 존재")
                return True
                
        except Exception as e:
            print(f"{username} 소지품 시트 생성 중 오류 발생: {e}")
            return False
    
    def add_item_to_user_inventory(self, username, item, timestamp=None, quantity=1):
        """유저 소지품 시트에 아이템 추가"""
        try:
            if timestamp is None:
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            # 시트가 없으면 생성
            self.create_user_inventory_sheet(username)
            
            sheet = self.service.spreadsheets()
            
            # 기존 아이템 확인
            result = sheet.values().get(
                spreadsheetId=self.spreadsheet_id,
                range=f'{username}!A:C'
            ).execute()
            
            values = result.get('values', [])
            updated = False
            
            # 기존 아이템이 있는지 확인하고 수량 업데이트
            for i, row in enumerate(values[1:], start=2):  # 헤더 제외
                if len(row) > 0 and row[0] == item:
                    current_quantity = int(row[2]) if len(row) > 2 and row[2].isdigit() else 1
                    new_quantity = current_quantity + quantity
                    
                    # 수량 업데이트
                    update_values = [[item, timestamp, new_quantity]]
                    body = {'values': update_values}
                    
                    sheet.values().update(
                        spreadsheetId=self.spreadsheet_id,
                        range=f'{username}!A{i}:C{i}',
                        valueInputOption='RAW',
                        body=body
                    ).execute()
                    
                    updated = True
                    break
            
            # 새 아이템 추가
            if not updated:
                new_values = [[item, timestamp, quantity]]
                body = {'values': new_values}
                
                sheet.values().append(
                    spreadsheetId=self.spreadsheet_id,
                    range=f'{username}!A:C',
                    valueInputOption='RAW',
                    body=body
                ).execute()
            
            print(f"{username} 소지품에 {item} 추가 완료 (수량: {quantity})")
            return True
            
        except Exception as e:
            print(f"{username} 소지품 추가 중 오류 발생: {e}")
            return False
    
    def get_user_inventory(self, username):
        """유저 소지품 조회"""
        try:
            sheet = self.service.spreadsheets()
            result = sheet.values().get(
                spreadsheetId=self.spreadsheet_id,
                range=f'{username}!A:C'
            ).execute()
            
            values = result.get('values', [])
            if not values or len(values) <= 1:  # 헤더만 있거나 비어있음
                return []
            
            inventory = []
            for row in values[1:]:  # 헤더 제외
                if len(row) >= 3:
                    item = row[0]
                    date = row[1]
                    quantity = int(row[2]) if row[2].isdigit() else 1
                    inventory.append({'item': item, 'date': date, 'quantity': quantity})
                elif len(row) >= 1:  # 최소한 아이템명만 있는 경우
                    inventory.append({'item': row[0], 'date': '', 'quantity': 1})
            
            return inventory
            
        except Exception as e:
            print(f"{username} 소지품 조회 중 오류 발생: {e}")
            return []
    
    def sync_acquisitions_to_inventories(self, acquisition_sheet):
        """획득 로그에서 각 유저 소지품으로 동기화"""
        try:
            sheet = self.service.spreadsheets()
            result = sheet.values().get(
                spreadsheetId=self.spreadsheet_id,
                range=f'{acquisition_sheet}!A:C'
            ).execute()
            
            values = result.get('values', [])
            if not values or len(values) <= 1:
                print("동기화할 획득 로그가 없습니다.")
                return
            
            # 임시 유저 목록 (A~T, 20명)
            valid_users = [chr(ord('A') + i) for i in range(20)]  # A, B, C, ..., T
            
            sync_count = 0
            for row in values[1:]:  # 헤더 제외
                if len(row) >= 3:
                    timestamp = row[0]
                    username = row[1]
                    item = row[2]
                    
                    # 유효한 유저인지 확인 (알파벳 단일 문자)
                    if username in valid_users:
                        if self.add_item_to_user_inventory(username, item, timestamp):
                            sync_count += 1
            
            print(f"총 {sync_count}개 항목 동기화 완료")
            return True
            
        except Exception as e:
            print(f"획득 로그 동기화 중 오류 발생: {e}")
            return False
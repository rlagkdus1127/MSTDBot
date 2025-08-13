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
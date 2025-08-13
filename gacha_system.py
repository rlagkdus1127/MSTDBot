import random
from typing import Dict, List, Tuple

class GachaSystem:
    def __init__(self):
        # 확률 등급 정의 (확률, 시작 줄, 끝 줄)
        self.rarity_tiers = [
            (1.0, 1, 5),    # 1% - SSR (1-5줄)
            (5.0, 6, 15),   # 5% - SR (6-15줄)  
            (15.0, 16, 30), # 15% - R (16-30줄)
            (79.0, 31, 50)  # 79% - N (31-50줄)
        ]
        
    def get_random_item(self, gacha_items: List[str]) -> Tuple[str, str]:
        """
        확률에 따라 랜덤 아이템 선택
        
        Args:
            gacha_items: 가챠 시트의 아이템 리스트 (인덱스 0부터 시작)
            
        Returns:
            (선택된_아이템, 등급명) 튜플
        """
        # 랜덤 확률 생성 (0-100)
        roll = random.uniform(0, 100)
        
        # 확률에 따른 등급 결정
        cumulative_prob = 0
        selected_tier = None
        rarity_name = ""
        
        for prob, start_line, end_line in self.rarity_tiers:
            cumulative_prob += prob
            if roll <= cumulative_prob:
                selected_tier = (start_line, end_line)
                if prob == 1.0:
                    rarity_name = "SSR"
                elif prob == 5.0:
                    rarity_name = "SR" 
                elif prob == 15.0:
                    rarity_name = "R"
                else:
                    rarity_name = "N"
                break
        
        if not selected_tier:
            # 기본값 (최하위 등급)
            selected_tier = (31, 50)
            rarity_name = "N"
        
        start_idx, end_idx = selected_tier
        # 1-based line number를 0-based index로 변환
        start_idx -= 1
        end_idx -= 1
        
        # 해당 등급 범위에서 랜덤 선택
        available_items = gacha_items[start_idx:end_idx + 1]
        
        if not available_items:
            # 범위에 아이템이 없으면 전체에서 랜덤 선택
            if gacha_items:
                selected_item = random.choice(gacha_items)
            else:
                selected_item = "기본 아이템"
        else:
            selected_item = random.choice(available_items)
        
        return selected_item, rarity_name
    
    def format_gacha_result(self, item: str, rarity: str) -> str:
        """
        가챠 결과를 포맷팅
        
        Args:
            item: 선택된 아이템
            rarity: 등급
            
        Returns:
            포맷된 결과 문자열
        """
        # 등급별 이모지
        rarity_emojis = {
            "SSR": "✨🌟",
            "SR": "⭐",
            "R": "💫",
            "N": "⚪"
        }
        
        emoji = rarity_emojis.get(rarity, "⚪")
        
        return f"{emoji} [{rarity}] {item}를 획득했습니다!"
    
    def get_rarity_info(self) -> str:
        """
        확률 정보를 문자열로 반환
        """
        return (
            "📊 가챠 확률 정보:\n"
            "✨ SSR (1%): 1-5번 아이템\n"
            "⭐ SR (5%): 6-15번 아이템\n"
            "💫 R (15%): 16-30번 아이템\n"
            "⚪ N (79%): 31-50번 아이템"
        )
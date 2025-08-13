#!/usr/bin/env python3
"""
마스토돈 봇 헬스체크 스크립트

이 스크립트는 봇의 상태를 종합적으로 모니터링합니다:
- 서비스 상태
- 메모리/CPU 사용량  
- 구글 스프레드시트 연결 상태
- 마스토돈 API 연결 상태
- 로그 파일 분석
"""

import os
import sys
import json
import time
import psutil
import subprocess
import requests
from datetime import datetime, timedelta
from pathlib import Path
import logging

class HealthChecker:
    def __init__(self, config_file=None):
        self.bot_dir = Path("/home/botuser/mastodon-bot")
        self.service_name = "mastodon-bot"
        self.config_file = config_file or self.bot_dir / "scripts" / "monitoring" / "health_config.json"
        
        self.setup_logging()
        self.load_config()
        
    def setup_logging(self):
        """로깅 설정"""
        log_dir = self.bot_dir / "logs"
        log_dir.mkdir(exist_ok=True)
        
        log_file = log_dir / "health_check.log"
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
        
    def load_config(self):
        """설정 로드"""
        default_config = {
            "memory_threshold": 80,  # 메모리 사용률 임계값 (%)
            "cpu_threshold": 90,     # CPU 사용률 임계값 (%)
            "disk_threshold": 85,    # 디스크 사용률 임계값 (%)
            "log_check_minutes": 30, # 로그 확인 시간 범위 (분)
            "alert_webhook": None,   # 웹훅 URL (선택사항)
            "check_interval": 300    # 체크 간격 (초)
        }
        
        if self.config_file.exists():
            try:
                with open(self.config_file, 'r') as f:
                    user_config = json.load(f)
                    default_config.update(user_config)
            except Exception as e:
                self.logger.warning(f"설정 파일 로드 실패, 기본값 사용: {e}")
        
        self.config = default_config
        
    def check_service_status(self):
        """서비스 상태 확인"""
        try:
            result = subprocess.run(
                ["systemctl", "is-active", self.service_name],
                capture_output=True, text=True
            )
            
            is_active = result.returncode == 0
            status = result.stdout.strip() if result.stdout else "unknown"
            
            # 서비스 정보 추가 수집
            if is_active:
                # 메인 PID 확인
                pid_result = subprocess.run(
                    ["systemctl", "show", "-p", "MainPID", self.service_name],
                    capture_output=True, text=True
                )
                main_pid = None
                if pid_result.returncode == 0:
                    for line in pid_result.stdout.split('\n'):
                        if line.startswith('MainPID='):
                            try:
                                main_pid = int(line.split('=')[1])
                                if main_pid == 0:
                                    main_pid = None
                            except:
                                pass
                            break
            else:
                main_pid = None
                
            return {
                "active": is_active,
                "status": status,
                "main_pid": main_pid
            }
            
        except Exception as e:
            self.logger.error(f"서비스 상태 확인 실패: {e}")
            return {"active": False, "status": "error", "main_pid": None}
    
    def check_system_resources(self):
        """시스템 리소스 확인"""
        try:
            # 메모리 사용량
            memory = psutil.virtual_memory()
            memory_percent = memory.percent
            
            # CPU 사용량 (1초간 측정)
            cpu_percent = psutil.cpu_percent(interval=1)
            
            # 디스크 사용량
            disk = psutil.disk_usage('/')
            disk_percent = (disk.used / disk.total) * 100
            
            # 봇 프로세스별 리소스 확인
            bot_processes = []
            for proc in psutil.process_iter(['pid', 'name', 'memory_percent', 'cpu_percent']):
                try:
                    if 'python' in proc.info['name'].lower():
                        cmdline = proc.cmdline()
                        if any('mastodon-bot' in arg for arg in cmdline):
                            bot_processes.append({
                                "pid": proc.info['pid'],
                                "memory_percent": proc.info['memory_percent'],
                                "cpu_percent": proc.info['cpu_percent']
                            })
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue
            
            return {
                "memory_percent": memory_percent,
                "cpu_percent": cpu_percent, 
                "disk_percent": disk_percent,
                "bot_processes": bot_processes,
                "memory_warning": memory_percent > self.config["memory_threshold"],
                "cpu_warning": cpu_percent > self.config["cpu_threshold"],
                "disk_warning": disk_percent > self.config["disk_threshold"]
            }
            
        except Exception as e:
            self.logger.error(f"시스템 리소스 확인 실패: {e}")
            return None
    
    def check_log_errors(self):
        """로그 파일에서 최근 에러 확인"""
        try:
            # systemd 로그 확인
            since_time = datetime.now() - timedelta(minutes=self.config["log_check_minutes"])
            since_str = since_time.strftime('%Y-%m-%d %H:%M:%S')
            
            result = subprocess.run([
                "journalctl", "-u", self.service_name,
                "--since", since_str,
                "--no-pager", "-q"
            ], capture_output=True, text=True)
            
            if result.returncode != 0:
                return {"error": "로그 조회 실패"}
            
            log_lines = result.stdout.split('\n')
            
            # 에러 패턴 분석
            error_patterns = ['ERROR', 'CRITICAL', 'Exception', 'Traceback', 'Failed']
            warning_patterns = ['WARNING', 'WARN']
            
            error_count = 0
            warning_count = 0
            recent_errors = []
            
            for line in log_lines:
                if any(pattern in line for pattern in error_patterns):
                    error_count += 1
                    if len(recent_errors) < 5:  # 최근 5개 에러만 저장
                        recent_errors.append(line.strip())
                elif any(pattern in line for pattern in warning_patterns):
                    warning_count += 1
            
            return {
                "error_count": error_count,
                "warning_count": warning_count,
                "recent_errors": recent_errors,
                "total_log_lines": len([l for l in log_lines if l.strip()])
            }
            
        except Exception as e:
            self.logger.error(f"로그 에러 확인 실패: {e}")
            return {"error": str(e)}
    
    def check_network_connectivity(self):
        """네트워크 연결 상태 확인"""
        results = {}
        
        # 구글 스프레드시트 API 연결 테스트
        try:
            response = requests.get(
                "https://sheets.googleapis.com/v4/spreadsheets",
                timeout=10
            )
            results["google_sheets_api"] = {
                "reachable": True,
                "status_code": response.status_code,
                "response_time": response.elapsed.total_seconds()
            }
        except Exception as e:
            results["google_sheets_api"] = {
                "reachable": False,
                "error": str(e)
            }
        
        # 일반적인 인터넷 연결 테스트
        try:
            response = requests.get("https://www.google.com", timeout=5)
            results["internet"] = {
                "reachable": True,
                "response_time": response.elapsed.total_seconds()
            }
        except Exception as e:
            results["internet"] = {
                "reachable": False,
                "error": str(e)
            }
        
        return results
    
    def generate_health_report(self):
        """종합 헬스 리포트 생성"""
        report = {
            "timestamp": datetime.now().isoformat(),
            "overall_status": "healthy"  # healthy, warning, critical
        }
        
        # 서비스 상태
        service_status = self.check_service_status()
        report["service"] = service_status
        
        if not service_status["active"]:
            report["overall_status"] = "critical"
        
        # 시스템 리소스
        resources = self.check_system_resources()
        if resources:
            report["resources"] = resources
            
            if any([resources["memory_warning"], resources["cpu_warning"], resources["disk_warning"]]):
                if report["overall_status"] != "critical":
                    report["overall_status"] = "warning"
        
        # 로그 에러
        log_errors = self.check_log_errors()
        report["logs"] = log_errors
        
        if log_errors and log_errors.get("error_count", 0) > 0:
            if report["overall_status"] == "healthy":
                report["overall_status"] = "warning"
        
        # 네트워크 연결
        network = self.check_network_connectivity()
        report["network"] = network
        
        if not network.get("internet", {}).get("reachable", False):
            report["overall_status"] = "critical"
        
        return report
    
    def send_alert(self, report):
        """알림 발송"""
        if not self.config.get("alert_webhook"):
            return
        
        if report["overall_status"] in ["warning", "critical"]:
            try:
                webhook_data = {
                    "text": f"🚨 마스토돈 봇 상태: {report['overall_status'].upper()}",
                    "attachments": [{
                        "color": "danger" if report["overall_status"] == "critical" else "warning",
                        "fields": [
                            {
                                "title": "서비스 상태",
                                "value": "🔴 비활성" if not report["service"]["active"] else "🟢 활성",
                                "short": True
                            },
                            {
                                "title": "시간",
                                "value": report["timestamp"],
                                "short": True
                            }
                        ]
                    }]
                }
                
                requests.post(self.config["alert_webhook"], json=webhook_data, timeout=10)
                self.logger.info("알림 발송 완료")
                
            except Exception as e:
                self.logger.error(f"알림 발송 실패: {e}")
    
    def save_report(self, report):
        """리포트 파일 저장"""
        report_dir = self.bot_dir / "logs" / "health_reports"
        report_dir.mkdir(exist_ok=True)
        
        # 날짜별 리포트 파일
        today = datetime.now().strftime("%Y%m%d")
        report_file = report_dir / f"health_report_{today}.jsonl"
        
        try:
            with open(report_file, 'a') as f:
                f.write(json.dumps(report, ensure_ascii=False) + '\n')
        except Exception as e:
            self.logger.error(f"리포트 저장 실패: {e}")
    
    def run_check(self):
        """헬스체크 실행"""
        self.logger.info("헬스체크 시작")
        
        report = self.generate_health_report()
        
        # 결과 출력
        print(f"\n=== 마스토돈 봇 헬스체크 - {report['timestamp']} ===")
        print(f"전체 상태: {report['overall_status'].upper()}")
        
        # 서비스 상태
        service = report['service']
        status_emoji = "🟢" if service['active'] else "🔴"
        print(f"서비스: {status_emoji} {service['status']}")
        if service['main_pid']:
            print(f"  PID: {service['main_pid']}")
        
        # 리소스 상태
        if 'resources' in report:
            res = report['resources']
            print(f"메모리: {res['memory_percent']:.1f}% {'⚠️' if res['memory_warning'] else '✅'}")
            print(f"CPU: {res['cpu_percent']:.1f}% {'⚠️' if res['cpu_warning'] else '✅'}")
            print(f"디스크: {res['disk_percent']:.1f}% {'⚠️' if res['disk_warning'] else '✅'}")
            
            if res['bot_processes']:
                print("봇 프로세스:")
                for proc in res['bot_processes']:
                    print(f"  PID {proc['pid']}: 메모리 {proc['memory_percent']:.1f}%, CPU {proc['cpu_percent']:.1f}%")
        
        # 로그 상태
        if 'logs' in report and 'error_count' in report['logs']:
            logs = report['logs']
            print(f"로그 에러: {logs['error_count']}개, 경고: {logs['warning_count']}개")
            if logs['recent_errors']:
                print("최근 에러:")
                for error in logs['recent_errors'][:3]:
                    print(f"  - {error[:100]}...")
        
        # 네트워크 상태
        if 'network' in report:
            net = report['network']
            internet_status = "🟢" if net.get('internet', {}).get('reachable') else "🔴"
            sheets_status = "🟢" if net.get('google_sheets_api', {}).get('reachable') else "🔴"
            print(f"인터넷 연결: {internet_status}")
            print(f"구글 시트 API: {sheets_status}")
        
        print("=" * 50)
        
        # 알림 및 저장
        self.send_alert(report)
        self.save_report(report)
        
        self.logger.info(f"헬스체크 완료 - 상태: {report['overall_status']}")
        
        return report

def main():
    """메인 함수"""
    checker = HealthChecker()
    
    if len(sys.argv) > 1:
        if sys.argv[1] == "--daemon":
            # 데몬 모드 (연속 모니터링)
            print("데몬 모드로 시작합니다...")
            try:
                while True:
                    checker.run_check()
                    time.sleep(checker.config["check_interval"])
            except KeyboardInterrupt:
                print("\n모니터링 중단됨")
        elif sys.argv[1] == "--json":
            # JSON 출력 모드
            report = checker.generate_health_report()
            print(json.dumps(report, indent=2, ensure_ascii=False))
        else:
            print("사용법: python health_check.py [--daemon|--json]")
    else:
        # 단일 체크 모드
        checker.run_check()

if __name__ == "__main__":
    main()
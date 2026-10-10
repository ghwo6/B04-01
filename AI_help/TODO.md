# 📋 미션 TODO 리스트: 컴퓨터가 알아서 자기 상태를 점검하게 만들기

> **미션 목표**: 다중 사용자 리눅스 환경에서 보안 설정(SSH, 방화벽), 계정/권한 체계(그룹, ACL), 환경변수 기반 애플리케이션 구동, 그리고 시스템 리소스 관제 및 로그 자동화 스크립트(`monitor.sh`)를 구현하고 cron으로 주기 실행하기.

---

## 📌 제출 산출물 확인
- [ ] **1. 요구사항 수행 내역서 (문서 1개)**: 각 단계별 설정/명령어 기록 및 필수 증거 자료 캡처/내역
- [ ] **2. 자동화 스크립트 소스코드**: `monitor.sh` (Bash로 작성)
- [ ] *(선택)* **보너스 스크립트**: `report.sh` (통계 리포트 및 로그 보존 정책)

---

## 🗺️ 전체 진행 단계 (Roadmap)

```
[Phase 0] 환경 준비 
   ⬇
[Phase 1] 기본 보안 및 네트워크 설정 (SSH, 방화벽)
   ⬇
[Phase 2] 계정/그룹/권한 및 디렉토리 구조 구축 (최소 권한, ACL)
   ⬇
[Phase 3] 앱 실행 환경 구성 및 정상 동작 확인 (부트 시퀀스 5단계 OK)
   ⬇
[Phase 4] 관제 자동화 스크립트(monitor.sh) 개발
   ⬇
[Phase 5] cron 자동 실행 등록 및 로그 누적 검증
   ⬇
[Phase 6] (선택) 보너스 과제 구현 (report.sh, 로그 아카이빙)
   ⬇
[Phase 7] 필수 증빙 자료 수집 및 보고서 작성
```

---

## ✅ 상세 TODO 리스트

### Phase 0. 사전 준비 및 환경 점검
- [ ] **개발 환경 확인**: Ubuntu 22.04 LTS (또는 동등 Linux 환경, 컨테이너/VM) 접속
- [ ] **제공 파일 확인**: `agent-app.zip` (x86 또는 arm64 아키텍처에 맞게 준비)
- [ ] 필수 패키지 설치 여부 확인 (`acl`, `ufw` 또는 `firewalld`, `cron`, `net-tools` 또는 `iproute2` 등)

---

### Phase 1. 기본 보안 및 네트워크 설정
- [ ] **SSH 설정 변경 (`/etc/ssh/sshd_config` 또는 `sshd_config.d/`)**
  - [ ] 접속 포트를 `20022`로 변경 (`Port 20022`)
  - [ ] Root 원격 로그인 차단 (`PermitRootLogin no`)
  - [ ] SSH 데몬 재시작 (`sudo systemctl restart ssh` 또는 `sshd`)
  - [ ] [증빙 1] `sshd_config` 파일 설정 내용 확인
  - [ ] [증빙 2] 포트 리슨 상태 확인 (`ss -tulnp | grep 20022` 또는 `netstat`)
- [ ] **방화벽 설정 (UFW 또는 firewalld 중 택1)**
  - [ ] 방화벽 기본 정책 설정 (기본 차단)
  - [ ] TCP `20022` (SSH) 허용
  - [ ] TCP `15034` (APP) 허용
  - [ ] 방화벽 활성화
  - [ ] [증빙 3] 방화벽 규칙 확인 (`sudo ufw status verbose` 또는 `sudo firewall-cmd --list-all`)

---

### Phase 2. 계정 / 그룹 / 권한 체계 구축 (협업 + 최소 권한)
- [ ] **그룹 생성**
  - [ ] `agent-common` 생성
  - [ ] `agent-core` 생성
- [ ] **계정 생성 및 그룹 배속**
  - [ ] `agent-admin` 생성 (소속: `agent-common`, `agent-core`)
  - [ ] `agent-dev` 생성 (소속: `agent-common`, `agent-core`)
  - [ ] `agent-test` 생성 (소속: `agent-common` 만 포함)
  - [ ] [증빙 4] 각 계정의 소속 그룹 확인 (`id agent-admin`, `id agent-dev`, `id agent-test`)
- [ ] **디렉토리 구조 생성 (AGENT_HOME 기준: 예 `/home/agent-admin/agent-app`)**
  - [ ] `$AGENT_HOME` 디렉토리 생성
  - [ ] `$AGENT_HOME/upload_files` 디렉토리 생성
  - [ ] `$AGENT_HOME/api_keys` 디렉토리 생성
  - [ ] `$AGENT_HOME/bin` 디렉토리 생성 (스크립트 위치)
  - [ ] `/var/log/agent-app` 디렉토리 생성
- [ ] **접근 권한 및 ACL 설정**
  - [ ] `upload_files`: 그룹 `agent-common`, R/W 가능 설정 (`chmod 775` 또는 `770`, 필요 시 ACL)
  - [ ] `api_keys`: 그룹 `agent-core` 전용, R/W 가능, 일반 사용자/agent-test 차단 (`chmod 770` 또는 `750`, 소유권 확인)
  - [ ] `/var/log/agent-app`: 그룹 `agent-core` R/W 가능
  - [ ] [증빙 5] 디렉토리 소유권/권한 확인 (`ls -ld`, `getfacl` 등)

---

### Phase 3. 애플리케이션 실행 환경 구성 및 테스트
- [ ] **키 파일 생성**
  - [ ] 경로: `$AGENT_HOME/api_keys/t_secret.key`
  - [ ] 내용: `agent_api_key_test` (1줄)
  - [ ] 권한: `agent-core` 소속만 읽을 수 있도록 제한
- [ ] **환경 변수 구성 (`/etc/environment` 또는 `agent-admin`의 `.bashrc` / 실행 프로필)**
  - [ ] `AGENT_HOME=/home/agent-admin/agent-app` (실제 경로)
  - [ ] `AGENT_PORT=15034`
  - [ ] `AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files`
  - [ ] `AGENT_KEY_PATH=$AGENT_HOME/api_keys/t_secret.key`
  - [ ] `AGENT_LOG_DIR=/var/log/agent-app`
- [ ] **앱 실행 및 부트 검증**
  - [ ] 루트가 아닌 일반 계정(`agent-admin`)으로 앱 실행
  - [ ] [증빙 6] Boot Sequence 5단계 `[OK]` 및 `Agent READY` 출력 캡처
    1. Checking User Account [OK]
    2. Verifying Environment Variables [OK]
    3. Checking Required Files [OK]
    4. Checking Port Availability [OK]
    5. Verifying Log Permission [OK]
  - [ ] [증빙 7] `0.0.0.0:15034` LISTEN 상태 확인 (`ss -tulnp | grep 15034`)

---

### Phase 4. 관제 자동화 스크립트 (`monitor.sh`) 구현
- [ ] **스크립트 기본 위치 및 권한 설정**
  - [ ] 경로: `$AGENT_HOME/bin/monitor.sh`
  - [ ] 소유자: `agent-dev`, 그룹: `agent-core`
  - [ ] 권한: `750` (`rwxr-x---`)
- [ ] **Health Check 로직 (실패 시 즉시 exit 1)**
  - [ ] 대상 프로세스(앱 바이너리 또는 `agent_app.py`) 실행 여부 확인 $\rightarrow$ 미실행 시 `exit 1`
  - [ ] TCP 15034 포트 리슨 상태 확인 $\rightarrow$ 미열림 시 `exit 1`
- [ ] **상태 점검 로직 (종료하지 않고 경고만 출력)**
  - [ ] 방화벽(UFW/firewalld) 상태 점검 $\rightarrow$ 비활성화 시 `[WARNING]` 출력
- [ ] **자원 수집 로직**
  - [ ] CPU 사용률(%) 계산/추출
  - [ ] 메모리 사용률(%) 계산/추출
  - [ ] 디스크 루트 파티션 사용률(`Root partition Used %`) 추출
- [ ] **임계치 초과 경고 (Warning 출력)**
  - [ ] CPU > 20% 이면 `[WARNING]`
  - [ ] MEM > 10% 이면 `[WARNING]`
  - [ ] DISK_USED > 80% 이면 `[WARNING]`
- [ ] **로그 파일 기록**
  - [ ] 저장 경로: `/var/log/agent-app/monitor.log`
  - [ ] 형식: `[YYYY-MM-DD HH:MM:SS] PID:... CPU:..% MEM:..% DISK_USED:..%`
- [ ] **로그 파일 용량 관리 (Rotation)**
  - [ ] 최대 10MB 크기 제한, 최대 10개 파일 보존 유지 (logrotate 등록 또는 쉘 스크립트 내 로직 구현)
- [ ] [증빙 8] `monitor.sh` 수동 실행 결과 콘솔 출력 확인

---

### Phase 5. crontab 자동 실행 등록 및 검증
- [ ] **crontab 등록**
  - [ ] `agent-admin` 계정의 crontab에 등록 (`crontab -e -u agent-admin`)
  - [ ] 주기: 매 1분마다 실행 (`* * * * * $AGENT_HOME/bin/monitor.sh`)
- [ ] **실행 검증**
  - [ ] 1~2분 대기 후 `/var/log/agent-app/monitor.log`에 로그 누적 확인
  - [ ] [증빙 9] `tail -n 10 /var/log/agent-app/monitor.log` 로 자동 누적 확인

---

### Phase 6. (선택) 보너스 과제
- [ ] **보너스 1: `report.sh` 요약 리포트 생성 스크립트**
  - [ ] `monitor.log` 분석하여 CPU/MEM/DISK의 평균, 최대(발생 시각), 최소(발생 시각), 샘플 수 콘솔 출력
  - [ ] (선택 기능) 시작 시간 및 종료 시간을 파라미터로 받아 특정 기간만 필터링 분석
- [ ] **보너스 2: 시간 기반 로그 보존 정책 스크립트**
  - [ ] 7일 경과된 로그 압축 (`/var/log/agent-app/*.log`)
  - [ ] 아카이브 경로로 이동 (`/var/log/monitor/agent-app/archive/`)
  - [ ] 30일 경과된 아카이브 압축 파일(`*.gz`) 자동 삭제
  - [ ] 디렉토리 부재/권한 부족/대상 파일 0개 시 예외 처리 로직 추가

---

### Phase 7. 필수 증거 자료 취합 및 최종 문서 작성
- [ ] 필수 증거 자료 8종 캡처 및 명령어 결과 정리:
  1. SSH 포트(20022) 및 Root 원격 접속 차단 설정 확인
  2. 방화벽 허용 포트(20022, 15034) 활성화 상태
  3. 계정 및 그룹 구성 확인 (`id` 결과)
  4. 디렉토리 구조 및 권한/ACL 설정 상태
  5. 앱 부트 시퀀스 5단계 `[OK]` 및 `Agent READY`
  6. `monitor.sh` 단독 실행 콘솔 결과
  7. `/var/log/agent-app/monitor.log` 누적 기록
  8. crontab 등록 내용 및 1분 단위 누적 증명
- [ ] `요구사항 수행 내역서` 작성 및 최종 점검
- [ ] `monitor.sh` 소스코드 정리 및 주석 보완


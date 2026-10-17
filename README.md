# B04-01 컴퓨터가 알아서 자기 상태를 점검하게 만들기

다중 사용자 리눅스 서버에서 **보안 설정(SSH, 방화벽) → 계정/권한 체계(그룹, ACL) → 환경변수 기반 앱 실행 → 관제 스크립트(`monitor.sh`) → cron 자동 실행**까지 구성한 미션입니다.

> 서버 장애가 났을 때 로그가 없으면 원인 분석은 '감'에 의존하게 된다.
> 그래서 컴퓨터가 **1분마다 스스로 상태를 점검하고 기록**하도록 만든다.

---

## 📁 디렉터리 구조

```
B04-01/
├── README.md          # 이 문서
├── tasks_log.md       # 요구사항 수행 내역서 (단계별 명령어 + 출력 결과)
├── bin/
│   └── monitor.sh     # 시스템 관제 자동화 스크립트 (제출 산출물)
├── evidence/          # 필수 증빙 캡처
├── misc/
│   └── agent-app/     # 제공된 앱 바이너리 (x86 / arm64)
├── pdf/               # 미션 원문
└── AI_help/           # 사전 조사 문서 (TODO, 앱 분석 가이드)
```

## 🖥️ 실행 환경

| 항목 | 값 |
|---|---|
| VM | OrbStack Linux VM (`agent-server`) |
| OS | Ubuntu 22.04 LTS |
| 아키텍처 | x86_64 → `agent-app-linux-x86` 사용 |
| 방화벽 | UFW |

---

## 🛠️ 수행 내용 요약

자세한 명령어와 출력은 [`tasks_log.md`](tasks_log.md)에 있습니다.

### 1. 기본 보안 및 네트워크

| 항목 | 설정 |
|---|---|
| SSH 포트 | `22` → **`20022`** |
| Root 원격 로그인 | **`PermitRootLogin no`** |
| 방화벽 | UFW 활성화, 기본 정책 `deny (incoming)`, **20022/tcp, 15034/tcp만 허용** |

### 2. 계정 / 그룹

| 계정 | 역할 | agent-common | agent-core |
|---|---|:---:|:---:|
| agent-admin | 운영/관리, cron 실행자 | ✅ | ✅ |
| agent-dev | 개발/운영, monitor.sh 작성자 | ✅ | ✅ |
| agent-test | QA/테스트 | ✅ | ❌ |

### 3. 디렉터리 / 권한

`AGENT_HOME=/home/agent-admin/agent-app`

| 경로 | 소유자:그룹 | 권한 | 용도 |
|---|---|---|---|
| `$AGENT_HOME/upload_files` | agent-admin:agent-common | `770` | **공유** 디렉터리 (test 포함 R/W) |
| `$AGENT_HOME/api_keys` | agent-admin:agent-core | `770` | **보안** 디렉터리 (core만 접근) |
| `$AGENT_HOME/api_keys/secret.key` | agent-admin:agent-core | `640` | API 키 |
| `$AGENT_HOME/bin` | agent-dev:agent-core | `750` | 실행 파일/스크립트 |
| `$AGENT_HOME/bin/monitor.sh` | agent-dev:agent-core | `750` | 관제 스크립트 |
| `/var/log/agent-app` | agent-dev:agent-core | `770` + ACL | 로그 (`u:agent-admin:rwx`) |

- `/home/agent-admin`에 `+x`를 부여해 다른 계정이 하위 앱 디렉터리로 **지나갈 수** 있게 했습니다.

### 4. 앱 실행

```bash
export AGENT_HOME=/home/agent-admin/agent-app
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys/
export AGENT_LOG_DIR=/var/log/agent-app

sudo -E -u agent-dev bash -c 'nohup $AGENT_HOME/bin/agent-app > /var/log/agent-app/app.log 2>&1 &'
```

- **일반 계정(agent-dev)**으로 실행 (root 실행 금지)
- Boot Sequence 5단계 모두 `[OK]` → `Agent READY` → `0.0.0.0:15034` LISTEN

### 5. cron 등록

```bash
sudo crontab -e -u agent-admin
# * * * * * /home/agent-admin/agent-app/bin/monitor.sh
```

---

## 📜 monitor.sh

`bin/monitor.sh`는 Bash로 작성된 관제 스크립트입니다.

| 단계 | 내용 | 실패 시 |
|---|---|---|
| Health Check | `agent-app` 프로세스 실행 여부 (`pgrep`) | `exit 1` |
| Health Check | TCP 15034 LISTEN 여부 (`ss`) | `exit 1` |
| 상태 점검 | UFW 활성화 여부 | `[WARNING]`만 출력 |
| 자원 수집 | CPU(`top`), MEM(`free`), 루트 디스크(`df /`) 사용률 | - |
| 임계치 경고 | CPU > 20%, MEM > 10%, DISK > 80% | `[WARNING]` 출력 |
| 로그 기록 | `/var/log/agent-app/monitor.log`에 한 줄 추가 | - |
| 로그 관리 | 10MB 초과 시 `monitor.log.1` ~ `.N`으로 회전 | - |

**로그 포맷**

```
[2026-10-13 21:10:01] PID:3602 CPU:3.4% MEM:2.5% DISK_USED:1%
```

**수동 실행**

```bash
sudo -u agent-admin $AGENT_HOME/bin/monitor.sh
```

---

## 📸 증빙 자료

| PDF 필수 증빙 | 파일 (`evidence/`) |
|---|---|
| SSH 포트 변경 및 Root 원격 접속 차단 | `[증빙 1]_1 ... before.png`, `[증빙 1]_2 ... after.png`, `[증빙 2] 포트 리슨 상태 확인.png` |
| 방화벽 활성화 및 20022/15034만 허용 | `[증빙 3] 방화벽 규칙 확인.png` |
| 계정/그룹 생성 확인 | `[증빙 4] 각 계정의 소속 그룹 확인.png` |
| 디렉터리 구조 및 권한(ACL) | `[증빙 5] 디렉토리 소유권 권한 확인.png`, `monitor.sh 권한 확인.png` |
| Boot Sequence 5단계 `[OK]` + `Agent READY` | `[증빙 6]_1 ... 출력 캡처.png`, `[증빙 6]_2 t_secret.key 실패.png` |
| 15034 LISTEN | `[증빙 7] 15034 LISTEN 상태 확인.png` |
| monitor.sh 실행 결과 | `[증빙 8] monitor.sh 수동 실행 결과 콘솔 출력 확인.png` |
| monitor.log 누적 기록 | `[증빙 9] tail -n 10 ~monitor.log 로 자동 누적 확인.png` |
| crontab 매분 실행 등록 | `cron 등록 내용.png` + 증빙 9 (1분 간격 누적) |

---

## 📝 PDF와 다르게 처리한 부분

| 항목 | PDF | 실제 | 이유 |
|---|---|---|---|
| 키 파일명 | `t_secret.key` | `secret.key` | 제공된 앱이 `secret.key`를 요구함 (`[증빙 6]_2`에 실패 기록) |
| 앱 실행 계정 | 예시는 agent-admin | agent-dev | PDF 요구는 "일반 계정 실행"이며, 앱 소유자인 agent-dev로 실행 |

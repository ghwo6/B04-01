# 📦 agent-app 바이너리 분석 및 OrbStack Linux VM 가이드

## 1. `misc/agent-app` 디렉토리 분석

`misc/agent-app` 폴더 안에는 두 개의 리눅스 실행 파일(ELF 바이너리)이 들어 있습니다:

| 파일명 | 아키텍처 | 설명 |
| :--- | :--- | :--- |
| **`agent-app-linux-arm64`** | **ARM64 (aarch64)** | **Apple Silicon(M1/M2/M3/M4) Mac의 OrbStack Linux VM용 (추천)** |
| **`agent-app-linux-x86`** | **x86_64 (amd64)** | Intel Mac 또는 x86 기반 Linux VM/서버용 |

### 🔍 정체 및 빌드 구조
- **언어 및 런타임**: Python 3.12 기반 애플리케이션
- **패키징 방식**: **PyInstaller**로 패키징된 독립 실행 바이너리 (시스템에 별도의 Python 설치 없이도 단독 실행 가능)
- **용도**: 이 과제에서 개발할 `monitor.sh` 스크립트가 감시(Health Check)하고 모니터링해야 하는 **"서버 대상 애플리케이션"**입니다.

> ⚠️ **주의**: 이 파일들은 리눅스 전용(ELF 64-bit) 바이너리입니다. Mac 호스트 터미널에서 직접 실행하면 `cannot execute binary file` 에러가 발생하므로, 반드시 **OrbStack의 Linux VM 내부**에서 실행해야 합니다.

---

## 2. `agent-app` 동작 방식 및 요구 조건

애플리케이션을 실행하면 **5단계 Boot Sequence**를 거치며 환경이 제대로 갖춰졌는지 자체 점검합니다. 5단계를 모두 통과해야 `Agent READY` 상태가 되고 `15034` 포트에서 대기합니다.

### 5단계 부트 시퀀스 조건
1. **[1/5] Checking User Account**:
   - **루트(root) 계정 실행 불가**. 반드시 일반 계정(과제 요구: `agent-admin` 또는 `agent-dev`)으로 실행되어야 합니다.
2. **[2/5] Verifying Environment Variables**:
   - 아래 필수 환경 변수들이 선언되어 있어야 합니다:
     - `AGENT_HOME` (예: `/home/agent-admin/agent-app`)
     - `AGENT_PORT=15034`
     - `AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files`
     - `AGENT_KEY_PATH=$AGENT_HOME/api_keys/t_secret.key`
     - `AGENT_LOG_DIR=/var/log/agent-app`
3. **[3/5] Checking Required Files**:
   - `$AGENT_KEY_PATH` 파일이 존재해야 하고, 파일 첫 줄에 `agent_api_key_test` 문자열이 저장되어 있어야 합니다.
4. **[4/5] Checking Port Availability**:
   - TCP `15034` 포트가 비어 있어야 하며, 바인딩 가능해야 합니다.
5. **[5/5] Verifying Log Permission**:
   - `$AGENT_LOG_DIR` (`/var/log/agent-app`) 디렉토리에 쓰기 권한이 있어야 합니다.

모두 통과 시:
```
------------------------------------------------------------
All Boot Checks Passed!
Agent READY
```
출력 후 `0.0.0.0:15034` LISTEN 상태로 유지됩니다 (종료는 `Ctrl + C`).

---

## 3. OrbStack Linux VM 환경 세팅 가이드

사용자분 환경이 Mac(Apple Silicon 추정)이므로 OrbStack으로 Ubuntu VM을 띄우는 것이 가장 빠르고 가볍습니다.

### Step 1. OrbStack에서 Ubuntu VM 생성
터미널 또는 OrbStack GUI에서 Ubuntu 머신을 생성합니다.
```bash
# 터미널에서 생성 시 (기본 arm64 Ubuntu 22.04 LTS 생성)
orb create ubuntu:22.04 my-server
```
*(또는 OrbStack 앱 화면에서 `New machine` -> `Ubuntu 22.04` 선택)*

### Step 2. VM 셸 접속 및 아키텍처 확인
```bash
# VM 셸 접속
orb -m my-server

# 아키텍처 확인 (aarch64 출력 시 agent-app-linux-arm64 사용)
uname -m
```

### Step 3. OrbStack VM으로 바이너리 파일 전달
OrbStack은 Mac 호스트의 파일 시스템이 VM 내 `/Users/...` 또는 마운트 경로로 자동 공유되거나, 아래 명령어로 복사할 수 있습니다:
```bash
# 1) OrbStack 공유 경로 바로 접근 (VM 내부에서)
cd /Users/ghwo61351/tasks_ghwo6/B04-01/misc/agent-app

# 또는 2) VM의 타깃 디렉토리로 복사 (Mac 터미널에서)
orb -m my-server push misc/agent-app/agent-app-linux-arm64 /home/agent-admin/agent-app/bin/agent-app
```

---

## 4. VM 내부에서의 필수 사전 세팅 예시

VM 내부에서 `agent-app`을 정상적으로 기동시키기 위한 세팅 명령어 순서입니다.

```bash
# 1. 계정 및 그룹 생성
sudo groupadd agent-common
sudo groupadd agent-core

sudo useradd -m -s /bin/bash -g agent-common -G agent-core agent-admin
sudo useradd -m -s /bin/bash -g agent-common -G agent-core agent-dev
sudo useradd -m -s /bin/bash -g agent-common agent-test

# 2. 디렉토리 구조 생성
AGENT_HOME="/home/agent-admin/agent-app"
sudo mkdir -p $AGENT_HOME/bin
sudo mkdir -p $AGENT_HOME/upload_files
sudo mkdir -p $AGENT_HOME/api_keys
sudo mkdir -p /var/log/agent-app

# 3. 키 파일 생성
echo "agent_api_key_test" | sudo tee $AGENT_HOME/api_keys/t_secret.key

# 4. 바이너리 복사 및 실행 권한 부여
# (Mac에서 복사해 온 agent-app-linux-arm64 파일)
sudo cp /Users/ghwo61351/tasks_ghwo6/B04-01/misc/agent-app/agent-app-linux-arm64 $AGENT_HOME/bin/agent-app
sudo chmod +x $AGENT_HOME/bin/agent-app

# 5. 권한 및 소유권 설정
# upload_files: agent-common 그룹 쓰기 허용
sudo chown -R agent-admin:agent-common $AGENT_HOME/upload_files
sudo chmod 775 $AGENT_HOME/upload_files

# api_keys 및 로그 디렉토리: agent-core 그룹만 R/W 허용
sudo chown -R agent-admin:agent-core $AGENT_HOME/api_keys /var/log/agent-app
sudo chmod 770 $AGENT_HOME/api_keys /var/log/agent-app

# 전체 디렉토리 소유권
sudo chown -R agent-admin:agent-core $AGENT_HOME

# 6. agent-admin 계정으로 전환 후 환경변수 등록 및 실행 테스트
sudo su - agent-admin

cat << 'EOF' >> ~/.bashrc
export AGENT_HOME=/home/agent-admin/agent-app
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys/t_secret.key
export AGENT_LOG_DIR=/var/log/agent-app
EOF

source ~/.bashrc

# 7. 실행 확인
$AGENT_HOME/bin/agent-app
```

---

## 5. `monitor.sh` 작성 시 참고사항
- 프로세스 점검 시: 바이너리 이름이 `agent-app` (또는 `agent-app-linux-arm64`)으로 프로세스 목록(`pgrep`, `ps -ef`)에 나타납니다.
- 포트 점검 시: `ss -tulnp` 또는 `netstat -tulnp`로 `15034` 포트가 `LISTEN`인지 확인합니다.


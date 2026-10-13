#!/bin/bash
# ==========================================
# 기본 환경 변수 및 경로 설정
# ==========================================
AGENT_HOME="/home/agent-admin/agent-app"
LOG_DIR="/var/log/agent-app"
LOG_FILE="${LOG_DIR}/monitor.log"
APP_NAME="agent-app"
PORT=15034
# ==========================================
# 1. Health Check (실패 시 즉시 exit 1)
# ==========================================
# 프로세스 확인 (agent-app 또는 agent_app)
PID=$(pgrep -x "$APP_NAME" | head -n1)
if [ -z "$PID" ]; then
    PID=$(pgrep -f "agent_app" | head -n1)
fi
if [ -z "$PID" ]; then
    echo "====== SYSTEM MONITOR RESULT ======"
    echo "[HEALTH CHECK]"
    echo "Checking process '$APP_NAME'... [FAIL] (Not Running)"
    exit 1
fi
# 포트 15034 리슨 상태 확인
if ! ss -tuln | grep -q ":${PORT}\b"; then
    echo "====== SYSTEM MONITOR RESULT ======"
    echo "[HEALTH CHECK]"
    echo "Checking process '$APP_NAME'... [OK] (PID: $PID)"
    echo "Checking port ${PORT}... [FAIL] (Not Listening)"
    exit 1
fi
# ==========================================
# 2. 방화벽 상태 점검 (비활성 시 경고만 출력, 스크립트 계속 진행)
# ==========================================
FW_WARN=""
# 일반 계정 권한에서도 정확히 감지하도록 ufw.conf 및 systemctl 상태 복합 체크
if [ -f /etc/ufw/ufw.conf ] && grep -qi "^ENABLED=yes" /etc/ufw/ufw.conf; then
    FW_STATUS="ACTIVE"
elif systemctl is-active --quiet ufw; then
    FW_STATUS="ACTIVE"
else
    FW_STATUS="INACTIVE"
    FW_WARN="[WARNING] Firewall is inactive"
fi
# ==========================================
# 3. 자원 수집 (CPU, 메모리, 루트 디스크)
# ==========================================
# CPU 사용률 (%)
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/")
CPU_USED=$(awk "BEGIN {printf \"%.1f\", 100 - $CPU_IDLE}")
CPU_INT=${CPU_USED%.*}
# 메모리 사용률 (%)
MEM_TOTAL=$(free | grep Mem | awk '{print $2}')
MEM_USED_VAL=$(free | grep Mem | awk '{print $3}')
MEM_USED=$(awk "BEGIN {printf \"%.1f\", ($MEM_USED_VAL/$MEM_TOTAL)*100}")
MEM_INT=${MEM_USED%.*}
# 루트 디스크 사용률 (%)
DISK_USED=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
# ==========================================
# 4. 임계치 초과 경고 판정
# ==========================================
RESOURCE_WARN=""
if [ "$CPU_INT" -gt 20 ]; then
    RESOURCE_WARN="${RESOURCE_WARN} [WARNING] CPU threshold exceeded (${CPU_USED}% > 20%)"
fi
if [ "$MEM_INT" -gt 10 ]; then
    RESOURCE_WARN="${RESOURCE_WARN} [WARNING] MEM threshold exceeded (${MEM_USED}% > 10%)"
fi
if [ "$DISK_USED" -gt 80 ]; then
    RESOURCE_WARN="${RESOURCE_WARN} [WARNING] DISK threshold exceeded (${DISK_USED}% > 80%)"
fi
# ==========================================
# 5. 콘솔 화면 출력 (PDF 7페이지 결과 예시 반영)
# ==========================================
echo "====== SYSTEM MONITOR RESULT ======"
echo "[HEALTH CHECK]"
echo "Checking process '$APP_NAME'... [OK] (PID: $PID)"
echo "Checking port ${PORT}... [OK]"
echo ""
echo "[RESOURCE MONITORING]"
echo "CPU Usage : ${CPU_USED}%"
echo "MEM Usage : ${MEM_USED}%"
echo "DISK Used : ${DISK_USED}%"
# 경고 메시지가 있으면 화면에 출력
if [ -n "$FW_WARN" ]; then
    echo "$FW_WARN"
fi
if [ -n "$RESOURCE_WARN" ]; then
    echo "$RESOURCE_WARN"
fi
# ==========================================
# 6. 로그 파일 기록 (PDF 로그 포맷 준수)
# ==========================================
# 로그 디렉토리 존재 확인
if [ -d "$LOG_DIR" ]; then
    ALL_WARNS=""
    [ -n "$FW_WARN" ] && ALL_WARNS="${ALL_WARNS} ${FW_WARN}"
    [ -n "$RESOURCE_WARN" ] && ALL_WARNS="${ALL_WARNS} ${RESOURCE_WARN}"
    
    LOG_LINE="[$(date '+%Y-%m-%d %H:%M:%S')] PID:${PID} CPU:${CPU_USED}% MEM:${MEM_USED}% DISK_USED:${DISK_USED}%${ALL_WARNS}"
    echo "$LOG_LINE" >> "$LOG_FILE"
fi
# ==========================================
# 7. 로그 파일 용량 관리 (10MB 초과 시 최대 10개 회전)
# ==========================================
if [ -f "$LOG_FILE" ]; then
    LOG_SIZE=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    # 10MB = 10485760 bytes
    if [ "$LOG_SIZE" -gt 10485760 ]; then
        for i in {9..1}; do
            [ -f "${LOG_FILE}.$i" ] && mv "${LOG_FILE}.$i" "${LOG_FILE}.$((i+1))"
        done
        mv "$LOG_FILE" "${LOG_FILE}.1"
        touch "$LOG_FILE"
    fi
fi

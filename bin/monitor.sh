#!/bin/bash

AGENT_HOME=/home/agent-admin/agent-app
LOG_DIR=/var/log/agent-app
LOG_FILE=${LOG_DIR}/monitor.log

# 1. 프로세스 및 포트 확인 (미실행 시 exit 1)
if ! pgrep -x "agent-app" > /dev/null; then
    exit 1
fi
PID=$(pgrep -x "agent-app" | head -n1)

if ! ss -tuln | grep -q ":15034"; then
    exit 1
fi

# 2. 자원 수집 로직
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/")
CPU_USED=$(awk "BEGIN {print 100 - $CPU_IDLE}")
CPU_INT=${CPU_USED%.*}

MEM_TOTAL=$(free | grep Mem | awk '{print $2}')
MEM_USED_VAL=$(free | grep Mem | awk '{print $3}')
MEM_USED=$(awk "BEGIN {printf \"%.1f\", ($MEM_USED_VAL/$MEM_TOTAL)*100}")
MEM_INT=${MEM_USED%.*}

DISK_USED=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')

# 3. 임계치 및 방화벽 경고 (Warning)
WARN_MSG=""
if [ "$CPU_INT" -gt 20 ]; then WARN_MSG="${WARN_MSG} [WARNING] CPU > 20%"; fi
if [ "$MEM_INT" -gt 10 ]; then WARN_MSG="${WARN_MSG} [WARNING] MEM > 10%"; fi
if [ "$DISK_USED" -gt 80 ]; then WARN_MSG="${WARN_MSG} [WARNING] DISK_USED > 80%"; fi
if [ "$(systemctl is-active ufw)" != "active" ]; then WARN_MSG="${WARN_MSG} [WARNING] 방화벽 비활성화"; fi

# 4. 로그 파일 기록
LOG_OUTPUT="[$(date '+%Y-%m-%d %H:%M:%S')] PID:$PID CPU:${CPU_USED}% MEM:${MEM_USED}% DISK_USED:${DISK_USED}%${WARN_MSG}"
echo "$LOG_OUTPUT" >> "$LOG_FILE"

# 5. 로그 파일 용량 관리 (Rotation) - 10MB(10485760 bytes) 초과 시 10개 보존
LOG_SIZE=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
if [ "$LOG_SIZE" -gt 10485760 ]; then
    for i in {9..1}; do
        [ -f "${LOG_FILE}.$i" ] && mv "${LOG_FILE}.$i" "${LOG_FILE}.$((i+1))"
    done
    mv "$LOG_FILE" "${LOG_FILE}.1"
    touch "$LOG_FILE"
fi
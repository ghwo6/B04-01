#!/bin/bash

# 1. 환경변수 세팅 (스크립트 단독 실행을 위해 내부에 고정)
export AGENT_HOME=/home/agent-admin/agent-app
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys
export AGENT_LOG_DIR=/var/log/agent-app

# 2. 프로세스 감시 및 백그라운드 실행 로직
# pgrep으로 agent-app이 실행 중인지 찾고, 없으면 if문 실행함
if ! pgrep -x "agent-app" > /dev/null; then
    echo "[$(date)] agent-app이 꺼져있습니다. 백그라운드에서 재시작을 시도합니다."
    # nohup: 터미널을 꺼도 앱이 죽지 않게 보호 / &: 백그라운드로 실행함
    # 로그 화면은 app.log 파일로 밀어 넣는다.
    nohup $AGENT_HOME/bin/agent-app > $AGENT_LOG_DIR/app.log 2>&1 &
else
    echo "[$(date)] agent-app이 정상적으로 실행 중입니다."
fi

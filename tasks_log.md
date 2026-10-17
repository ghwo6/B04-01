### orbstack에서 linux를 선택하여 이름을 agent-server로 설정한후 22.04로 세팅하여 vm을 생성한다.

### (임시) gui환경으로 생성한 vm환경을 클릭하여 (agent-server) terminal환경으로 접속한다.

### cd 명령어를 이용해 /User/~~하여 B04-01로 이동한다.

### 확인해보니 ssh가 깔려있지 않았다.
### 나중에 설치해야하는 ufw 와 acl도 같이 설치한다.
### sudo apt install ufw -y 를 입력해 방화벽을 설치한다.
### getfacl명령어를 쓰기 위해서 getfacl를 설치한다.


```bash
sudo apt update && sudo apt install openssh-server ufw acl -y
```

### sudo vim /etc/ssh/sshd_config에서 #Port 22를 Port 20022로 바꾼다.

```bash
sudo vim /etc/ssh/sshd_config
```

```vim
#Port 22 -> Port 20022
#PermitRootLogin prohibit-password -> PermitRootLogin no 로 바꾼다.

```

### ssh 설정을 적용하기 위해서 sudo systemctl restart ssh를 입력함

```bash
sudo systemctl restart ssh
```

### ssh 포트가 잘 켜져있는지 확인하자

```bash
sudo ss -tulnp | grep 20022

# tcp   LISTEN 0      128                0.0.0.0:20022      0.0.0.0:*    users:(("sshd",pid=3631,fd=3))           
# tcp   LISTEN 0      128                   [::]:20022         [::]:*    users:(("sshd",pid=3631,fd=4))           
# ghwo61351@agent-server:/Users/ghwo61351/tasks_ghwo6/B04-01$ 
```


### 아래처럼 입력하여 방화벽을 작동 시킨다.

```bash
sudo ufw allow 20022/tcp
sudo ufw allow 15034/tcp
sudo ufw enable
```

### 그룹을 추가함

```bash
sudo groupadd agent-common
sudo groupadd agent-core
```

### 사용자 계정을 추가함

```bash
# 1. agent-admin: common과 core 그룹 모두 포함
sudo useradd -m -s /bin/bash -G agent-common,agent-core agent-admin

# 2. agent-dev: common과 core 그룹 모두 포함
sudo useradd -m -s /bin/bash -G agent-common,agent-core agent-dev

# 3. agent-test: common 그룹에만 포함
sudo useradd -m -s /bin/bash -G agent-common agent-test
```

### 잘 입력 됬는지 내역을 확인함

```bash
id agent-admin; id agent-dev; id agent-test

# uid=1000(agent-admin) gid=1002(agent-admin) groups=1002(agent-admin),1000(agent-common),1001(agent-core)
# uid=1001(agent-dev) gid=1003(agent-dev) groups=1003(agent-dev),1000(agent-common),1001(agent-core)
# uid=1002(agent-test) gid=1004(agent-test) groups=1004(agent-test),1000(agent-common)

```

### 디렉터리 구조 생성

```bash
export AGENT_HOME=/home/agent-admin/agent-app

sudo mkdir -p $AGENT_HOME/upload_files
sudo mkdir -p $AGENT_HOME/api_keys
sudo mkdir -p $AGENT_HOME/bin
sudo mkdir -p /var/log/agent-app
```

### (fix) 다른 계정이 agent-admin 홈 아래로 들어갈 수 있게 권한 설정
```bash
sudo chmod +x /home/agent-admin
```


### 소유권과 권한 설정

```bash

# chown은 소유자를 결정하는것
# chmod는 접근 권할을 설정하는것

# upload_files: agent-common R/W  → 770 (이전 750에서 변경)
sudo chown agent-admin:agent-common $AGENT_HOME/upload_files
sudo chmod 770 $AGENT_HOME/upload_files

# api_keys: agent-core R/W  → 770 (이전 750에서 변경)
sudo chown agent-admin:agent-core $AGENT_HOME/api_keys
sudo chmod 770 $AGENT_HOME/api_keys

# bin: 스크립트 위치
sudo chown agent-dev:agent-core $AGENT_HOME/bin
sudo chmod 750 $AGENT_HOME/bin

# 로그: agent-core R/W  → 770 + ACL
sudo chown agent-dev:agent-core /var/log/agent-app
sudo chmod 770 /var/log/agent-app
sudo setfacl -m u:agent-admin:rwx /var/log/agent-app

```

### 권한 부여 확인

```bash
getfacl /var/log/agent-app

# getfacl: Removing leading '/' from absolute path names
# # file: var/log/agent-app
# # owner: agent-dev
# # group: agent-core
# user::rwx
# user:agent-admin:rwx
# group::rwx
# mask::rwx
# other::---
```

### 권한 설정 최종 확인

```bash

sudo ls -ld $AGENT_HOME/upload_files $AGENT_HOME/api_keys $AGENT_HOME/bin /var/log/agent-app

# drwxrwx---  1 agent-admin agent-core   24 Oct 13 20:46 /home/agent-admin/agent-app/api_keys
# drwxr-x---  1 agent-dev   agent-core    0 Oct 13 20:12 /home/agent-admin/agent-app/bin
# drwxrwx---  1 agent-admin agent-common  0 Oct 13 20:12 /home/agent-admin/agent-app/upload_files
# drwxrwx---+ 1 agent-dev   agent-core    0 Oct 13 20:12 /var/log/agent-app

# drwxrwxrwx에서
# rwx : 7
# r-x : 5
# --- : 0

```


### api키를 만듭니다.

```bash
echo "agent_api_key_test" | sudo tee $AGENT_HOME/api_keys/secret.key > /dev/null
```

### api키의 권한과 소유를 설정합니다.

```bash
sudo chown agent-admin:agent-core $AGENT_HOME/api_keys/secret.key
sudo chmod 640 $AGENT_HOME/api_keys/secret.key
```
### api키의 권한이 잘 들어갔는지 확인합니다.

```bash
sudo ls -l $AGENT_HOME/api_keys/secret.key

# -rw-r----- 1 agent-admin agent-core 19 Oct 13 20:53 /home/agent-admin/agent-app/api_keys/secret.key
```


### 앱 구동을 위한 변수 5개 등록

```bash
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys/
export AGENT_LOG_DIR=/var/log/agent-app

# AGENT_HOME은 디렉터리 구조 생성 단계에서 먼저 export함 (총 5개)
# PDF는 AGENT_KEY_PATH를 키 파일 경로(.../t_secret.key)로 안내하지만,
# 제공된 앱은 이 디렉터리 안에서 secret.key를 찾기 때문에 디렉터리 경로로 설정했다
```

### 환경변수가 잘 입력 됬는지 확인한다.

```bash
env | grep AGENT_
```

### 제공된 파일을 실행하기 위해서 아키텍처가 arm인지 인텔인지 확인함

```bash
uname -m

# x86_64
```

### 실행 파일을 복사한다.

```bash
sudo cp /Users/ghwo61351/tasks_ghwo6/B04-01/misc/agent-app/agent-app-linux-x86 $AGENT_HOME/bin/agent-app
```

### 파일을 확인한다.

```bash
sudo ls -al $AGENT_HOME/bin

# total 6348
# drwxr-x--- 1 agent-dev agent-core      18 Oct 11 20:59 .
# drwxr-xr-x 1 root      root            46 Oct 11 20:25 ..
# -rwxr-xr-x 1 root      root       6498144 Oct 11 20:59 agent-app
```

### 소유권을 설정한다.

```bash
sudo chown agent-dev:agent-core $AGENT_HOME/bin/agent-app
```

### 소유권이 잘 바꼇는지 확인함

```bash
sudo ls -al $AGENT_HOME/bin

# total 6348
# drwxr-x--- 1 agent-dev agent-core      18 Oct 11 20:59 .
# drwxr-xr-x 1 root      root            46 Oct 11 20:25 ..
# -rwxr-xr-x 1 agent-dev agent-core 6498144 Oct 11 20:59 agent-app
```


### 파일을 실행함

```bash

sudo -E -u agent-dev bash -c 'nohup $AGENT_HOME/bin/agent-app > /var/log/agent-app/app.log 2>&1 &'
# PDF에는 t_secret.key로 되어 있지만, 제공된 앱이 secret.key를 요구해서 secret.key로 생성했다

# sudo -E -u agent-dev $AGENT_HOME/bin/agent-app
```

### monitor.sh 복사

```bash
sudo cp /Users/ghwo61351/tasks_ghwo6/B04-01/bin/monitor.sh $AGENT_HOME/bin/monitor.sh
```

### 복사 확인

```bash
sudo ls -l $AGENT_HOME/bin/

# total 6352
# -rwxr-xr-x 1 agent-dev agent-core 6498144 Oct 11 20:59 agent-app
# -rw-r--r-- 1 root      root           946 Oct 11 22:01 monitor.sh
# ghwo61351@agnet-server:/Users/ghwo61351/tasks_ghwo6/B04-01$ 
```

### 스크립트 소유권 및 실행 권한 부여

```bash
sudo chown agent-dev:agent-core $AGENT_HOME/bin/monitor.sh
sudo chmod 750 $AGENT_HOME/bin/monitor.sh
```

### 소유권 변화 확인

```bash
sudo ls -l $AGENT_HOME/bin/

# total 6356
# -rwxr-xr-x 1 root      root       6498144 Oct 17 20:03 agent-app
# -rwxr-x--- 1 agent-dev agent-core    4385 Oct 17 20:31 monitor.sh

# agent-app은 10/17에 다시 cp하면서 소유자가 root로 돌아감 (cp한 사용자 소유가 됨)
# 실행에는 문제 없지만 일관성을 위해 아래 명령으로 다시 소유권을 맞춘다
# sudo chown agent-dev:agent-core $AGENT_HOME/bin/agent-app
```

### 모니터링 스크립트 실행

```bash
sudo -u agent-admin $AGENT_HOME/bin/monitor.sh
```


### 0.0.0.0:15034 LISTEN 상태 확인

```bash
sudo ss -tulnp | grep 15034

# tcp   LISTEN 0      1                  0.0.0.0:15034      0.0.0.0:*    users:(("agent-app",pid=3843,fd=4))      
```


### 크론탭 등록

```bash
sudo crontab -e -u agent-admin

# 에디터 맨 아래에 
# * * * * * /home/agent-admin/agent-app/bin/monitor.sh 라고 입력함

# 에디터를 나오면

# crontab: installing new crontab

# 라고 출력함

```


### monitor.log 확인

```bash
sudo cat /var/log/agent-app/monitor.log
```
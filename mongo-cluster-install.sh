#!/bin/bash

# 检查firewall端口是否开放
firewall_port() {
    local port=$1
    if firewall-cmd --zone=public --query-port=$port/tcp &> /dev/null; then
        echo "端口 $port 已开放"
    else
        echo "端口 $port 未开放"
        firewall-cmd --zone=public --add-port=$port/tcp --permanent
        firewall-cmd --reload
    fi
}

# 检查是否已安装MongoDB组件
check_mongodb_installed() {
    if command -v mongod &> /dev/null; then
        version=$(mongod --version | awk '/db version/ {print $3}')
        echo "已安装MongoDB组件，版本号：$version"
        return 1;
    else
        echo "未安装MongoDB组件"
        return 0;

    fi
}

# 安装MongoDB yum源
mongodb_yum() {
    local version=$1
    cat > /etc/yum.repos.d/mongodb.repo << EOF
[mongodb-org-$version]
name = MongoDB Repository
baseurl = https://mirrors.aliyun.com/mongodb/yum/redhat/8/mongodb-org/$version/x86_64/
gpgcheck = 0
enabled = 1
EOF
}

#安装MongoDB组件
mongodb_install() {
    yum search mongodb-org --showduplicates | sort -r | grep metapackage | awk '{print $1}'
    read -p "选择安装版本：" install_version
    yum install $install_version
}

config_write_to_file() {
    local file=\$1
    cat > "$file" << EOF
# \$replSetName
#-----------

# 日志
systemLog:
  quiet: true
  destination: file
  path: \$logpath
  logAppend: true
  logRotate: reopen
  timeStampFormat: iso8601-local

# 存储
storage:
  dbPath: \$dbpath
  journal:
    enabled: true
  directoryPerDB: true
  engine: wiredTiger
  wiredTiger:
    engineConfig:
      cacheSizeGB: 1
      directoryForIndexes: true
    collectionConfig:
      blockCompressor: snappy
    indexConfig:
      prefixCompression: true

# 进程管理
processManagement:
  pidFilePath: \$pidFilePath
  fork: true

# 网络
net:
  bindIpAll: true
  port: 27017

# 安全
#security:
#  keyFile: /etc/mongod.d/mongodb.key
#  clusterAuthMode: keyFile

setParameter:
    enableLocalhostAuthBypass: true
# 分片
sharding:
  clusterRole: shardsvr

operationProfiling:
    mode: slowOp
    slowOpThresholdMs: 500

replication:
    oplogSizeMB: 10240
    replSetName: \$replSetName        
EOF
}


echo "开始MongoDB部署检查"

check_mongodb_installed

installed="$?" 

if [ "$installed" -eq 0 ]; then 
    read -p "安装mongodb版本(4.2, 4.4):" mongo_version
    mongodb_yum $mongo_version
    mongodb_install
fi

echo "请选择MongoDB部署方式

===========================================
  0. 重新部署mongodb
===========================================
  1. 部署单机副本集
  2. 部署单机分片集群
-------------------------------------------
 在多台主机上分别部署mongod,mongos,config
-------------------------------------------
  3. 部署mongod服务
  4. 部署mongos服务
  5. 部署config服务
==========================================="

read -p "请输入数字:" num
case $num in
    0)
        echo "0. 开始重新部署mongodb"

        read -p "安装mongodb版本(4.2, 4.4):" mongo_version
        mongodb_yum $mongo_version
        mongodb_install
        ;;
    1)
        echo "1. 开始部署单机副本集"
        ;;
    2)
        echo "2. 开始部署单机分片集群"
        ;;
    3)
        echo "3. 开始部署mongod服务"
        read -p "分片名shardName:" shardName
        read -p "配置文件路径conf (default:/etc/mongod.d/mongod.conf)" path
        read -p "数据存储路径dbpath (default:/var/data/mongod):" dbpath
        read -p "日志存储路径logpath (default:/var/log/mongodb/mongod.log):" logpath
        read -p "进程管理文件路径pidFilePath (default:/var/run/mongodb/mongod.pid):" pidFilePath
        
        if [ -z "$path" ]; then
            path="/etc/mongod.d/mongod.conf"
        fi

        if [ -z "$dbpath" ]; then
            dbpath="/var/data/mongod"
        fi

        if [ -z "$logpath" ]; then
            logpath="/var/log/mongodb/mongod.log"
        fi

        if [ -z "$pidFilePath" ]; then
            pidFilePath="/var/run/mongodb/mongod.pid"
        fi        

        echo "路径配置检查：
        配置文件路径conf: $path 
        分片名shardName: $shardName
        数据存储路径dbpath: $dbpath
        日志存储路径logpath: $logpath
        进程管理文件路径pidFilePath: $pidFilePath"

        touch $path
        mkdir -p $dbpath
        touch $logpath
        touch $pidFilePath

        cat > $path << EOF
# $shardName
#-----------

# 日志
systemLog:
  quiet: true
  destination: file
  path: $logpath
  logAppend: true
  logRotate: reopen
  timeStampFormat: iso8601-local

# 存储
storage:
  dbPath: $dbpath
  journal:
    enabled: true
  directoryPerDB: true
  engine: wiredTiger
  wiredTiger:
    engineConfig:
      cacheSizeGB: 1
      directoryForIndexes: true
    collectionConfig:
      blockCompressor: snappy
    indexConfig:
      prefixCompression: true

# 进程管理
processManagement:
  pidFilePath: $pidFilePath
  fork: true

# 网络
net:
  bindIpAll: true
  port: 27017

# 安全
#security:
#  keyFile: /etc/mongod.d/mongodb.key
#  clusterAuthMode: keyFile

setParameter:
    enableLocalhostAuthBypass: true
# 分片
sharding:
  clusterRole: shardsvr

operationProfiling:
    mode: slowOp
    slowOpThresholdMs: 500

replication:
    oplogSizeMB: 10240
    replSetName: $shardName        
EOF

        ;;
    4)
        echo "4. 开始部署mongos服务"
        ;;
    5)
        echo "5. 开始部署config服务"
        ;;
    *)
        echo "请输入正确的数字"
        ;;
esac
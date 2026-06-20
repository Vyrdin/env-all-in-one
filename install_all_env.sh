
## install_all_env.sh
```bash
#!/bin/bash
# 全能LNMP/LAMP/TOMCAT/REDIS/PROMETHEUS/GRAFANA一键部署脚本
# 支持CentOS/Ubuntu/Debian
# Author: DevOps Tool

set -e
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# ===================== 配置区 =====================
# 数据库密码
MYSQL_ROOT_PWD="DB@Admin123456"
# Redis密码
REDIS_PWD="Redis@Pass666"
# Grafana管理员密码
GRAFANA_ADMIN_PWD="Grafana@123"
# JDK版本 8 / 17
JDK_VER="17"
# 监控数据存储目录
MONITOR_DATA_DIR=/data/monitor
# MySQL数据目录
MYSQL_DATA_DIR=/data/mysql
# Redis数据目录
REDIS_DATA_DIR=/data/redis
# 日志目录
LOG_DIR=/var/log/all_env_install
mkdir -p ${LOG_DIR}
LOG_FILE=${LOG_DIR}/install_$(date +%Y%m%d_%H%M%S).log

# 安装开关 1=开启 0=关闭
INSTALL_LNMP=1
INSTALL_LAMP=0
INSTALL_REDIS=1
INSTALL_TOMCAT=1
INSTALL_MONITOR=1 # Prometheus+Grafana+node-exporter
# ==================================================

# 日志输出函数
log() {
    local LEVEL=$1
    shift
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] [${LEVEL}] $*" | tee -a ${LOG_FILE}
}

# 系统识别
check_os() {
    if [ -f /etc/redhat-release ]; then
        OS_TYPE="centos"
        if grep -q "release 7" /etc/redhat-release; then
            OS_VER=7
        elif grep -q "release 8" /etc/redhat-release; then
            OS_VER=8
        elif grep -q "release 9" /etc/redhat-release; then
            OS_VER=9
        fi
    elif [ -f /etc/lsb-release ]; then
        OS_TYPE="ubuntu"
        OS_VER=$(lsb_release -rs | cut -d. -f1)
    elif [ -f /etc/debian_version ]; then
        OS_TYPE="debian"
        OS_VER=$(cat /etc/debian_version | cut -d. -f1)
    else
        log ERROR "不支持当前操作系统，退出"
        exit 1
    fi
    log INFO "识别系统: ${OS_TYPE} ${OS_VER}"
}

# 基础环境初始化
init_system() {
    log INFO "===== 系统初始化、关闭SELinux/防火墙 ====="
    # SELinux
    if [ ${OS_TYPE} = "centos" ]; then
        setenforce 0
        sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
        # 防火墙
        systemctl stop firewalld
        systemctl disable firewalld
    else
        ufw disable
    fi

    # 内核参数优化
    cat > /etc/sysctl.d/99-all-optimize.conf <<EOF
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65535
fs.file-max = 655350
vm.swappiness = 10
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
EOF
    sysctl -p /etc/sysctl.d/99-all-optimize.conf

    # 文件句柄优化
    cat > /etc/security/limits.d/99-nofile.conf <<EOF
* soft nofile 65535
* hard nofile 65535
root soft nofile 65535
root hard nofile 65535
EOF

    # 更新软件源 & 基础工具
    if [ ${OS_TYPE} = "centos" ]; then
        if [ ${OS_VER} -eq 7 ]; then
            curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
        elif [ ${OS_VER} -eq 8 ]; then
            curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-8.repo
        elif [ ${OS_VER} -eq 9 ]; then
            curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-9.repo
        fi
        yum clean all && yum makecache
        yum install -y wget unzip zip net-tools lsof telnet curl vim git gcc gcc-c++ make openssl-devel
    else
        apt update -y
        apt install -y wget unzip zip net-tools lsof telnet curl vim git gcc make libssl-dev
    fi
    log INFO "系统初始化完成"
}

# MySQL 统一安装
install_mysql() {
    log INFO "===== 安装 MySQL 8.0 ====="
    if [ ${OS_TYPE} = "centos" ]; then
        rpm -ivh https://dev.mysql.com/get/mysql80-community-release-el${OS_VER}-3.noarch.rpm
        yum install -y mysql-community-server
    else
        apt install -y mysql-server mysql-client
    fi
    systemctl enable --now mysqld || systemctl enable --now mysql
    sleep 5

    # 初始化密码
    if [ ${OS_TYPE} = "centos" ]; then
        TMP_PWD=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}')
        mysql -uroot -p"${TMP_PWD}" --connect-expired-password <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PWD}';
CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PWD}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL
    else
        mysql -uroot <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PWD}';
CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PWD}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL
    fi
    log INFO "MySQL安装完成，root密码: ${MYSQL_ROOT_PWD}"
}

# LNMP Nginx+PHP
install_lnmp() {
    if [ ${INSTALL_LNMP} -ne 1 ]; then return; fi
    log INFO "===== 安装 LNMP Nginx + PHP8.1 ====="
    if [ ${OS_TYPE} = "centos" ]; then
        yum install -y nginx php php-fpm php-mysqlnd php-redis php-gd php-mbstring php-curl php-opcache
    else
        apt install -y nginx php8.1-fpm php8.1-mysql php8.1-redis php8.1-gd php8.1-mbstring php8.1-curl
    fi
    # 替换优化Nginx配置
    cp ./conf/nginx_default.conf /etc/nginx/conf.d/default.conf
    systemctl enable --now nginx
    systemctl enable --now php-fpm || systemctl enable --now php8.1-fpm
    log INFO "LNMP 安装完成，Nginx默认页面: http://本机IP"
}

# LAMP Apache+PHP
install_lamp() {
    if [ ${INSTALL_LAMP} -ne 1 ]; then return; fi
    log INFO "===== 安装 LAMP Apache + PHP ====="
    if [ ${OS_TYPE} = "centos" ]; then
        yum install -y httpd php php-mysqlnd php-redis
        systemctl enable --now httpd
    else
        apt install -y apache2 php8.1 libapache2-mod-php8.1 php8.1-mysql
        systemctl enable --now apache2
    fi
    log INFO "LAMP Apache安装完成，访问: http://本机IP"
}

# Redis
install_redis() {
    if [ ${INSTALL_REDIS} -ne 1 ]; then return; fi
    log INFO "===== 安装 Redis 7 ====="
    mkdir -p ${REDIS_DATA_DIR}
    if [ ${OS_TYPE} = "centos" ]; then
        yum install -y redis
    else
        apt install -y redis-server
    fi
    sed -i "s/^# requirepass.*/requirepass ${REDIS_PWD}/" /etc/redis/redis.conf
    sed -i "s/^bind 127.0.0.1/bind 0.0.0.0/" /etc/redis/redis.conf
    sed -i "s|^dir .*|dir ${REDIS_DATA_DIR}|" /etc/redis/redis.conf
    systemctl enable --now redis || systemctl enable --now redis-server
    log INFO "Redis安装完成，密码: ${REDIS_PWD} 端口6379"
}

# JDK + Tomcat9 (SpringBoot运行环境)
install_java_tomcat() {
    log INFO "===== 安装 JDK${JDK_VER} + Tomcat9 ====="
    mkdir -p /usr/local/java /usr/local/tomcat
    # JDK17
    if [ ${JDK_VER} = "17" ]; then
        wget -q https://download.java.net/java/GA/jdk17.0.10/GPL/openjdk-17.0.10_linux-x64_bin.tar.gz -O /tmp/jdk.tar.gz
        tar -xf /tmp/jdk.tar.gz -C /usr/local/java
        mv /usr/local/java/jdk-17.0.10 /usr/local/java/jdk17
        echo "export JAVA_HOME=/usr/local/java/jdk17" >> /etc/profile
    else
        wget -q https://download.java.net/java/jdk8u402/GA/openjdk-8u402-linux-x64.tar.gz -O /tmp/jdk.tar.gz
        tar -xf /tmp/jdk.tar.gz -C /usr/local/java
        mv /usr/local/java/jdk1.8.0_402 /usr/local/java/jdk8
        echo "export JAVA_HOME=/usr/local/java/jdk8" >> /etc/profile
    fi
    echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile
    source /etc/profile

    # Tomcat9
    wget -q https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.85/bin/apache-tomcat-9.0.85.tar.gz -O /tmp/tomcat.tar.gz
    tar -xf /tmp/tomcat.tar.gz -C /usr/local/tomcat
    mv /usr/local/tomcat/apache-tomcat-9.0.85 /usr/local/tomcat/tomcat9
    # 替换优化server.xml
    cp ./conf/tomcat_server.xml /usr/local/tomcat/tomcat9/conf/server.xml
    chmod +x /usr/local/tomcat/tomcat9/bin/*.sh

    # Systemd管理Tomcat
    cat > /etc/systemd/system/tomcat.service <<EOF
[Unit]
Description=Tomcat9 Server
After=network.target
[Service]
Environment="JAVA_HOME=${JAVA_HOME}"
ExecStart=/usr/local/tomcat/tomcat9/bin/startup.sh
ExecStop=/usr/local/tomcat/tomcat9/bin/shutdown.sh
User=root
Restart=always
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now tomcat
    log INFO "JDK${JDK_VER} + Tomcat9 安装完成，Tomcat访问: http://本机IP:8080"
}

# Prometheus + Grafana + node-exporter 监控全套
install_monitor() {
    if [ ${INSTALL_MONITOR} -ne 1 ]; then return; fi
    log INFO "===== 部署 Prometheus + Grafana + node-exporter ====="
    mkdir -p ${MONITOR_DATA_DIR}/{prometheus,node-exporter,grafana}
    # node-exporter
    wget -q https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz -O /tmp/node.tar.gz
    tar -xf /tmp/node.tar.gz -C /usr/local/
    mv /usr/local/node_exporter-1.8.2.linux-amd64 /usr/local/node-exporter
    cat > /etc/systemd/system/node-exporter.service <<EOF
[Unit]
Description=Node Exporter
After=network.target
[Service]
ExecStart=/usr/local/node-exporter/node_exporter --web.listen-address=0.0.0.0:9100
Restart=always
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now node-exporter

    # Prometheus
    wget -q https://github.com/prom/prometheus/releases/download/v2.52.0/prometheus-2.52.0.linux-amd64.tar.gz -O /tmp/prom.tar.gz
    tar -xf /tmp/prom.tar.gz -C /usr/local/
    mv /usr/local/prometheus-2.52.0.linux-amd64 /usr/local/prometheus
    # 使用项目内置优化配置
    cp ./conf/prometheus_custom.yml /usr/local/prometheus/prometheus.yml
    cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus Server
After=network.target node-exporter.service
[Service]
ExecStart=/usr/local/prometheus/prometheus --config.file=/usr/local/prometheus/prometheus.yml --storage.tsdb.path=${MONITOR_DATA_DIR}/prometheus --web.listen-address=0.0.0.0:9090
Restart=always
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now prometheus

    # Grafana
    if [ ${OS_TYPE} = "centos" ]; then
        wget -q https://dl.grafana.com/oss/release/grafana-11.0.0-1.x86_64.rpm -O /tmp/grafana.rpm
        rpm -ivh /tmp/grafana.rpm
    else
        wget -q https://dl.grafana.com/oss/release/grafana_11.0.0_amd64.deb -O /tmp/grafana.deb
        dpkg -i /tmp/grafana.deb
    fi
    systemctl enable --now grafana-server
    sleep 8
    grafana-cli admin reset-admin-password ${GRAFANA_ADMIN_PWD}
    log INFO "监控部署完成："
    log INFO "Prometheus: http://本机IP:9090"
    log INFO "Grafana: http://本机IP:3000 账号admin 密码${GRAFANA_ADMIN_PWD}"
    log INFO "Node-Exporter监控指标端口:9100"
    log INFO "Grafana面板模板路径: ./docs/grafana_dashboard.json"
}

# 输出汇总信息
print_summary() {
    local IP=$(hostname -I | awk '{print $1}')
    log INFO "==================== 部署完成信息汇总 ===================="
    log INFO "服务器IP: ${IP}"
    log INFO "MySQL root密码: ${MYSQL_ROOT_PWD}"
    log INFO "Redis 连接密码: ${REDIS_PWD}"
    log INFO "Grafana admin密码: ${GRAFANA_ADMIN_PWD}"
    log INFO "Web服务:"
    [ ${INSTALL_LNMP} -eq 1 ] && log INFO " LNMP Nginx: http://${IP}"
    [ ${INSTALL_LAMP} -eq 1 ] && log INFO " LAMP Apache: http://${IP}"
    log INFO "Tomcat/SpringBoot容器: http://${IP}:8080"
    log INFO "监控平台:"
    [ ${INSTALL_MONITOR} -eq 1 ] && log INFO " Prometheus: http://${IP}:9090 | Grafana: http://${IP}:3000"
    log INFO "备份脚本目录: ./backup/"
    log INFO "巡检脚本: ./monitor_check.sh"
    log INFO "=========================================================="
}

# 主流程
main() {
    check_os
    init_system
    install_mysql
    install_lnmp
    install_lamp
    install_redis
    install_java_tomcat
    install_monitor
    print_summary
    log INFO "全部环境部署完成！日志文件: ${LOG_FILE}"
}

main
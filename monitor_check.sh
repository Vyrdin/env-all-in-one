#!/bin/bash
# Linux全能环境巡检脚本 LNMP/LAMP/Redis/Tomcat/Prometheus/Grafana
LOG_PATH="/var/log/env_check"
mkdir -p ${LOG_PATH}
CHECK_LOG=${LOG_PATH}/check_$(date +%Y%m%d_%H%M%S).log
IP=$(hostname -I | awk '{print $1}')

print_title() {
    echo -e "\n==================================== $1 ====================================" | tee -a ${CHECK_LOG}
}

log_out() {
    echo "$1" | tee -a ${CHECK_LOG}
}

# 1.系统基础信息
check_system_base() {
    print_title "1.系统基础信息"
    log_out "主机IP: $IP"
    log_out "主机名: $(hostname)"
    log_out "系统版本: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
    log_out "内核版本: $(uname -r)"
    log_out "运行时长: $(uptime | awk -F, '{print $1}')"
    log_out "当前登录用户: $(who)"
}

# 2.CPU/内存/负载
check_cpu_mem() {
    print_title "2.CPU、内存、负载状态"
    log_out "系统负载: $(uptime)"
    log_out "CPU核心数: $(grep -c processor /proc/cpuinfo)"
    log_out "内存使用:"
    free -h | tee -a ${CHECK_LOG}
    log_out "Swap使用:"
    cat /proc/meminfo | grep Swap | tee -a ${CHECK_LOG}
}

# 3.磁盘使用率&inode
check_disk() {
    print_title "3.磁盘分区使用率"
    df -h | tee -a ${CHECK_LOG}
    print_title "磁盘Inode占用"
    df -i | tee -a ${CHECK_LOG}
    log_out "磁盘告警分区(>85%):"
    df -h | awk 'NR>1 {gsub(/%/,"");if($5>85)print "告警: "$0}'
}

# 4.端口监听状态
check_port() {
    print_title "4.关键业务端口监听"
    log_out "80(Nginx/Apache) 3306(Mysql) 6379(Redis) 8080(Tomcat) 9090(Prometheus) 3000(Grafana) 9100(node-exporter)"
    ss -tulnp | grep -E "80|3306|6379|8080|9090|3000|9100" | tee -a ${CHECK_LOG}
}

# 5.服务运行状态
check_service() {
    print_title "5.核心服务运行状态"
    service_list="nginx httpd mysqld mysql redis redis-server tomcat prometheus grafana-server node-exporter"
    for svc in ${service_list};do
        if systemctl list-unit-files | grep -q ${svc};then
            stat=$(systemctl is-active ${svc})
            if [ "${stat}" = "active" ];then
                log_out "✅ ${svc} 运行正常"
            else
                log_out "❌ ${svc} 已停止"
            fi
        fi
    done
}

# 6.MySQL巡检
check_mysql() {
    print_title "6.MySQL数据库巡检"
    if systemctl is-active mysqld &>/dev/null || systemctl is-active mysql &>/dev/null;then
        mysql -uroot -pDB@Admin123456 -e "show status like 'Threads_connected';show databases;" 2>/dev/null | tee -a ${CHECK_LOG}
    else
        log_out "MySQL服务未启动，跳过巡检"
    fi
}

# 7.Redis巡检
check_redis() {
    print_title "7.Redis缓存巡检"
    if systemctl is-active redis &>/dev/null || systemctl is-active redis-server &>/dev/null;then
        redis-cli -a Redis@Pass666 info server 2>/dev/null | head -20 | tee -a ${CHECK_LOG}
    else
        log_out "Redis未启动，跳过巡检"
    fi
}

# 8.Tomcat日志报错
check_tomcat_log() {
    print_title "8.Tomcat错误日志统计"
    tomcat_log=/usr/local/tomcat/tomcat9/logs/catalina.out
    if [ -f ${tomcat_log} ];then
        log_out "ERROR报错行数: $(grep -i error ${tomcat_log} | wc -l)"
        grep -i error ${tomcat_log} | tail -10 | tee -a ${CHECK_LOG}
    else
        log_out "Tomcat日志文件不存在"
    fi
}

# 9.监控组件状态
check_monitor() {
    print_title "9.Prometheus & Grafana 监控状态"
    curl -s http://127.0.0.1:9090/-/healthy &>/dev/null && log_out "✅ Prometheus健康" || log_out "❌ Prometheus异常"
    curl -s http://127.0.0.1:3000/api/health &>/dev/null && log_out "✅ Grafana健康" || log_out "❌ Grafana异常"
    curl -s http://127.0.0.1:9100/metrics &>/dev/null && log_out "✅ Node-Exporter正常采集" || log_out "❌ Node-Exporter采集失败"
}

# 主执行
main() {
    echo "==================== 环境巡检开始 时间: $(date) ====================" > ${CHECK_LOG}
    check_system_base
    check_cpu_mem
    check_disk
    check_port
    check_service
    check_mysql
    check_redis
    check_tomcat_log
    check_monitor
    echo -e "\n巡检完成，报告存放路径: ${CHECK_LOG}"
}

main
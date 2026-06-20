# 定时任务配置 crontab -e
# 每日凌晨2点自动巡检
0 2 * * * /root/env-all-in-one/monitor_check.sh
# 每日凌晨3点MySQL备份
0 3 * * * /root/env-all-in-one/backup/mysql_backup.sh
# 每日凌晨4点Redis备份
0 4 * * * /root/env-all-in-one/backup/redis_backup.sh
#!/bin/bash
REDIS_CLI=$(which redis-cli)
REDIS_PWD=Redis@Pass666
BACKUP_DIR=/data/backup/redis
mkdir -p ${BACKUP_DIR}
# 触发RDB持久化
${REDIS_CLI} -a ${REDIS_PWD} BGSAVE
# 拷贝rdb备份
cp /data/redis/dump.rdb ${BACKUP_DIR}/dump_$(date +%Y%m%d).rdb
# 7天清理
find ${BACKUP_DIR} -name "*.rdb" -mtime +7 -delete
echo "Redis备份完成"
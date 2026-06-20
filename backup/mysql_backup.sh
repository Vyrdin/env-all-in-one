#!/bin/bash
MYSQL_USER=root
MYSQL_PWD=DB@Admin123456
BACKUP_DIR=/data/backup/mysql
DATE=$(date +%Y%m%d)
mkdir -p ${BACKUP_DIR}
# 全库备份
mysqldump -u${MYSQL_USER} -p${MYSQL_PWD} --all-databases > ${BACKUP_DIR}/all_db_${DATE}.sql
# 保留7天备份
find ${BACKUP_DIR} -name "*.sql" -mtime +7 -delete
echo "MySQL备份完成: ${BACKUP_DIR}/all_db_${DATE}.sql"
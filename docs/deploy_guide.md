# 部署操作指南
1. 上传完整 env-all-in-one 文件夹至服务器 /root
2. 赋权
chmod +x *.sh backup/*.sh
3. 修改 install_all_env.sh 顶部配置密码、安装开关
4. 执行部署
./install_all_env.sh
5. 日常巡检
./monitor_check.sh
6. 定时任务参考 docs/crontab_task.md
7. Grafana导入面板：登录Grafana → Dashboards → Import 上传 grafana_dashboard.json
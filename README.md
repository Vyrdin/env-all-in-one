# Linux全能运维环境一键部署套件 env-all-in-one
## 适配系统
CentOS7 / CentOS8 / CentOS9 | Ubuntu20.04 / 22.04 | Debian10 / Debian11

## 内置全套业务&监控组件
### Web服务（二选一开关控制）
1. LNMP：Nginx + PHP8.1
2. LAMP：Apache + PHP8.1
### 数据存储
- MySQL 8.0 数据库（支持远程访问）
- Redis7 缓存服务（带连接密码）
### Java业务运行环境
- JDK8 / JDK17 自由切换
- Tomcat9 容器（适配SpringBoot项目部署）
### 全链路监控平台
- Prometheus 时序指标存储
- Grafana 可视化监控面板
- node-exporter 服务器硬件指标采集

## 📂 项目完整目录结构
env-all-in-one/
├── install_all_env.sh # 一键安装主脚本 LNMP/LAMP/Redis/Tomcat/Prometheus/Grafana
├── monitor_check.sh # 全组件一键巡检脚本（系统 + 数据库 + 缓存 + 中间件 + 监控）
├── docs/
│ ├── deploy_guide.md # 详细部署操作教程、参数修改说明
│ ├── crontab_task.md # 定时巡检、定时备份 crontab 配置模板
│ └── grafana_dashboard.json # Linux 服务器监控大盘导入模板
├── conf/
│ ├── nginx_default.conf # Nginx 站点优化配置
│ ├── tomcat_server.xml # Tomcat 线程 / 编码优化配置
│ └── prometheus_custom.yml # Prometheus 指标采集扩展规则
├── backup/
│ ├── mysql_backup.sh # MySQL 全库定时备份脚本（自动 7 天清理）
│ └── redis_backup.sh # Redis RDB 持久化备份脚本
└── README.md # 项目总说明文档
plaintext

## 🚀 快速部署使用步骤
1. 将完整项目压缩包上传至服务器 `/root` 目录并解压
2. 进入项目根目录，统一给所有脚本赋予执行权限
chmod +x *.sh backup/*.sh
修改 install_all_env.sh 脚本顶部配置区，自定义数据库、Redis、Grafana 密码，按需开关 LNMP/LAMP 组件
执行一键环境部署
./install_all_env.sh
日常环境巡检（一键输出完整巡检报告）
./monitor_check.sh
Grafana 导入监控大盘：登录 Grafana → Dashboards → Import，上传 docs/grafana_dashboard.json
定时任务配置参考 docs/crontab_task.md，实现自动巡检、自动数据库备份
📌 默认端口汇总
表格
服务组件	端口	访问地址说明
Nginx/Apache	80	http:// 服务器 IP
MySQL	3306	数据库连接端口
Redis	6379	缓存连接端口
Tomcat	8080	SpringBoot 容器访问地址
Prometheus	9090	监控指标后台
Grafana	3000	可视化监控面板（账号 admin）
node-exporter	9100	服务器指标采集端口
📦 项目打包 & 生产部署说明
将本项目完整目录打包为 env-all-in-one.zip，上传至 Linux 服务器解压即可开箱使用：
部署脚本会自动加载 conf/ 目录下预制优化配置，无需手动修改 Nginx、Tomcat、Prometheus 原生配置文件；
全部账号密码、组件安装开关统一在 install_all_env.sh 顶部配置区集中修改，巡检、备份脚本同步替换密码即可适配自有环境；
目录分层规范清晰，严格区分部署脚本、巡检工具、定时备份任务、服务配置、操作文档，内置 Grafana 监控面板 json 文件，开箱即用监控大盘，便于长期维护、迭代扩展；
内置全套运维配套脚本，可直接落地用于 IDC 机房、私有云虚拟化批量服务器标准化初始化。
⚠️ 生产环境安全提示
公网服务器部署完成后，建议限制 MySQL、Redis、Grafana 端口 IP 访问白名单，避免全网段开放；
所有默认密码务必修改为高强度自定义密码，禁止线上使用脚本内置默认密码；
推荐本地修改脚本配置后再上传服务器，避免明文密码暴露在公共仓库。
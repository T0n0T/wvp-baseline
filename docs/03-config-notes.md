# 配置说明

## WVP 关键配置

baseline 运行时基线目录：`runtime/`

重点文件：

- `runtime/.env`
- `runtime/docker-compose.yml`
- `runtime/wvp/wvp/application-docker.yml`
- `runtime/media/config.ini`
- `runtime/nginx/templates/nginx.conf.template`

脚本实际运行目录：`.runtime/`

- 以上基线文件会在执行命令前同步到 `.runtime/`
- 不应手工把 `.runtime/` 作为长期配置保存位置

## 地址配置原则

以下值必须是设备和浏览器都能访问到的宿主机地址：

- `Stream_IP`
- `SDP_IP`
- `SIP_ShowIP`
- `runtime/media/config.ini` 中的 `rtc.externIP`

## 持久化路径原则

以下内容统一落到 `.runtime/`：

- PostgreSQL 数据：`.runtime/volumes/postgresql/data`
- Redis 数据：`.runtime/volumes/redis/data`
- 录像数据：`.runtime/volumes/video`
- 服务日志：`.runtime/logs/`

## 当前默认运行信息

- WVP 默认后台账号：`admin`
- WVP 默认后台密码：`admin`
- WVP 默认 HTTP 端口：`18978`
- Nginx 默认外部端口：`8080`
- SIP 端口：`8160`
- 媒体端口：`10001/10002/10003/8000`

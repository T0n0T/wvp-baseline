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

## 代理配置原则

构建时使用如下环境变量：

- `http_proxy`
- `https_proxy`
- `no_proxy`
- `HTTP_PROXY`
- `HTTPS_PROXY`
- `NO_PROXY`

代理仅在镜像构建阶段通过 `--build-arg` 传入，不应作为最终容器运行时环境变量固化。

# stream-media-baseline

用于统一管理 `WVP-GB28181-Pro` 与 `ZLMediaKit` 的基线仓库。

## 目录结构

- `vendor/wvp-GB28181-pro`：WVP 子模块
- `vendor/ZLMediaKit`：ZLMediaKit 子模块
- `runtime/`：可提交的运行时基线文件
- `.runtime/`：命令执行时生成的运行时目录，包含 compose 工作目录、日志和持久化数据，不纳入提交
- `scripts/`：构建、配置、启动、停止、状态收集脚本实现
- `docs/`：镜像构建与部署说明
- `dockerfiles/`：本仓库维护的 Dockerfile 方案
- `tests/`：baseline 脚本回归检查

## 入口命令

统一使用根目录脚本：

```bash
./baseline.sh [--dry-run] <command> [args]
```

支持的子命令：

- `configure [ip]`
- `build`
- `start`
- `stop`
- `status`
- `help`

`--dry-run` 只输出将要执行的命令，不实际改配置，也不会真正执行 `docker compose`。

## 当前运行方式

本仓库当前以 Docker Compose 方式管理以下服务：

- `polaris-media`：本仓库内构建的 `ZLMediaKit`
- `polaris-wvp`：本仓库内构建的 `WVP-GB28181-Pro`
- `polaris-nginx`：本仓库内构建的前端与反向代理镜像
- `polaris-postgresql`
- `polaris-redis`

## 运行时目录

- `runtime/` 存放可提交的基线配置。
- `.runtime/` 由脚本按需生成，不纳入 git。
- 启动、停止、状态查询都基于 `.runtime/` 运行。
- PostgreSQL、Redis、录像和日志等持久化内容都写入 `.runtime/volumes` 与 `.runtime/logs`。

## 常用流程

```bash
./baseline.sh configure 10.8.4.63
./baseline.sh build
./baseline.sh start
./baseline.sh status
```

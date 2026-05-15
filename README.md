# stream-media-baseline

用于统一管理 `WVP-GB28181-Pro` 与 `ZLMediaKit` 的基线仓库。

## 目录结构

- `vendor/wvp-GB28181-pro`：WVP 子模块
- `vendor/ZLMediaKit`：ZLMediaKit 子模块
- `skeletons/`：可提交的运行时骨架文件
- `.runtime/`：命令执行时生成的运行时目录，包含 compose 工作目录、日志和持久化数据，不纳入提交
- `scripts/`：构建、配置、启动、停止、状态收集脚本实现
- `scripts/env.sh`：默认环境变量入口，包含代理、端口、SIP 和主机地址默认值
- `docs/`：镜像构建与部署说明
- `dockerfiles/`：本仓库维护的 Dockerfile 方案
- `tests/`：baseline 脚本回归检查

## 入口命令

拉取项目后，需要初始化 submodules

```bash
git clone https://github.com/T0n0T/wvp-baseline.git --recursive
# 或
git clone https://github.com/T0n0T/wvp-baseline.git
cd wvp-baseline
git submodule update --init --recursive
```

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

## 配置入口

优先修改 `scripts/env.sh`，这里集中管理默认值：

- `BASELINE_HOST_IP`
- `BASELINE_WEB_HTTP`
- `BASELINE_WEB_HTTPS`
- `BASELINE_MEDIA_RTMP`
- `BASELINE_MEDIA_RTSP`
- `BASELINE_MEDIA_RTP`
- `BASELINE_MEDIA_RTC`
- `BASELINE_SIP_PORT`
- `BASELINE_SIP_DOMAIN`
- `BASELINE_SIP_ID`
- `BASELINE_SIP_PASSWORD`
- `BASELINE_RECORD_SIP`
- `BASELINE_RECORD_PUSH_LIVE`
- `BASELINE_SECCOMP_UNCONFINED`
- `http_proxy`
- `https_proxy`
- `no_proxy`
- `HTTP_PROXY`
- `HTTPS_PROXY`
- `NO_PROXY`

默认情况下：

- `BASELINE_HOST_IP=AUTO_HOST_IP`
- 运行脚本时会自动解析执行机器的实际 IPv4，并回填到 `.runtime/.env` 与 `.runtime/media/config.ini`
- 如果你执行 `./baseline.sh configure 192.168.x.x`，只会更新现有 `.runtime/` 中的地址相关配置


## 兼容性说明

### ppc64le + 旧内核 Docker 适配

在 ppc64le 架构 + 旧内核/Docker 环境下（如 Debian 10 + Docker v20.10），默认 seccomp 策略会阻止 Redis 8.x、ZLMediaKit、Java JVM 创建线程，导致以下错误：

- Redis: `Fatal: Can't initialize Background Jobs. Operation not permitted`
- ZLMediaKit: `std::thread::_M_start_thread` throw system_error
- WVP: `pthread_create failed (EPERM)` GC 线程创建失败

设置环境变量 `BASELINE_SECCOMP_UNCONFINED=true` 后，`materialize_runtime()` 会自动将 `skeletons/docker-compose.override.yml` 同步到运行时目录，为相关容器添加 `security_opt: [seccomp:unconfined]` 绕过该限制。

```bash
export BASELINE_SECCOMP_UNCONFINED=true
./baseline.sh start
```

正常 x86_64 环境无需此配置，默认 false。

## 当前运行方式

本仓库当前以 Docker Compose 方式管理以下服务：

- `polaris-media`：本仓库内构建的 `ZLMediaKit`
- `polaris-wvp`：本仓库内构建的 `WVP-GB28181-Pro`
- `polaris-nginx`：本仓库内构建的前端与反向代理镜像
- `polaris-postgresql`
- `polaris-redis`

## 目录语义

- `skeletons/` 存放可提交的基线配置骨架。
- `.runtime/` 由脚本按需生成，不纳入 git。
- 启动、停止、状态查询都基于 `.runtime/` 运行。
- `configure` 只操作已经存在的 `.runtime/`，不会改 `skeletons/` 或 `scripts/env.sh`。
- PostgreSQL、Redis、录像和日志等持久化内容都写入 `.runtime/volumes` 与 `.runtime/logs`。

## 常用流程

```bash
# 1. 按需修改 scripts/env.sh
# 2. 可选：显式指定当前机器对外地址
./baseline.sh configure
# 或者
./baseline.sh configure 192.168.1.10

# 3. 构建镜像
./baseline.sh build

# 4. 启动系统
./baseline.sh start

# 5. 查看状态与关键信息
./baseline.sh status
```

## 构建代理

代理只通过 `docker compose build --build-arg ...` 注入构建阶段：

- 如果你在 `scripts/env.sh` 或当前 shell 里设置了 `http_proxy` / `https_proxy` 等变量，`./baseline.sh build` 会自动把它们追加为 `--build-arg`
- Dockerfile 本身不再显式包一层 `env http_proxy=...` 调用

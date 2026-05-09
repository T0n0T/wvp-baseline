# stream-media-baseline

用于统一管理 `WVP-GB28181-Pro` 与 `ZLMediaKit` 的基线仓库。

## 目录结构

- `vendor/wvp-GB28181-pro`：WVP 子模块
- `vendor/ZLMediaKit`：ZLMediaKit 子模块
- `vendor/wvp-GB28181-pro-src`：指向当前远端 WVP 工作目录的只读软链接
- `vendor/ZLMediaKit-src`：指向当前远端 ZLMediaKit 工作目录的只读软链接
- `runtime/`：可提交的运行时基线文件
- `.runtime/`：命令执行时生成的运行时目录，包含 compose 工作目录、日志和持久化数据，不纳入提交
- `scripts/`：构建、配置、启动、停止、信息收集脚本实现
- `docs/`：镜像构建与部署说明
- `dockerfiles/`：本次采用的 Dockerfile 方案归档

## 入口命令

统一使用根目录脚本：

```bash
./baseline.sh [--dry-run] <command> [args]
```

支持的子命令：

- `build-images`
- `configure-project [ip]`
- `start-system`
- `stop-system`
- `system-info`
- `help`

`--dry-run` 会只输出将要执行的命令，不实际修改配置，也不会真正执行 `docker compose`。

## 运行时目录

- `runtime/` 存放可提交的基线配置。
- `.runtime/` 由脚本按需生成，不纳入 git。
- 启动、停止、信息查询都基于 `.runtime/` 运行。
- PostgreSQL、Redis、录像和日志等持久化内容都写入 `.runtime/volumes` 与 `.runtime/logs`。

## 构建代理

构建镜像时不在 baseline 脚本中固化导出 `http_proxy`、`https_proxy` 等环境变量。
如果当前 shell 已设置这些代理变量，`build-images` 会自动追加对应的 `docker compose build --build-arg` 参数传给镜像构建阶段。
当前 `dockerfiles/wvp.Dockerfile` 只在构建阶段临时注入代理，不再把代理固化到最终镜像环境变量中。

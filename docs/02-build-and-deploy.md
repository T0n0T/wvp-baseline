# 构建与部署记录

## 当前镜像角色

- `local/zlmediakit:ppc64le`
- `docker-polaris-wvp:latest`
- `docker-polaris-nginx:latest`
- `postgres:16-alpine`
- `redis:latest`

## 当前部署要点

- WVP 使用 PostgreSQL，不再使用 MySQL。
- WVP 前端静态资源使用宿主机构建产物 `src/main/resources/static`。
- Nginx 负责将 `/api/` 代理到 WVP，将 `/rtp/` 与 `/index/api/` 代理到 ZLMediaKit。
- WVP 与 ZLMediaKit 使用 docker compose 在同一桥接网络中互通。
- 设备可见地址需使用宿主机实际可达地址，不能使用 `127.0.0.1`。
- baseline 仓库中的 `runtime/` 保存可提交的运行时基线，`.runtime/` 为脚本生成的真实运行目录。
- 构建 WVP、nginx 镜像时，仍使用 WVP 源仓库作为 build context，但 compose 工作目录与数据卷路径全部切到 `.runtime/`。

## 当前已知事项

- 设备国标注册默认密码来自 `runtime/.env` 中的 `SIP_Password`。
- Jessibuca 黑屏排障中，已确认以下两类问题都实际出现过：
  - 点播时下发错误收流地址 `127.0.0.1:10003`
  - Nginx 模板缺少 `sub_filter` 规则，导致返回给前端的 `ws_flv/flv/rtc` URL 仍指向 `:80`

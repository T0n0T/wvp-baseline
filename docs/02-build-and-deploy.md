# 构建与部署记录

## 当前镜像角色

- `baseline/polaris-media:local`
- `baseline/polaris-wvp:local`
- `baseline/polaris-nginx:local`
- `postgres:16-alpine`
- `redis:latest`

## 当前部署要点

- WVP 使用 PostgreSQL，不再使用 MySQL。
- WVP 前端静态资源在 `polaris-nginx` 镜像构建阶段生成。
- Nginx 负责将 `/api/` 代理到 WVP，将 `/rtp/` 与 `/index/api/` 代理到 ZLMediaKit。
- WVP 与 ZLMediaKit 使用 docker compose 在同一桥接网络中互通。
- 设备可见地址必须使用宿主机实际可达地址，不能使用 `127.0.0.1`。
- baseline 仓库中的 `skeletons/` 保存可提交的运行时骨架，`.runtime/` 为脚本生成的真实运行目录。
- `./baseline.sh build` 会顺序构建 `polaris-media`、`polaris-wvp`、`polaris-nginx`。

## 当前验证路径

```bash
./baseline.sh configure 10.8.4.63
./baseline.sh build
./baseline.sh start
./baseline.sh status
```

## 当前已知事项

- WVP 默认后台账号来自数据库初始化脚本：`admin / admin`
- 设备国标注册默认密码来自 `skeletons/.env` 初始化到 `.runtime/.env` 后的 `SIP_Password`
- `status` 会输出当前关键运行信息，包括 WVP 地址、后台默认账号、SIP 参数与媒体端口

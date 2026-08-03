# 05 WVP 管理 Web 界面实施计划

> 状态：草案，待评审。
> 适用基线：`vendor/wvp-GB28181-pro` **2.7.4**（提交 `761c3082`）。
> API 契约与字段定义：见 [04-wvp-api-reference.md](./04-wvp-api-reference.md)（第 9 节附录为各请求体的完整字段表）。
> 技术栈（已确认）：**Vue 3 + TypeScript + Vite + Element Plus + Pinia + axios**。

## 1. 目标与边界

新建一个独立维护的管理 Web，替换/并存于官方 `web/` 前端，覆盖设备、通道、播放、录像、配置与运维能力。

- **只消费 `/api/*` 正常管理接口**，不依赖 `/api/v1/*` 历史兼容层和 `/api/sy/*` 定制层（04 §1）。
- **首版做最小闭环**（登录 → 设备/通道 → 实时播放 → PTZ → 录像回放），配置型页面放到第二阶段，避免把低频设备能力做成强依赖（04 §3、§5）。
- 逐通道 RBAC 后端不做，界面不得假设接口自带权限边界（04 §6.7）。

## 2. 技术栈与关键依赖

| 领域 | 选型 | 说明 |
| --- | --- | --- |
| 脚手架 | Vite + Vue 3 + TS | `npm create vue@latest` 起步，路由用 Vue Router 4 |
| 状态 | Pinia | 仅存登录态、当前播放的 `StreamContent`、全局播放器实例 |
| UI | Element Plus | 表格/表单/树/弹窗直接满足管理界面需求 |
| HTTP | axios | 拦截器统一注入 `access-token`、拆包、401 处理 |
| 播放器 | Jessibuca（ws_flv/wss_flv）+ WebRTC（rtc/rtcs） | 与官方前端选择一致（04 §4.4）；Jessibuca 必须本地打包，禁止 CDN |
| 图表（可选） | ECharts | 首页运行概况 |
| 地图（可选，Phase 2） | OpenLayers | 官方前端用 `ol`；矢量瓦片是 protobuf，需配套解析（04 §4.3） |
| 类型生成 | 手写起步 | 依据 04 附录 9.x 手写 TS 类型，后续可脚本化对齐 `/v3/api-docs` |

## 3. 仓库位置与目录结构

**建议：本仓库根目录新建 `ui/`**，与 `skeletons/` 平行，构建产物接入 `polaris-nginx` 镜像（见 §9）。优点：与基线仓库同生命周期、部署链路最短；后续若需独立发布再拆仓。

```
ui/
├── vite.config.ts                # dev proxy 指向 nginx 外部地址
├── src/
│   ├── api/                      # 按域拆分的接口模块，禁止页面直拼 URL（04 §6.2）
│   │   ├── request.ts            # axios 实例 + unwrapWvp<T> + 鉴权拦截器
│   │   ├── auth.ts / device.ts / channel.ts / playback.ts
│   │   ├── ptz.ts / record.ts / stream.ts / admin.ts
│   │   └── types/
│   │       ├── wvp.d.ts          # 04 附录 9.2–9.8 生成的实体类型
│   │       └── response.ts       # WvpResponse<T> / PageInfo<T>
│   ├── player/                   # Jessibuca / WebRTC 封装（协议选择、生命周期）
│   ├── stores/                   # authStore、playerStore（Pinia）
│   ├── views/                    # 页面组件
│   └── router/                   # 路由 + 登录守卫
└── public/
```

## 4. 页面清单与接口映射

### Phase 1：最小闭环（M1–M3）

| 页面 | 接口（详见 04） | 要点 |
| --- | --- | --- |
| 登录 | §4.1 `/api/user/login`（密码 32 位小写 MD5）、`/api/user/userInfo` | 登录页与 API 必须走 HTTPS（§2.1）；令牌写 `access-token` 头 |
| 首页运行概况 | §4.8 `/api/server/info`、`/api/server/system/info`、`/api/server/media_server/load` | 三个接口并行拉取 |
| 国标设备列表 | §4.2 `/api/device/query/devices` | 分页 `page`/`count`；`query`、`status` 过滤 |
| 设备通道列表 | §4.2 `/api/device/query/devices/{deviceId}/channels` | 目录（`channelType=true`）与通道区分；目录需 `sub_channels` 递归进入 |
| 实时播放 | §4.4 `/api/play/start/{deviceId}/{channelId}`、`/api/play/stop/...` | 有状态操作：保存 `StreamContent`，卸载/切台必调 stop（§6.3） |
| PTZ 控制 | §4.5 `/api/front-end/*` | `pointerdown` 发方向、`pointerup`/失焦/销毁发 `stop`；防重复提交（§6.4） |
| 国标录像查询/回放 | §4.6 `/api/gb_record/query/*`、`/api/playback/start|pause|resume|seek|speed|stop` | 异步 SIP；时间格式 `yyyy-MM-dd HH:mm:ss`；`stream`/`streamId` 取返回字段，不自行拼接 |
| 云端录像（可选） | §4.7 `/api/cloud/record/*` | 录像播放路径 + 装载 |

### Phase 2：配置与运维（M4–M5）

| 页面 | 接口（详见 04） | 表单字段 |
| --- | --- | --- |
| 统一通道库 | §4.3 `/api/common/channel/list`、`one`、`add|update|reset` | 04 附录 9.3（`gbId` 即整数主键，`reset` 字段名是 `chanelFields`） |
| 行政区划 / 业务分组 | §4.3 `/api/region/*`、`/api/group/*` | 树 + 分页双视图 |
| 拉流代理 | §4.8 `/api/proxy/*` | 附录 9.6；创建前先查媒体节点列表，不硬编码浏览器地址（§4.8） |
| 推流通道 | §4.8 `/api/push/*` | 附录 9.7；类型继承 `CommonGBChannel` |
| 媒体节点 | §4.8 `/api/server/media_server/list|save|check` | 附录 9.5；`secret` 禁止写日志/URL |
| 上级平台（级联） | §4.9 `/api/platform/*` | 附录 9.4；国标通信配置，提交前专门校验 |
| 录制计划 | §4.9 `/api/record/plan/*` | 附录 9.8；半小时槽位 0–47 + 周几 |
| 用户与 API Key | §4.1 `/api/user/*`、`/api/role/all`、`/api/userApiKey/*` | 管理员角色 ID 为 1 由后端强校验（§4.1） |
| 报警 / 位置 | §4.7 `/api/alarm/*`、`/api/position/*` | 快照按 JPEG 处理（204 无内容） |
| 日志 | §4.9 `/api/log/*` + WebSocket `/channel/log` | 令牌作 WS 子协议；服务端只推不收 |

## 5. API 层设计

1. **`unwrapWvp<T>`**：非 2xx 直接失败；2xx 但 `code !== 0` 转业务错误。二进制下载、快照图片、OpenAPI 走旁路不拆包（04 §6.1）。
2. **类型命名**：国标通道号与通用通道主键分开命名——`channelDeviceId`（字符串国标号）与 `channelDbId`（整数主键），杜绝错误点播（04 §2.3）。`StreamPush extends CommonGBChannel` 的类型同样继承（04 附录 9.1-4）。
3. **鉴权拦截器**：请求注入 `access-token` 头；收到 401 清令牌回登录页。密码 MD5 计算用稳定实现（小写 32 位），明文不进日志。
4. **有状态操作登记**：`playback.ts` 维护当前活动流 Map（deviceId+channelId → streamId），页面卸载统一 stop；防止设备与媒体服务残留流（04 §6.3）。
5. **必填与枚举校验在前端表单完成**：服务端无 Bean 校验（04 附录 9.1-1），后端只以业务码兜底；枚举取值照附录表格。

## 6. 播放器集成

- 协议选择（04 §4.4）：页面 HTTPS → `wss_flv` 或 `rtcs`；HTTP → `ws_flv` 或 `rtc`。字段为空时提示"媒体节点未开启该协议"，不自行拼接端口。
- H265 依赖 Jessibuca（wasm），首帧白屏/失败给出明确提示并提供 WebRTC 回退。
- 已知流（代理/推流/云录像）用 `/api/media/getPlayUrl`，不发起国标点播（§4.4）。
- 播放器组件卸载、路由切换、切台三处必须触发 stop；`playerStore` 持有唯一播放器实例，避免双播。

## 7. 分阶段里程碑与验收

| 里程碑 | 内容 | 验收标准（真机验证点） |
| --- | --- | --- |
| M1 | 脚手架、登录、设备列表、通道列表 | 登录 → 设备 → 通道目录可正确展开；列表分页/过滤正常 |
| M2 | 实时播放、停止、PTZ | 真机点播出画面（H264/H265 各验证）；停止后设备与媒体节点无残留流；PTZ 松键即停 |
| M3 | 国标录像查询、回放（暂停/seek/倍速）、云录像 | 录像片段正确列出；回放可 seek；离开页面自动停止 |
| M4 | 配置页：媒体节点、代理、推流、平台、录制计划、用户/API Key | 新增节点连通性检查通过；代理拉流成功；级联平台注册成功；计划时间片生效 |
| M5 | 报警、位置、实时日志、首页指标 | 报警列表/快照正常；实时日志推送可见；首页指标与 `status` 输出一致 |

每个里程碑合入前跑一遍 04 §7 的回归路径（登录、列表、点播、停止、PTZ、录像查询、回放）。

## 8. 开发与联调

- 开发期 `VITE_WVP_BASE_URL` 指向 **nginx 外部地址**（如 `http://10.8.4.63:8080`），而不是直连 `18978`：这样 `/api/` 的 sub_filter 重写（§9）生效，`StreamContent` 返回的媒体 URL 可直接被浏览器使用；直连端口会拿到 ZLM 内网地址，浏览器不可达（02 §部署要点）。
- Vite dev proxy：`/api`、`/rtp`、`/mp4_record`、`/mediaserver` 转发到同一 nginx 地址，避免开发期 CORS。
- 基线开发配置 `interface-authentication: false`（04 §2.1）：联调方便但**生产必须开启**，前端从第一天就按"带令牌"实现，不要依赖关闭状态。

## 9. 部署

现状拓扑（02 §当前部署要点、skeletons/nginx/templates/nginx.conf.template）：

- `polaris-nginx` 以 `/opt/dist` 为静态根，`location /` 服务前端
- `/api/` → `polaris-wvp:18978`，并做 sub_filter 将 JSON 里的媒体地址重写为 nginx 可达路径
- `/rtp/`、`/mp4_record/` → `polaris-media`；`/mediaserver/api/downloadFile` → 媒体节点下载

方案 A（推荐）：`ui/` 构建产物替换 `/opt/dist` 内容，接入 `dockerfiles/nginx.Dockerfile`（当前该文件从 `web/` 构建并拷贝 `static` 目录，接入时改为多阶段：`npm run build` 产物直接 `COPY --from=builder /build/dist /opt/dist`）。改造后 `./baseline.sh build && start` 即可整体上线，无需新增容器或端口。

方案 B：新 UI 独立容器/静态服务器，通过同源反向代理或 CORS 访问 `/api`；需配置 `user-settings.allowed-origins`（04 §2.1）。

## 10. 风险与注意事项

1. **三类 ID 混淆**（04 §2.3）：国标号 vs 通用通道主键 vs `app+stream`，类型层用命名区分。
2. **流泄漏**：start 后未 stop 会持续占用设备与媒体资源；stop 调用是强约定，不依赖组件库生命周期钩子的时序。
3. **PTZ 持续转动**：`pointerup`、失焦、销毁缺一不可（04 §4.5）。
4. **H265 兼容**：浏览器原生不支持，必须 Jessibuca/WebRTC；测试用 H264 摄像头与 H265 摄像头各一。
5. **混合内容**：HTTPS 页面拉 `ws://`/`http://` 会被浏览器拦截（04 §4.4）。
6. **令牌与密钥**：`access-token`、`api-key`、媒体节点 `secret` 不得进日志、错误上报或 URL（04 §6.6）。
7. **接口权限边界**：WVP 后端主要做全局登录校验，细粒度页面权限由新界面自建 BFF 或网关补充（04 §6.7）。
8. **sub_filter 依赖**：`/api/` 返回的 JSON 依赖 nginx 重写媒体地址；若换独立部署（方案 B），需确认 `StreamContent` 地址可达性，或在 BFF 层做同等重写。

## 11. 后续建议

- 从 `/v3/api-docs` 自动生成 TS 类型与 04 附录字段表对齐脚本，消除手工维护（04 §7 升级清单第 3 条）。
- 为新界面补充 `docs/06-*.md`（如播放器集成细则、表单校验规则表）时与 04 附录保持单向引用，避免双份字段描述。

# WVP 前端集成 API 参考手册

> 适用基线：仓库内 `vendor/wvp-GB28181-pro`，`pom.xml` 标识为 **2.7.4**，源码提交 `761c3082`（2026-05-09）。
>
> 本文面向另行维护的管理 Web。接口、字段及行为均由该版本后端控制器与随附 Vue 前端调用点交叉核对；实际部署仍应以运行实例的 OpenAPI 文档为最终准则。

## 1. 使用范围与地址

新前端应使用正常管理 API，即 `/api/*`。按基线配置，WVP HTTP 服务默认监听 `18978`，因此开发时可将：

```text
VITE_WVP_BASE_URL=http://<wvp-host>:18978
```

设为 API 基地址。若通过 Nginx 暴露服务，则使用 Nginx 的外部地址；不要把浏览器直接可见的地址、SIP 地址和 ZLMediaKit 内网地址混为一谈。

运行实例开启 `user-settings.doc-enable: true` 后，可查看完整的、随源码变化的接口定义：

- Knife4j：`GET /doc.html`
- Swagger UI：`GET /swagger-ui/index.html`
- OpenAPI JSON：`GET /v3/api-docs`（分组名称见界面）

`/api/v1/*` 是被 `@Hidden` 标注的历史兼容层，包含模拟登录和部分未完整实现的接口；`/api/sy/*` 是 `web.custom` 下的第三方定制接口。两者都不建议作为新管理界面的契约。

## 2. 通用约定

### 2.1 鉴权与跨域

默认后端设置为 `user-settings.interface-authentication: true` 时，除登录、快照、文档等白名单外，所有管理请求都需携带 JWT：

```http
access-token: <login response.data.accessToken>
```

也可在查询参数中传 `access-token`。WebSocket 握手则将令牌作为 `Sec-WebSocket-Protocol` 子协议传入。服务端还接受 `api-key` 头（由用户 API Key 管理接口生成的 JWT），适合服务到服务调用。

本基线的 `application-base.yml` 为便于本地联调，配置了 `interface-authentication: false` 和 `/api/**` 白名单；生产部署应改为开启鉴权，并将 `user-settings.allowed-origins` 限制为实际前端域名。不要把该开发默认值带入生产。

登录请求如下。`password` 是明文密码的 32 位小写 MD5；随附前端正是这样计算后再发送。该兼容协议不替代传输安全，登录页和 API 必须走 HTTPS。

```http
GET /api/user/login?username=admin&password=<md5(password)>
```

```json
{
  "code": 0,
  "msg": "成功",
  "data": {
    "accessToken": "eyJ...",
    "username": "admin",
    "serverId": "..."
  }
}
```

### 2.2 返回体、分页与错误

绝大多数 `/api/*` 响应会被全局包装为：

```ts
type WvpResponse<T> = {
  code: number; // 0 为成功
  msg: string;
  data: T;
};
```

常见业务码：`0` 成功、`100` 失败、`400` 参数或方法错误、`401` 未登录、`403` 无权限、`404` 未找到、`408` 请求超时、`486` 设备无响应、`500` 系统异常。业务错误有时返回 HTTP 200 加非零 `code`，因此前端必须同时判断 HTTP 状态和 `code`。

`PageInfo<T>` 位于 `data` 中，至少按 `data.list` 和 `data.total` 消费；查询接口统一使用 `page`（从 1 开始）与 `count`。截图、下载、地图矢量瓦片、日志文件等非 JSON 接口是例外，见各自说明。

### 2.3 三类 ID 不可混用

| 名称 | 类型 | 使用位置 |
| --- | --- | --- |
| `deviceId` | 国标设备编号，字符串 | `/api/device/*`、`/api/play/*` |
| `channelId`（国标） | 国标通道编号，字符串 | `/api/device/*`、`/api/play/*`、`/api/front-end/*` |
| `channelId`（通用通道） | 数据库自增 ID，整数 | `/api/common/channel/*` 及其前端控制接口 |

此外，`mediaServerId` 是 ZLMediaKit/ABL 节点 ID；`app + stream` 是媒体流唯一定位键。新前端的数据模型应把国标通道号和通用通道主键分别命名，例如 `channelDeviceId` 与 `channelDbId`，避免错误点播或控制。

## 3. 推荐的页面与接口映射

| 页面/能力 | 首选接口 |
| --- | --- |
| 登录、当前用户 | `/api/user/login`、`/api/user/userInfo` |
| 首页运行概况 | `/api/server/info`、`/api/server/system/info`、`/api/server/media_server/load` |
| 国标设备与其目录 | `/api/device/query/devices`、`/api/device/query/devices/{deviceId}/channels` |
| 跨来源的统一通道资源库 | `/api/common/channel/list` |
| 实时预览与停止 | `/api/play/start/{deviceId}/{channelId}`、`/api/play/stop/{deviceId}/{channelId}` |
| 云台、预置位、巡航 | `/api/front-end/*` 或 `/api/common/channel/front-end/*` |
| 国标录像与回放 | `/api/gb_record/query/*`、`/api/playback/*` |
| 服务器录像 | `/api/cloud/record/*` |
| 拉流代理、外部推流 | `/api/proxy/*`、`/api/push/*` |
| 国标级联、区域、分组 | `/api/platform/*`、`/api/region/*`、`/api/group/*` |
| 告警、设备位置 | `/api/alarm/*`、`/api/position/*` |

建议先实现“登录 → 设备/通道列表 → 实时播放 → 停止播放 → PTZ → 录像回放”的最小闭环，再逐步接入配置型页面。这样可尽早验证设备、SIP、媒体节点和浏览器播放链路。

## 4. 核心接口

### 4.1 用户、令牌与 API Key

| 方法 | 路径 | 参数/请求体 | 用途 |
| --- | --- | --- | --- |
| GET 或 POST | `/api/user/login` | `username`、`password`（MD5） | 登录；令牌也会写入 `access-token` 响应头 |
| POST | `/api/user/userInfo` | — | 当前登录用户 |
| POST | `/api/user/changePassword` | Query：`oldPassword`（MD5）、`password`（新密码明文） | 修改本人密码 |
| GET | `/api/user/users` | `page`、`count` | 分页用户列表 |
| GET | `/api/user/all` | — | 全部用户 |
| POST | `/api/user/add` | Query：`username`、`password`、`roleId` | 添加用户；仅管理员 |
| DELETE | `/api/user/delete` | Query：`id` | 删除用户；仅管理员 |
| GET | `/api/role/all` | — | 角色列表 |
| GET/POST/DELETE | `GET /api/userApiKey/userApiKeys`、`POST /api/userApiKey/add|enable|disable|reset|remark`、`DELETE /api/userApiKey/delete` | 列表：`page`、`count`；新增：`userId`、`app`、`enable`、`expiresAt`、`remark`；其他操作传 `id` | API Key 的查询、创建、启停、重置、备注和删除 |

账号管理中，后端明确检查管理员角色 ID 为 `1` 的地方主要是新增、删除与改他人密码；不要仅依赖前端隐藏按钮来实现权限边界。

> **添加用户已知缺陷（基线 2.7.4）**：`POST /api/user/add` 实测返回 500 —— `duplicate key value violates unique constraint "wvp_user_pkey" (id)=(1)`，`UserServiceImpl.addUser` 硬编码主键 `id=1` 导致已存在用户时必然冲突。前端调用方式本身正确（`username`/`password`/`roleId` 均被后端接收），升级 WVP 前不建议在管理界面开放用户新增。

### 4.2 国标设备与通道

| 方法 | 路径 | 关键参数 | 返回/说明 |
| --- | --- | --- | --- |
| GET | `/api/device/query/devices` | `page`、`count`，可选 `query`、`status` | `PageInfo<Device>` |
| GET | `/api/device/query/devices/{deviceId}` | path `deviceId` | 单个 `Device` |
| GET | `/api/device/query/devices/{deviceId}/channels` | `page`、`count`，可选 `query`、`online`、`channelType` | 设备下通道分页；`channelType=false/true` 表示设备通道/目录 |
| GET | `/api/device/query/sub_channels/{deviceId}/{channelId}/channels` | 同上 | 指定目录下通道 |
| GET | `/api/device/query/streams` | `page`、`count`、`query` | 当前已有流的通道 |
| GET | `/api/device/query/devices/{deviceId}/sync` | path `deviceId` | 触发设备目录同步，返回 `SyncStatus` |
| GET | `/api/device/query/sync_status` | `deviceId` | 轮询同步状态 |
| POST | `/api/device/query/device/add` | JSON `Device` | 手动添加国标设备 |
| POST | `/api/device/query/device/update` | JSON `Device` | 更新设备 |
| DELETE | `/api/device/query/devices/{deviceId}/delete` | path `deviceId` | 删除设备 |
| POST | `/api/device/query/transport/{deviceId}/{streamMode}` | path 参数 | 修改国标流传输模式 |
| POST | `/api/device/query/channel/audio` | Query：`channelId`、`audio` | 设置通道音频开关 |
| GET | `/api/device/query/snap/{deviceId}/{channelId}` | path 参数 | JPEG 快照，未登录白名单；按二进制图片处理 |
| GET | `/api/device/query/subscribe/catalog` | `id`、`cycle` | 设备目录订阅 |
| GET | `/api/device/query/subscribe/mobile-position` | `id`、`cycle`、`interval` | 移动位置订阅 |
| GET | `/api/device/query/subscribe/alarm` | `id`、`cycle` | 告警订阅 |

设备控制接口为：`GET /api/device/control/guard?deviceId=...&guardCmd=SetGuard|ResetGuard`、`GET /api/device/control/record?deviceId=...&channelId=...&recordCmdStr=...`、`GET /api/device/control/teleboot/{deviceId}`、`GET /api/device/control/reset_alarm`、`GET /api/device/control/i_frame`、`GET /api/device/control/home_position` 和 `GET /api/device/control/drag_zoom/zoom_in|zoom_out`。它们都会向设备发送 SIP 命令，应使用二次确认并将超时作为正常业务结果展示。

### 4.3 统一通道库、区域与业务分组

`/api/common/channel/*` 将国标通道、推流和拉流代理统一为 `CommonGBChannel`，适合用作新界面的资源总表。这里的 `channelId` 为整数数据库主键。

| 方法 | 路径 | 关键参数/请求体 | 用途 |
| --- | --- | --- | --- |
| GET | `/api/common/channel/list` | `page`、`count`，可选 `query`、`online`、`hasRecordPlan`、`channelType`（0/1/2）、`civilCode`、`parentDeviceId` | 统一资源分页 |
| GET | `/api/common/channel/one` | `id` | 单个统一通道 |
| POST | `/api/common/channel/add`、`/api/common/channel/update` | JSON `CommonGBChannel` | 创建/编辑通道元数据 |
| POST | `/api/common/channel/reset` | JSON `{ id, chanelFields }` | 重置指定字段 |
| GET | `/api/common/channel/industry/list`、`/api/common/channel/type/list`、`/api/common/channel/network/identification/list` | — | 编辑表单的枚举选项 |
| POST | `/api/common/channel/region/add` | JSON `{ civilCode, channelIds }` | 批量挂载到行政区划 |
| POST | `/api/common/channel/group/add` | JSON `{ parentId, businessGroup, channelIds }` | 批量挂载到业务分组 |
| GET | `/api/region/tree/list`、`/api/region/tree/query` | 过滤参数，后者需 `page`、`count` | 行政区划树/分页查询 |
| POST/DELETE | `/api/region/add`、`/api/region/update`、`/api/region/delete` | JSON `Region` 或 Query `id` | 区划维护 |
| GET | `/api/group/tree/list`、`/api/group/tree/query` | 过滤参数 | 业务分组树/分页查询 |
| POST/DELETE | `/api/group/add`、`/api/group/update`、`/api/group/delete` | JSON `Group` 或 Query `id` | 分组维护 |

需要地图时，`GET /api/common/channel/map/list` 查询点位，`GET /api/common/channel/map/tile/{z}/{x}/{y}` 与 `/map/thin/tile/{z}/{x}/{y}` 返回 `application/x-protobuf` 矢量瓦片，不能按 JSON 解析。

### 4.4 实时预览、媒体地址与截图

```http
GET /api/play/start/{deviceId}/{channelId}
access-token: <token>
```

此请求会发送 SIP INVITE，并异步等待媒体流就绪；成功时 `data` 为 `StreamContent`。停止播放必须在播放器关闭、切台或组件卸载时调用：

```http
GET /api/play/stop/{deviceId}/{channelId}
```

`StreamContent` 中最重要的字段如下：

| 字段 | 用途 |
| --- | --- |
| `app`、`stream`、`mediaServerId` | 识别流及其媒体节点 |
| `ws_flv`、`wss_flv` | 随附 Vue 界面的 Jessibuca/H265 播放器首选地址 |
| `rtc`、`rtcs` | WebRTC 播放地址 |
| `flv`、`https_flv`、`hls`、`https_hls`、`fmp4`、`rtsp`、`rtmp` | 其他协议地址，字段是否存在取决于媒体节点端口和协议配置 |
| `mediaInfo` | 编码、分辨率、帧率、音频、观看人数等 |
| `transcodeStream` | 存在转码时的替代流地址 |

浏览器页面为 HTTPS 时，只选择 `wss_flv` 或 `rtcs`，避免混合内容；HTTP 页面对应 `ws_flv` 或 `rtc`。随附前端将 Jessibuca 映射到 `ws_flv/wss_flv`，WebRTC 映射到 `rtc/rtcs`。

对于已知流（拉流代理、推流、云端录像等），可不发起国标点播，改用：

```http
GET /api/media/getPlayUrl?app=<app>&stream=<stream>&mediaServerId=<optional>
GET /api/media/stream_info_by_app_and_stream?app=<app>&stream=<stream>&mediaServerId=<optional>
```

后者支持 `callId` 流鉴权与 `useSourceIpAsStreamIp=true`。`/api/play/snap?deviceId=...&channelId=...` 是主动截图，成功时按普通 WVP JSON 消费其中的字符串数据；`/api/device/query/snap/{deviceId}/{channelId}` 才是已有快照文件，应按 JPEG 二进制处理。

### 4.5 PTZ、预置位与巡航

有两套控制入口，取决于列表来源：

| 资源来源 | 接口前缀 | 主键 |
| --- | --- | --- |
| 国标设备下的原生通道 | `/api/front-end` | `deviceId` + 国标 `channelId` |
| 统一通道库 | `/api/common/channel/front-end` | 整数 `channelId` |

两套路径的语义平行。常用入口如下：

| 功能 | 原生设备路径 | 通用通道路径 | 参数 |
| --- | --- | --- | --- |
| PTZ | `GET /api/front-end/ptz/{deviceId}/{channelId}` | `GET /api/common/channel/front-end/ptz` | `command`：`left/right/up/down/upleft/upright/downleft/downright/zoomin/zoomout/stop`；`horizonSpeed`/`verticalSpeed` 0–255（缺省 100）、`zoomSpeed` 0–15（缺省 16） |
| 预置位查询 | `/preset/query/{deviceId}/{channelId}` | `/preset/query` | 通用通道传 `channelId` |

> **PTZ 参数勘误**：实际后端（`PtzController`，基线 2.7.4）不接受 `speed` 参数，速度字段为 `horizonSpeed`/`verticalSpeed`/`zoomSpeed`。且 `zoomSpeed` 缺省值 16 超出其 0–15 校验范围，未显式传参时内部调用 `frontEndCommand` 会报 `100: combindCode2 为 0-15的数字`；前端必须显式传 0–15 的 `zoomSpeed`。
| 预置位增/调/删 | `/preset/add|call|delete/{deviceId}/{channelId}` | `/preset/add|call|delete` | `presetId` |
| 巡航 | `/cruise/*/{deviceId}/{channelId}` | `/tour/*` | `cruiseId`（通用路径名为 `tourId`）、`presetId`、速度或时间 |
| 扫描 | `/scan/*/{deviceId}/{channelId}` | `/scan/*` | `scanId`，设置速度再启动 |

PTZ 按键交互应在 `pointerdown` 发送方向命令，在 `pointerup`、失焦和组件销毁时立刻发送 `stop`。否则设备可能持续转动。云台、聚焦、光圈、雨刷和辅助开关均属于有副作用的设备命令，前端应避免重复点击重放。

### 4.6 国标录像、回放与下载

| 方法 | 路径 | 关键参数 | 用途 |
| --- | --- | --- | --- |
| GET | `/api/gb_record/query/{deviceId}/{channelId}` | `startTime`、`endTime`，格式 `yyyy-MM-dd HH:mm:ss` | 向设备查询录像片段 |
| GET | `/api/playback/start/{deviceId}/{channelId}` | `startTime`、`endTime` | 启动指定时段回放，返回 `StreamContent` |
| GET | `/api/playback/pause/{streamId}`、`/api/playback/resume/{streamId}` | path `streamId` | 暂停/恢复 |
| GET | `/api/playback/seek/{streamId}/{seekTime}` | `seekTime` 单位秒 | 跳转 |
| GET | `/api/playback/speed/{streamId}/{speed}` | 速度仅 `0.25/0.5/1/2/4/8` | 倍速 |
| GET | `/api/playback/stop/{deviceId}/{channelId}/{stream}` | path 参数 | 释放回放流 |
| GET | `/api/gb_record/download/start/{deviceId}/{channelId}` | `startTime`、`endTime`、`downloadSpeed` | 启动历史媒体下载，返回带下载信息的流对象 |
| GET | `/api/gb_record/download/progress/{deviceId}/{channelId}/{stream}` | path 参数 | 查询下载进度 |
| GET | `/api/gb_record/download/stop/{deviceId}/{channelId}/{stream}` | path 参数 | 终止下载 |

回放和下载与实时点播一样是异步 SIP 操作。界面应在请求中显示“正在向设备请求”，成功后再创建播放器；离开页面时无条件调用 stop。`stream`/`streamId` 必须取启动接口返回的字段，不能自行以设备号拼接。

### 4.7 云端录像、报警与位置

| 方法 | 路径 | 关键参数 | 用途 |
| --- | --- | --- | --- |
| GET | `/api/cloud/record/date/list` | `app`、`stream`，可选 `year`、`month`、`mediaServerId` | 有录像的日期 |
| GET | `/api/cloud/record/list` | `page`、`count`，可选 `app`、`stream`、`query`、`callId`、起止时间、`mediaServerId`、`ascOrder` | 云端录像分页 |
| GET | `/api/cloud/record/play/path` | `recordId` | 录像播放路径 |
| GET | `/api/cloud/record/loadRecord` | `app`、`stream`、`cloudRecordId` | 装载录像为可播放流 |
| GET | `/api/cloud/record/seek`、`/api/cloud/record/speed` | `mediaServerId`、`app`、`stream`、`seek|speed`、`schema` | 服务器录像跳转与倍速 |
| DELETE | `/api/cloud/record/delete` | JSON `{ ids: number[] }` | 删除录像 |
| GET | `/api/alarm/list` | `page`、`count`，可重复传 `alarmType`，可选起止时间 | 报警分页 |
| DELETE | `/api/alarm/delete` | JSON `number[]` | 按 ID 删除报警 |
| DELETE | `/api/alarm/clear` | 可选 `alarmType`、`beginTime`、`endTime` | 按过滤条件清空 |
| GET | `/api/alarm/snap/{id}` | path `id` | JPEG 报警快照；无内容时 HTTP 204 |
| GET | `/api/position/history/{deviceId}` | 可选 `channelId`、`start`、`end` | 历史位置轨迹 |
| GET | `/api/position/latest/{deviceId}` | path `deviceId` | 最近位置 |
| GET | `/api/position/realtime/{deviceId}` | path `deviceId` | 主动查询，等待设备响应 |

### 4.8 拉流代理、推流与媒体节点

| 方法 | 路径 | 关键参数/请求体 | 用途 |
| --- | --- | --- | --- |
| GET | `/api/proxy/list` | `page`、`count`，可选 `query`、`pulling`、`mediaServerId` | 拉流代理列表 |
| POST | `/api/proxy/add`、`/api/proxy/update` | JSON `StreamProxyParam` | 创建/编辑代理 |
| GET | `/api/proxy/start`、`/api/proxy/stop` | `id` | 启停代理 |
| DELETE | `/api/proxy/delete` | `id` | 删除代理 |
| GET | `/api/proxy/ffmpeg_cmd/list` | `mediaServerId` | FFmpeg 模板 |
| GET | `/api/push/list` | `page`、`count`，可选 `query`、`pushing`、`mediaServerId` | 推流列表 |
| POST | `/api/push/add`、`/api/push/update` | JSON `StreamPush` | 注册/编辑推流通道 |
| GET | `/api/push/start`、`/api/push/forceClose` | `id` | 启动或强制关闭 |
| POST | `/api/push/remove` | `id` | 删除单个推流 |
| DELETE | `/api/push/batchRemove` | JSON `{ ids: number[] }` | 批量删除 |
| GET | `/api/server/media_server/list`、`/api/server/media_server/online/list`、`/api/server/media_server/one/{id}` | — | 媒体节点配置与在线状态 |
| POST | `/api/server/media_server/save` | JSON `MediaServer` | 新增/更新媒体节点 |
| GET | `/api/server/media_server/check` | `ip`、`port`、`secret`、`type` | 连通性检查 |
| GET | `/api/server/media_server/media_info` | `app`、`stream`、`mediaServerId` | 流媒体信息 |
| GET | `/api/server/info`、`/api/server/system/info`、`/api/server/resource/info`、`/api/server/media_server/load` | — | 首页与运维指标 |

`StreamProxyParam` 的核心字段是 `type`（`default` 或 `ffmpeg`）、`app`、`stream`、`name`、`mediaServerId`、`url`、`timeoutMs`、`rtpType`、`enable`、`enableAudio`、`enableMp4`、`enableDisableNoneReader`、`ffmpegCmdKey`。`StreamPush` 的核心字段是 `app`、`stream`、`mediaServerId`，以及继承自统一通道的国标映射字段。创建前应先读取媒体节点列表，不要将浏览器地址硬编码进流定义。

### 4.9 国标级联、录制计划与日志

| 功能 | 接口 | 关键参数 |
| --- | --- | --- |
| 上级平台分页、详情 | `GET /api/platform/query`、`GET /api/platform/info/{id}` | `page`、`count`、`query` |
| 上级平台增改删 | `POST /api/platform/add`、`POST /api/platform/update`、`DELETE /api/platform/delete` | JSON `Platform`，删除传 `id` |
| 上级平台注册状态 | `GET /api/platform/exit/{serverGBId}` | 平台国标服务 ID |
| 分享通道查询/调整 | `GET /api/platform/channel/list`、`POST /api/platform/channel/add`、`DELETE /api/platform/channel/remove`、`POST /api/platform/channel/device/add|remove` | `platformId`，以及 `channelIds`/`deviceIds`；批量通道体可含 `all` |
| 录制计划 | `POST /api/record/plan/add|update`、`GET /api/record/plan/get|query`、`DELETE /api/record/plan/delete` | `RecordPlan`；查询使用 `page`、`count` |
| 计划关联 | `POST /api/record/plan/link` | `{ planId, channelIds?, deviceDbIds?, allLink? }` |
| 应用日志 | `GET /api/log/list`、`GET /api/log/file/{fileName}` | `query`、`startTime`、`endTime`；文件接口按文本/下载处理 |
| 实时服务日志 | WebSocket `/channel/log` | 令牌作为 WebSocket 子协议；服务端只推送，不接收客户端消息 |

`Platform` 提交体中至少核对 `enable`、`name`、`serverGBId`、`serverGBDomain`、`serverIp`、`serverPort`、`deviceGBId`、`deviceIp`、`devicePort`、`username`、`password`、`expires`、`keepTimeout`、`transport`、`characterSet`、`ptz`、`catalogGroup`。这是国标通信配置，提交前必须做专门表单校验。

## 5. 扩展接口索引

以下接口适合在第二阶段按需接入，避免在首版前端把低频设备能力做成强依赖。

| 前缀 | 能力 |
| --- | --- |
| `/api/device/config` | `basicParam`、`query`：读取/查询国标设备配置 |
| `/api/common/channel/play`、`/play/stop`、`/playback/*` | 以统一通道整数 ID 播放、停止、回放、暂停、跳转、倍速 |
| `/api/common/channel/civilcode/*`、`/parent/*` | 行政区划/父节点异常查询与清理 |
| `/api/common/channel/map/reset-level`、`/map/thin/draw|clear|save|progress` | 百万点位地图抽稀管理 |
| `/api/front-end/fi/iris|focus`、`/wiper`、`/auxiliary` | 原生通道的光圈、聚焦、雨刷、辅助开关 |
| `/api/rtp/*`、`/api/ps/*` | RTP/PS 收流与发流，适合级联或专业运维界面 |
| `/api/server/config`、`/version`、`/shutdown` | 服务配置、版本和停机；停机接口不应暴露到普通用户 UI |
| `/api/cloud/record/task/*`、`collect/*`、`download/zip`、`zip`、`list-url` | 录像合并、收藏、打包下载及 URL 查询 |
| `/api/jt1078/*`、`/api/jt1078/terminal/*` | 部标 808/1078 终端、实时预览、回放、位置、区域/路线、对讲和媒体查询 |

部标终端是独立业务域：它以 `phoneNumber`、终端通道 ID 和专用 JSON 请求体工作，不应与 GB28181 的 `deviceId/channelId` 复用同一个前端类型。

## 6. 前端实现建议

1. 在 HTTP 客户端单独实现 `unwrapWvp<T>`：非 2xx 直接失败，2xx 但 `code !== 0` 也转换为可展示的业务错误。二进制下载/图片、OpenAPI 和旧 `/api/v1` 走旁路，不要拆包。
2. 把 API 分成 `auth`、`device`、`channel`、`playback`、`ptz`、`record`、`stream`、`admin` 模块；不要让页面组件直接拼 URL。
3. 预览接口是有状态操作。保存 `StreamContent`，优先使用它返回的地址；页面卸载时调用对应 stop 接口，避免设备和媒体服务残留流。
4. 对 SIP 触发的“同步、点播、录像查询、PTZ、订阅”等请求显示加载状态并允许超时；不要因用户重复点按并发发送同一个设备命令。
5. 对媒体 URL 做协议选择：HTTPS 页面选择 `wss_flv`/`rtcs`，HTTP 页面选择 `ws_flv`/`rtc`。当字段为空时，提示媒体节点未开启该协议，而不是自行拼接端口。
6. 令牌存储和登出策略由新前端自行决定，但不得将 `access-token`、`api-key`、媒体节点 `secret` 写入日志、错误上报或 URL。
7. 新界面若需要更细粒度的页面权限，应在自己的 BFF 或后端补齐授权策略；当前 WVP 源码主要提供全局登录校验，不能假定每个资源接口都完成了逐通道 RBAC。

## 7. 维护与校验清单

WVP 升级时，按以下顺序更新本手册：

1. 记录 `vendor/wvp-GB28181-pro/pom.xml` 版本和子模块提交。
2. 在测试环境打开 `/doc.html`，导出 `/v3/api-docs`，核对新增/删除路径和请求体 schema。
3. 对照第 9 节附录与实体类源码（`gb28181/bean/`、`streamProxy/bean/` 等），核对请求体字段的新增、删除与类型变化，同步更新附录表格。
4. 用真实设备跑通登录、设备列表、点播、停止、PTZ、录像查询和回放，确认返回媒体 URL 可以从浏览器访问。
5. 复核 `user-settings.interface-authentication`、`allowed-origins`、`doc-enable` 与 Nginx 反向代理是否一致。
6. 对不再使用的 `/api/v1/*`、`/api/sy/*`、`/api/test/*` 和高危运维接口做网关拦截或不在菜单中暴露。

## 8. 本手册的源码依据

- 控制器：`vendor/wvp-GB28181-pro/src/main/java/com/genersoft/iot/vmp/**/controller/`、`vmanager/`、`streamProxy/`、`streamPush/`。
- 鉴权、统一返回、OpenAPI：`conf/security/`、`GlobalResponseAdvice`、`SpringDocConfig`。
- 页面实际调用与播放器协议选择：`vendor/wvp-GB28181-pro/web/src/api/`、`web/src/utils/request.js`、`web/src/views/common/channelPlayer/`。
- 本仓库默认端口与安全开关：`skeletons/wvp/wvp/application-base.yml`。

## 9. 附录：核心请求体字段定义

> 本节字段来自下列实体源码（`vendor/wvp-GB28181-pro/src/main/java/com/genersoft/iot/vmp/`），与第 4 节接口表中的 JSON 请求体一一对应：
>
> - `gb28181/bean/Device.java` → `/api/device/query/device/add|update`
> - `gb28181/bean/CommonGBChannel.java` → `/api/common/channel/add|update`
> - `gb28181/bean/Platform.java` → `/api/platform/add|update`
> - `media/bean/MediaServer.java` → `/api/server/media_server/save`
> - `streamProxy/bean/StreamProxyParam.java` → `/api/proxy/add|update`
> - `streamPush/bean/StreamPush.java` → `/api/push/add|update`
> - `service/bean/RecordPlan.java` + `RecordPlanItem.java` → `/api/record/plan/add|update`

### 9.1 通用约定（读本节前必读）

1. **服务端没有 Bean 校验**。全仓库控制器无任何 `@Valid`/`@Validated`/`@NotNull` 使用，实体上也没有校验注解；必填、枚举、取值范围全部要靠前端表单把关，后端只以业务错误码（如 100/400/486）兜底。提交表单时必须自行校验必填项和枚举值。
2. **布尔与 0/1 整数不互通**。`enable`、`ssrcCheck` 等是 JSON `true/false`；`catalogWithPlatform`、`registerWay` 等是整数，不要互相传错类型。
3. **时间字段**由后端按 `yyyy-MM-dd HH:mm:ss` 返回（`createTime`、`updateTime`、`pushTime`、`gpsTime` 等），前端只展示，不作为提交字段。
4. **`StreamPush` 继承 `CommonGBChannel`**：推流通道的国标映射字段（`gbDeviceId`、`gbName` 等）与统一通道共用一套定义，前端类型同样用 extends。
5. 下表“提交”列含义：`必填`＝创建时必须提供；`可选`＝可省略；`只读`＝后端生成/维护，提交时忽略或不应修改。
6. 对 `CommonGBChannel`，新增/编辑是“编辑通道元数据”：除 `gbDeviceId` 外全部可选，接口按业务语义合并字段；另注意 `/api/common/channel/reset` 的请求体字段名是 `chanelFields`（源码如此拼写，保持原样，不要“修正”）。

### 9.2 `Device`（国标设备）

| 字段 | 类型 | 提交 | 说明 |
| --- | --- | --- | --- |
| `id` | int | 只读 | 数据库自增 ID |
| `deviceId` | string | 必填 | 设备国标编号 |
| `name` | string | 可选 | 名称 |
| `manufacturer` | string | 可选 | 生产厂商 |
| `model` | string | 可选 | 型号 |
| `firmware` | string | 可选 | 固件版本 |
| `transport` | string | 可选 | 传输协议：`UDP`/`TCP` |
| `streamMode` | string | 可选 | 数据流传输模式：`UDP`/`TCP-ACTIVE`/`TCP-PASSIVE` |
| `ip` | string | 可选 | 设备 IP |
| `port` | int | 可选 | 设备端口 |
| `hostAddress` | string | 可选 | 设备 wan 地址 |
| `onLine` | boolean | 只读 | 是否在线 |
| `registerTimeStamp` | long | 只读 | 注册时间戳 |
| `keepaliveTimeStamp` | long | 只读 | 心跳时间戳 |
| `heartBeatInterval` | int | 可选 | 心跳间隔秒数，缺省 60 |
| `heartBeatCount` | int | 可选 | 心跳超时次数，缺省 3 |
| `positionCapability` | int | 只读 | 定位能力：`0`-不支持，`1`-GPS，`2`-北斗 |
| `channelCount` | int | 只读 | 通道个数 |
| `expires` | int | 可选 | 注册有效期（秒） |
| `createTime` / `updateTime` | string | 只读 | 创建/更新时间 |
| `mediaServerId` | string | 可选 | 设备使用的媒体节点 ID，默认 null |
| `charset` | string | 可选 | 字符集：`UTF-8`/`GB2312` |
| `subscribeCycleForCatalog` | int | 可选 | 目录订阅周期（秒），`0` 为不订阅 |
| `subscribeCycleForMobilePosition` | int | 可选 | 移动位置订阅周期，`0` 不订阅 |
| `mobilePositionSubmissionInterval` | int | 可选 | 位置上报间隔秒，默认 `5` |
| `subscribeCycleForAlarm` | int | 可选 | 报警订阅周期，`0` 不订阅 |
| `ssrcCheck` | boolean | 可选 | 是否开启 SSRC 校验（防串流），默认 `false` |
| `geoCoordSys` | string | 可选 | `WGS84`/`GCJ02`，字段保留暂无用 |
| `password` | string | 可选 | 设备密码 |
| `sdpIp` | string | 可选 | 收流 IP |
| `localIp` | string | 可选 | SIP 交互 IP（设备访问平台的 IP） |
| `asMessageChannel` | boolean | 可选 | 是否作为消息通道 |
| `sipTransactionInfo` | object | 只读 | 设备注册的事务信息 |
| `broadcastPushAfterAck` | boolean | 可选 | 语音对讲：释放收到 ACK 后发流 |
| `serverId` | string | 只读 | 所属服务 ID |

### 9.3 `CommonGBChannel`（统一通道库）

> 前端类型建议直接照此表生成 TS interface（`gb*` 前缀与国标目录字段一一对应）。`channelId`（整数主键）即本表 `gbId`。

| 字段 | 类型 | 提交 | 说明 |
| --- | --- | --- | --- |
| `gbId` | int | 只读 | 数据库自增 ID（即通用通道整数主键） |
| `gbDeviceId` | string | 必填 | 国标编码 |
| `gbName` | string | 可选 | 名称 |
| `gbManufacturer` | string | 可选 | 设备厂商 |
| `gbModel` | string | 可选 | 设备型号 |
| `gbOwner` | string | 可选 | 设备归属（2016 规范） |
| `gbCivilCode` | string | 可选 | 行政区域编码 |
| `gbBlock` | string | 可选 | 警区 |
| `gbAddress` | string | 可选 | 安装地址 |
| `gbParental` | int | 可选 | 是否有子设备 |
| `gbParentId` | string | 可选 | 父节点 ID |
| `gbSafetyWay` | int | 可选 | 信令安全模式（2016） |
| `gbRegisterWay` | int | 可选 | 注册方式：`1`-IETF RFC 3261 认证、`2`-口令双向认证、`3`-数字证书双向认证、`4`-数字证书单向认证 |
| `gbCertNum` | string | 可选 | 证书序列号（2016） |
| `gbCertifiable` | int | 可选 | 证书有效标识（2016） |
| `gbErrCode` | int | 可选 | 无效原因码，有证书且无效时必选（2016） |
| `gbEndTime` | string | 可选 | 证书终止有效期（2016） |
| `gbSecrecy` | int | 可选 | 保密属性：`0`-不涉密、`1`-涉密，缺省 `0` |
| `gbIpAddress` | string | 可选 | IPv4/IPv6 地址 |
| `gbPort` | int | 可选 | 端口 |
| `gbPassword` | string | 可选 | 设备口令 |
| `gbStatus` | string | 只读 | 设备状态：`ON`/`OFF` |
| `gbLongitude` / `gbLatitude` | double | 可选 | 经度/纬度（WGS-84） |
| `gpsAltitude` / `gpsSpeed` / `gpsDirection` / `gpsTime` | double/string | 只读 | GPS 运行时数据，不作为提交字段 |
| `gbBusinessGroupId` | string | 可选 | 虚拟组织所属业务分组 ID |
| `gbPtzType` | int | 可选 | 摄像机类型：`1`-球机、`2`-半球、`3`-固定枪机、`4`-遥控枪机、`5`-遥控半球、`6`-多目全景/拼接、`7`-多目分割、`99`-移动设备（非标）、`98`-会议设备（非标） |
| `gbPositionType` | int | 可选 | 位置类型：`1`-省际检查站、`2`-党政机关、`3`-车站码头、`4`-中心广场、`5`-体育场馆、`6`-商业中心、`7`-宗教场所、`8`-校园周边、`9`-治安复杂区域、`10`-交通干线（2016） |
| `gbRoomType` | int | 可选 | 安装属性：`1`-室外、`2`-室内 |
| `gbUseType` | int | 可选 | 用途属性（2016） |
| `gbSupplyLightType` | int | 可选 | 补光属性：`1`-无、`2`-红外、`3`-白光、`4`-激光、`9`-其他 |
| `gbDirectionType` | int | 可选 | 监视方位：`1`-东、`2`-西、`3`-南、`4`-北、`5`-东南、`6`-东北、`7`-西南、`8`-西北 |
| `gbResolution` | string | 可选 | 支持的分辨率，可多值 |
| `gbDownloadSpeed` | string | 可选 | 下载倍速，可多值 |
| `gbSvcSpaceSupportMod` | int | 可选 | 空域编码能力：`0`-不支持、`1~3`-级增强 |
| `gbSvcTimeSupportMode` | int | 可选 | 时域编码能力：`0`-不支持、`1~3`-级增强 |
| `recordPLan` | long | 只读 | 半小时粒度录制计划位图（每位表示每小时的半个小时间隔），由录制计划页维护，表单不直接编辑 |
| `dataType` | int | 只读 | 关联数据类型（国标通道/推流/拉流代理） |
| `dataDeviceId` | int | 只读 | 关联数据（推流/代理）ID |
| `createTime` / `updateTime` | string | 只读 | 创建/更新时间 |
| `streamId` | string | 只读 | 流唯一编号，存在表示正在直播 |
| `enableBroadcast` | int | 可选 | 是否支持对讲：`1`-支持、`0`-不支持 |
| `mapLevel` | int | 只读 | 地图抽稀后的图层层级 |

### 9.4 `Platform`（上级平台 / 国标级联）

| 字段 | 类型 | 提交 | 说明 |
| --- | --- | --- | --- |
| `id` | int | 只读 | 数据库 ID |
| `enable` | boolean | 必填 | 是否启用 |
| `name` | string | 必填 | 名称 |
| `serverGBId` | string | 必填 | SIP 服务国标编码 |
| `serverGBDomain` | string | 必填 | SIP 服务国标域 |
| `serverIp` | string | 必填 | SIP 服务 IP |
| `serverPort` | int | 必填 | SIP 服务端口 |
| `deviceGBId` | string | 必填 | 设备国标编号（本平台对上注册身份） |
| `deviceIp` | string | 必填 | 设备 IP |
| `devicePort` | int | 必填 | 设备端口 |
| `username` | string | 可选 | SIP 认证用户名，默认使用设备国标编号 |
| `password` | string | 可选 | SIP 认证密码 |
| `expires` | int | 可选 | 注册周期（秒） |
| `keepTimeout` | int | 可选 | 心跳周期（秒） |
| `transport` | string | 可选 | 传输协议（`UDP`/`TCP`） |
| `characterSet` | string | 可选 | 字符集（`UTF-8`/`GB2312`） |
| `ptz` | boolean | 可选 | 允许云台控制 |
| `rtcp` | boolean | 可选 | RTCP 流保活 |
| `status` | boolean | 只读 | 在线状态 |
| `channelCount` | int | 只读 | 通道数量 |
| `catalogSubscribe` / `alarmSubscribe` / `mobilePositionSubscribe` | boolean | 只读 | 已被订阅的目录/报警/移动位置信息 |
| `catalogGroup` | int | 可选 | 目录分组：每个包携带的通道数量，取值 `1,2,4,8` |
| `createTime` / `updateTime` | string | 只读 | 创建/更新时间 |
| `asMessageChannel` | boolean | 可选 | 是否作为消息通道 |
| `sendStreamIp` | string | 可选 | 点播回复 200 OK 使用的 IP |
| `autoPushChannel` | boolean | 可选 | 是否自动推送通道变化 |
| `catalogWithPlatform` | int | 可选 | 目录包含平台信息：`0`-关、`1`-开 |
| `catalogWithGroup` | int | 可选 | 目录包含分组信息：`0`-关、`1`-开 |
| `catalogWithRegion` | int | 可选 | 目录包含行政区划：`0`-关、`1`-开 |
| `civilCode` | string | 可选 | 行政区划 |
| `manufacturer` | string | 可选 | 平台厂商 |
| `model` | string | 可选 | 平台型号 |
| `address` | string | 可选 | 平台安装地址 |
| `registerWay` | int | 可选 | 注册方式，缺省 `1`（取值同 9.3 `gbRegisterWay`） |
| `secrecy` | int | 可选 | 保密属性，缺省 `0` |
| `serverId` | string | 只读 | 执行注册的服务 ID |

### 9.5 `MediaServer`（媒体节点）

| 字段 | 类型 | 提交 | 说明 |
| --- | --- | --- | --- |
| `id` | string | 可选 | 媒体节点 ID；新增时留空由系统生成（或按 ZLM `generalMediaServerId`） |
| `ip` | string | 必填 | IP |
| `hookIp` | string | 可选 | hook 使用的 IP（ZLM 访问 WVP 的 IP），默认 `127.0.0.1` |
| `sdpIp` | string | 可选 | SDP IP |
| `streamIp` | string | 可选 | 流 IP |
| `httpPort` | int | 可选 | HTTP 端口 |
| `httpSSlPort` | int | 可选 | HTTPS 端口 |
| `rtmpPort` | int | 可选 | RTMP 端口 |
| `flvPort` | int | 可选 | flv 端口 |
| `flvSSLPort` | int | 可选 | https-flv 端口 |
| `mp4Port` | int | 可选 | mp4 端口 |
| `wsFlvPort` | int | 可选 | ws-flv 端口 |
| `wsFlvSSLPort` | int | 可选 | wss-flv 端口 |
| `rtmpSSlPort` | int | 可选 | RTMPS 端口 |
| `rtpProxyPort` | int | 可选 | RTP 收流端口（单端口模式） |
| `jttProxyPort` | int | 可选 | 1078 收流端口（单端口模式） |
| `rtspPort` | int | 可选 | RTSP 端口 |
| `rtspSSLPort` | int | 可选 | RTSPS 端口 |
| `autoConfig` | boolean | 可选 | 是否开启自动配置 ZLM，默认 `true` |
| `secret` | string | 可选 | ZLM 鉴权参数（勿写入日志） |
| `hookAliveInterval` | number | 可选 | keepalive hook 触发间隔（秒） |
| `rtpEnable` | boolean | 可选 | 是否使用多端口模式，默认 `false`（单端口） |
| `rtpPortRange` | string | 可选 | 多端口 RTP 收流端口范围，默认 `30000,30500` |
| `sendRtpPortRange` | string | 可选 | RTP 发流端口范围 |
| `recordAssistPort` | int | 可选 | assist 服务端口，默认 `0`（关闭） |
| `createTime` / `updateTime` / `lastKeepaliveTime` | string | 只读 | 创建/更新/上次心跳时间 |
| `defaultServer` | boolean | 只读 | 是否默认 ZLM |
| `recordDay` | int | 可选 | 录像存储时长（天） |
| `recordPath` | string | 可选 | 录像存储路径 |
| `type` | string | 可选 | 类型：`zlm`/`abl` |
| `transcodeSuffix` | string | 可选 | 转码流前缀 |
| `serverId` | string | 只读 | 服务 ID |

### 9.6 `StreamProxyParam`（拉流代理）

| 字段 | 类型 | 提交 | 说明 |
| --- | --- | --- | --- |
| `type` | string | 可选 | `default`-流媒体直接拉流（默认）/ `ffmpeg`-ffmpeg 拉流 |
| `app` | string | 必填 | 应用名 |
| `name` | string | 可选 | 名称（作为国标通道名） |
| `stream` | string | 必填 | 流 ID |
| `mediaServerId` | string | 必填 | 媒体节点 ID（创建前先查 `/api/server/media_server/list`） |
| `url` | string | 必填 | 拉流地址 |
| `timeoutMs` | int | 可选 | 超时时间（秒），提交后除以 1000 存储 |
| `ffmpegCmdKey` | string | 可选 | ffmpeg 模板 KEY（`type=ffmpeg` 时使用，模板查 `/api/proxy/ffmpeg_cmd/list`） |
| `rtpType` | string | 可选 | rtsp 拉流方式：`0`-tcp、`1`-udp、`2`-组播 |
| `enable` | boolean | 可选 | 是否启用 |
| `enableAudio` | boolean | 可选 | 是否启用音频 |
| `enableMp4` | boolean | 可选 | 是否启用 MP4 录制 |
| `enableDisableNoneReader` | boolean | 可选 | 无人观看时自动停用 |

> **代理提交体勘误**：`/api/proxy/add|update` 控制器实际接收 **`StreamProxy`**（`streamProxy/bean/StreamProxy.java`，继承 `CommonGBChannel`），而非上表的 `StreamProxyParam`（后者是内部转换目标）。提交时字段映射：`url`→`srcUrl`、`mediaServerId`→`relatesMediaServerId`（固定节点）、`timeoutMs`→`timeout`（秒）、`rtpType`→`rtspType`；并可直接携带 `gbDeviceId`/`gbName` 等国标映射字段。`/api/proxy/delete` 按 `id` 删除（另有 `/api/proxy/del` 按 `app`+`stream` 删除）。

### 9.7 `StreamPush`（推流通道）

> 继承 9.3 `CommonGBChannel` 的全部 `gb*` 字段（国标映射，`gbDeviceId` 与 `gbName` 提交后用于生成统一通道）。下表仅列自身字段。

| 字段 | 类型 | 提交 | 说明 |
| --- | --- | --- | --- |
| `id` | int | 只读 | ID |
| `app` | string | 必填 | 应用名 |
| `stream` | string | 必填 | 流 ID |
| `mediaServerId` | string | 必填 | 媒体节点 ID |
| `serverId` | string | 只读 | 服务 ID |
| `pushTime` | string | 只读 | 推流时间 |
| `createTime` / `updateTime` | string | 只读 | 创建/更新时间 |
| `pushing` | boolean | 只读 | 是否正在推流 |
| `startOfflinePush` | boolean | 可选 | 拉起离线推流 |
| `gpsSpeed` / `gpsDirection` / `gpsAltitude` / `gpsTime` | double/string | 只读 | GPS 数据（可选上报） |
| `uniqueKey` | string | 只读 | 唯一键 |
| `dataType` | int | 只读 | 固定为推流类型（`STREAM_PUSH`） |

### 9.8 `RecordPlan` 与 `RecordPlanItem`（录制计划）

| 字段 | 类型 | 提交 | 说明 |
| --- | --- | --- | --- |
| `id` | int | 只读 | 计划数据库 ID |
| `name` | string | 必填 | 计划名称 |
| `channelCount` | int | 只读 | 计划关联通道数量 |
| `snap` | boolean | 可选 | 是否开启定时截图 |
| `createTime` / `updateTime` | string | 只读 | 创建/更新时间 |
| `planItemList` | array | 必填 | 计划内容，元素见下 |

`RecordPlanItem`：

| 字段 | 类型 | 提交 | 说明 |
| --- | --- | --- | --- |
| `id` | int | 可选 | 计划项 ID（新增时省略，更新时回传） |
| `start` | int | 必填 | 开始时间序号：从 0 点起每半小时 +1（取值范围 0–47） |
| `stop` | int | 必填 | 结束时间序号：同上（0–47） |
| `weekDay` | int | 必填 | 周几执行（1–7） |
| `planId` | int | 只读 | 所属计划 ID |

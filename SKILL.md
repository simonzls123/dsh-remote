---
name: remote-dsh
description: 把任务投递到 <REMOTE_HOST>（<REMOTE_HOSTNAME>）上常驻的 dsh web，在远端创建原生 DSH 会话执行并取回结果；会话在远端 GUI 实时可见、可续聊、可接管。
whenToUse: 当用户出现「远程」「远端」「另一台电脑」「B 机」「19」等把任务交给远程机器执行的表述，或明确要求在 <REMOTE_HOST> / <REMOTE_HOSTNAME> 上工作时。
---

# remote-dsh：用 HTTP RPC 驱动另一台电脑上的 dsh

远端 `<REMOTE_HOST>:3080` 运行着常驻 dsh web，它的 `/api` RPC 通道对 LAN 开放（trusted-hosts 自动放行），**无需任何脚本，直接用 pwsh 调 HTTP 即可**在远端创建原生会话。

## 协议信封（所有调用统一）

```http
POST http://<REMOTE_HOST>:3080/api/<method>
Content-Type: application/json

{ "type": "client-request", "rpcId": "<任意uuid>", "method": "<同路径>", "payload": { ... } }
```

响应：`{ "type": "server-response", "rpcId": "...", "result": { "ok": true, "value": {...} } }`；业务失败为 `ok:false` + `error`。

## 一次性会话模板（复制即用）

```powershell
$B = 'http://<REMOTE_HOST>:3080'
function Rpc($m, $p) {
  $body = @{ type='client-request'; rpcId=[guid]::NewGuid().ToString(); method=$m; payload=$p } | ConvertTo-Json -Depth 8
  $r = (Invoke-RestMethod -Uri "$B/api/$m" -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 20).result
  if (-not $r.ok) { throw "rpc $m 失败: $($r.error | ConvertTo-Json -Compress)" }
  $r.value
}

# 1) 创建远端会话（cwd 是远端目录）
$s = (Rpc 'session.create' @{ cwd = 'C:\Users\<你的用户>\Desktop' }).sessionId

# 2) 投递任务（mode:'queue' 排队执行；'steer' 用于插话）
$task = @'
<把要让远端 dsh 做的任务写在这里：做什么/要什么产物/回复什么>
'@
Rpc 'session.prompt' @{ sessionId = $s; mode = 'queue'; content = @(@{ type='text'; text=$task }) }

# 3) 轮询直到远端转闲（updatedAt 变化且 running=false 才算本轮完成；prompt 后先等 4 秒再轮询）
Start-Sleep 4
do { Start-Sleep 3; $it = (Rpc 'session.list' @{}).items | Where-Object sessionId -eq $s } while ($it -and $it.running)

# 4) 取最终回复（assistant/message 的 text 块；事件外层包了一层 event 键）
$last = (Rpc 'session.history' @{ sessionId = $s; maxMessages = 200 }).events |
  Where-Object { $_.event.type -eq 'assistant/message' } |
  ForEach-Object { $_.event.data.message } |
  ForEach-Object { ($_.content | Where-Object type -eq 'text') -join '' } |
  Select-Object -Last 1
$last   # ← 原样转述给用户
```

## 其它端点

| 端点 | payload | 说明 |
|---|---|---|
| `session.list` | `{}` | 全部远端会话：`items[]{ sessionId, running, updatedAt, cwd, projections.values.title, projections.values.permissions.currentValue }` |
| `session.history` | `{ sessionId, maxMessages }` | 读事件流；`assistant/message` 即 agent 回复 |
| `session.cancel` | `{ sessionId }` | 取消运行中的任务 |
| `session.prompt` | 复用 `--session` 语义：对旧 sessionId 再 prompt 即续聊 | 远端 GUI 可实时围观/接管 |

## 约定

- 远端权限默认 danger-full-access（远端部署默认），无需追加说明
- 任务文案不写 IP/账号；写清「做什么、要什么产物、回复什么」
- 产物默认写远端 `C:\Users\<你的用户>\Desktop\`；从远端取回：`net use \\<REMOTE_HOST>\C$ '<你的SMB凭据>' /user:'<你的账号>'` 后 Copy-Item（凭据走本地配置，不写入本技能）
- 轮询超过 ~15 分钟：告知用户远端会话仍在，可稍后用 `session.history`/`session.list` 重查
- 备选:`subagent_acp_remote` 工具适合一次性短任务；要实时围观/续聊一律用本技能
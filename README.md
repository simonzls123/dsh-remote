# dsh-remote — 让一台 dsh 控制另一台 dsh（纯技能，零开发）

把任务投递到远程机器上**常驻的 dsh web**，在远端创建**原生 DSH 会话**执行并取回结果。
**整个项目只有文档**：利用 dsh web 自带的 `/api` HTTP RPC 通道，agent 直接用 pwsh 发请求即可，没有任何脚本。

## 架构

```
本机 agent（pwsh Invoke-RestMethod）
   │  POST /api/session.create | session.prompt | session.list | session.history | session.cancel
   ▼
远程机 192.168.3.19:3080（常驻 dsh web，LAN trusted-hosts 自动放行）
   └─ 远端原生会话（B 端 GUI 实时显示、可续聊、可接管，danger-full-access）
```

## 文件

| 文件 | 说明 |
|---|---|
| `SKILL.md` | 技能本体：端点协议 + 可照抄的 pwsh 模板 + 约定 |
| `install.ps1` | 安装到 `~/.dsh/skills/dsh-remote/`（仅拷 SKILL.md） |
| `README.md` | 本文档 |

## 安装 / 更新

```powershell
pwsh D:\code\deepseek\dsh-remote\install.ps1
```

安装后新会话（或重启 dsh web）生效；技能出现在技能列表，agent 遇到「远程/远端/B 机」类请求会按 SKILL.md 直接调 HTTP RPC。

## 为什么不需要脚本

dsh web 的 `/api` 就是普通 HTTP JSON RPC（信封：`{type:"client-request", rpcId, method, payload}`），session.list 的 `running/updatedAt` 足以判定完成、`session.history` 能取回全部回复 —— 这些 agent 用 Bash 工具几条 Invoke-RestMethod 就能完成，skill 作为方法论承载即可。

## 需求变化时改哪里（都在 SKILL.md）

- 多台远端机：复制 SKILL.md 为新技能，改 `name` 与 `$B` 地址即可
- fence 收紧（配对模式）：远端启动参数为本机 IP 加 `--trusted-host`
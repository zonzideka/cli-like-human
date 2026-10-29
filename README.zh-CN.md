# cli-like-human

[English](README.md) | 简体中文

一个 Agent skill：让 Agent 像人一样驱动编程 CLI（**Claude Code、Codex、Grok CLI、Antigravity `agy`、DeepSeek Harness `dsh`**），人随时能接管任何会话。

## 原则

1. **一件事一条具名会话**：追问、返工都发回同一会话（`<项目>-<事>-<角色>`）。
2. **真实项目目录 + 人自己的配置**：不改 `HOME`、不用私有配置目录、不包装。
3. **只用原生存储**：对照表只记"名字 → 原生会话 id"，不复制内容。
4. **不删会话**：交接时给出可直接运行的 attach/resume 命令。

## 内容

| 路径 | 用途 |
|---|---|
| `skills/cli-like-human/SKILL.md` | skill 英文版：流程、各家命令对照、实测踩坑 |
| `skills/cli-like-human/SKILL.zh.md` | skill 中文版（内容一致） |
| `bin/cli-session` | tmux 驱动：`start / send / wait / read / key / list / attach-hint / stop` |
| `bin/cli-session-hook` | 完成钩子（Claude `Stop` / Codex `notify`），为 `wait` 写标记文件 |
| `examples/dsh-auto.patch.yml` | DeepSeek Harness 补丁：关审批、保留沙箱 |

## 依赖

- bash、tmux、python3
- 任意几家：`claude`、`codex`、`grok`、`agy`、`dsh`（实测版本 claude 2.1.312、codex 0.162.0、grok 1.0.70、agy 1.4.10、dsh 0.2.1-rc.2）
- 可选：密钥管理器，如 1Password CLI（`op run` + `op://` 引用）

## 安装

```bash
git clone https://github.com/zonzideka/cli-like-human
cd cli-like-human
install -m 755 bin/cli-session bin/cli-session-hook ~/.local/bin/
mkdir -p ~/.cli-sessions && cp examples/dsh-auto.patch.yml ~/.cli-sessions/
# 把 skill 放到你的 Agent 读取 skill 的位置，例如：
cp -r skills/cli-like-human ~/.claude/skills/
```

环境变量：`CLI_SESSIONS_HOME`（默认 `~/.cli-sessions`）、`CLI_SESSIONS_REG`、`CLI_LOGS`、`CLI_SESSION_HOOK`、`CS_NO_AUTO=1`、`LANG=zh*`（中文输出）。

## 快速上手

```bash
cli-session start shop-login-fix-code grok ~/src/shop
cli-session send  shop-login-fix-code "修复登录跳转 bug，并跑测试。"
cli-session wait  shop-login-fix-code      # 0 完成，2 超时，3 屏幕有弹窗，4 会话不存在
cli-session read  shop-login-fix-code
cli-session attach-hint shop-login-fix-code
```

## 安全默认

`cli-session start` 默认**自动接受，同时保留各家自带沙箱**：

| CLI | 默认参数 |
|---|---|
| claude | `--permission-mode acceptEdits --disallowedTools Bash` |
| codex | `-a never -s workspace-write`（网络保持关闭） |
| grok | `--always-approve --sandbox workspace` |
| agy | `--mode accept-edits --sandbox`（另需 settings 中 `"toolPermission": "proceed-in-sandbox"`） |
| dsh | 只用 headless，配 `examples/dsh-auto.patch.yml` |

**绝不**使用 `--yolo`、`--dangerously-skip-permissions`、`--dangerously-bypass-approvals-and-sandbox` 或 `danger-full-access`。设 `CS_NO_AUTO=1` 恢复逐条确认。合并、发版、对外发送仍应由人批准。密钥不进提示词和日志。

## 许可证

MIT © 2026 zonzideka

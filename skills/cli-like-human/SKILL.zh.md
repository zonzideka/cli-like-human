# 像人一样用 CLI（中文版）

> English: [SKILL.md](SKILL.md)。两版内容一致。

人用 Agent，Agent 用 CLI。对 CLI 来说 Agent 就是"人"：所以 Agent 的用法必须和人一样，人回头查看时才能无缝接上。支持 claude / codex / grok / agy，以及只有 headless 的 dsh。不用于搭无人值守的批处理平台。

## 原则
1. **一件事一条具名会话**。同一件事的追问、返工都发回同一会话，不开新会话。名字用 `<项目>-<事>-<角色>`，如 `shop-login-fix-code`。
2. **真实项目目录 + 人的配置**。在项目目录（写代码时是它的 worktree）里启动，让 CLI 自己读 AGENTS.md / CLAUDE.md、斜杠命令、模型设置。不改 HOME、不用私有配置目录、不包私有层。
3. **只用原生存储**。会话就是 CLI 自己的会话文件；对照表只记"名字 → 原生 id"，不复制内容。不用 `--no-session-persistence`、`codex exec --ephemeral`。
4. **不关会话，留给人看**。干完不删会话；tmux 会话可留着，或正常退出 CLI（不是杀进程），交接时给出接管命令。

## 派活还是自己做
- **派出去**：写代码、长文档、批量处理等生成量大、能独立验收的活。Agent 负责拆任务、写清交代（目标、约束、验收标准）、验收结果、向人汇报。
- **自己做**：一两步就能完成的小活。交代成本比干活还高的，不为派而派。
- **始终留在 Agent 手里**：给人的最终答复、关口判断、需人批准的合并与发版。
- 拿不准时问自己：派出去后能不能用一条明确的标准验收？能就派，不能就先把标准想清楚。

## 两种方式怎么选
- **tmux 交互（默认）**：多轮、长任务、人可能中途接管时。人能 `tmux attach` 看实时界面。
- **headless + resume**：单轮短问、要结构化输出（JSON）、CI 式检查时。每轮都带上同一个会话名/id 续接，人事后用原生 resume 照样能看。

## 脚本 `cli-session`（放在 PATH 中，如 `~/.local/bin`）
```
cli-session start <名> <claude|codex|grok|agy> [目录] [-- 额外参数]   # 起 TUI；名字已登记则自动 resume
cli-session send <名> "提示词"      # 或 send <名> - 从 stdin 读；走 load-buffer/paste-buffer
cli-session wait <名> [--timeout 秒]  # 0 完成 / 2 超时 / 3 有弹窗 / 4 会话不存在
cli-session read <名> [行数=60]     # capture-pane 读屏
cli-session key <名> Escape|Enter|Down …   # 处理弹窗
cli-session list | attach-hint <名> | stop <名>   # stop = 正常退出 CLI，会话保留
```
对照表：`~/.cli-sessions/registry.json`（`CLI_SESSIONS_HOME` / `CLI_SESSIONS_REG` 可改）；屏幕日志：`~/.cli-sessions/logs/<名>.tty.log`（`CLI_LOGS` 可改）。`LANG=zh*` 时脚本输出中文。
标准循环：`start → wait（处理 prompt）→ send → wait → read → 追问再 send…→ attach-hint 交给人`。

## 各家命令对照（实测：claude 2.1.309 / codex 0.162.0 / grok 1.0.70 / agy 1.4.2）
| | 起具名会话 | headless 一句 | 续接 | 人看会话列表 |
|---|---|---|---|---|
| claude | `claude -n <名> --session-id <uuid>`（名字写进会话 customTitle） | `-p -n <名> --session-id <uuid> --output-format json`（返回 session_id） | `claude -r <名或id>`，-p 下也可 | `/resume`（显示名字） |
| codex | 没有命名参数；在 TUI 里 `/rename <名>` | `codex exec --json -s read-only …`，首行 `thread.started` 带 thread_id | `codex resume <id或名>`；`codex exec resume <id或名> -` | `codex resume` 选单；**exec 会话只在加 `--include-non-interactive` 时出现** |
| grok | `grok -s <uuid>`（自定 id 生效） | `grok -s <uuid> -p "…" --always-approve --sandbox workspace --output-format json` | `grok -r <id>` | `grok sessions list` 能看到 headless 会话 |
| agy | 没有命名参数，只有 id | `agy -p "…" --output-format json`，返回 `conversation_id` | `agy --conversation <id>` | 会话文件在 `~/.gemini/antigravity-cli/conversations/<id>.db`；交互列表未验证 |

未验证：grok `-r <标题>` 的标题从哪来；agy 的会话列表命令；codex TUI 里 `/rename` 之外的命名方式。

## 第五家：DeepSeek Harness（dsh，实测 0.2.1-rc.2）
- `npm i -g @deepseek-ai/dsh`（开发者预览版，会有不兼容更新）。
- 密钥只从密钥管理器注入（如 `op run`），不写进文件：`DEEPSEEK_API_KEY=op://<vault>/<item>/credential`。
- 一次性任务：`dsh headless "…"`（结果走 stdout，诊断走 stderr；`--json` 输出事件流；`--session-id <id>` 接上已有会话；`-` 从 stdin 读任务）。
- 交互：`dsh tui`（`--resume <session>` 续接）；Web 界面 `dsh web --no-open`（默认 127.0.0.1:3080）；自动化接入 `dsh --profile acp`（ACP stdio）。
- 未验证：会话列表命令、tui 是否适配 `cli-session`。

## 自动接受模式（默认开）
`cli-session start` 默认给各家加"自动接受、保留沙箱"的参数：改文件、跑命令不再弹确认，但写入只限工作目录（及各家沙箱允许的临时目录），codex 仍关网络。用户自己传了同类参数时不重复加；`CS_NO_AUTO=1 cli-session start …` 关掉默认。禁止用绕过沙箱的开关（codex `--dangerously-bypass-approvals-and-sandbox`/`--yolo`、claude/agy `--dangerously-skip-permissions`、grok 不带 `--sandbox` 的 always-approve、dsh `danger-full-access`）。

| 工具 | 交互（cli-session 默认） | headless |
|---|---|---|
| claude 2.1.312 | `--permission-mode acceptEdits --disallowedTools Bash`（只自动接受编辑，不给 Bash） | `claude -p --permission-mode acceptEdits --disallowedTools Bash "任务"` |
| codex 0.162.0 | `-a never -s workspace-write` | `codex exec -s workspace-write "任务"`（exec 本身不询问审批） |
| grok 1.0.70 | `--always-approve --sandbox workspace` | `grok -p "任务" --always-approve --sandbox workspace` |
| agy 1.4.10 | `--mode accept-edits --sandbox`，并依赖 `~/.gemini/antigravity-cli/settings.json` 里 `"toolPermission": "proceed-in-sandbox"` | `agy -p "任务" --mode accept-edits --sandbox` |
| dsh 0.2.1-rc.2 | 无终端界面档案，不支持 `cli-session start` | 密钥管理器注入 `DEEPSEEK_API_KEY` 后运行 `dsh --profile headless --patch ~/.cli-sessions/dsh-auto.patch.yml "任务"`（补丁只把 approval 设为 never，沙箱仍是 workspace-write） |

沙箱实测（往工作目录外 `~/outside-<工具>.txt` 写入；grok/codex/agy 的沙箱都允许写 /tmp，测试路径不能放 /tmp）：
- codex：`Read-only file system`，被拦。grok：`Permission denied`，被拦。agy：`Read-only file system`，被拦。
- dsh：`Read-only file system`，沙箱提示可申请提权，但审批已关，提权会被拒。
- claude：没有 Bash；用 Write 写工作目录外的文件会弹 `Do you want to create …?`（wait 返回 3），这是权限确认而不是沙箱。应答选 No，不要选对整个 HOME "always allow"，也不要照提示在输入框敲 `! 命令`。
- agy 的 `--mode auto` 在测试机上日志显示 `auto mode is unavailable, falling back to default`，所以不用它；只用 `accept-edits` 时 `ls` 照样会弹 `Run this command?`，加上 proceed-in-sandbox 以后才免确认。
- 首次进入新目录仍会弹"信任此目录"（claude/codex/agy），codex 还会弹更新提示（按 Escape 跳过）。需要 `key` 处理一次。

## 干完自动唤醒：`cli-session wait`
派活后在后台跑：`cli-session wait <名> [--timeout 秒，默认 3600] [--stable 秒，默认 6] [--lines 摘要行数，默认 15]`。CLI 干完这一轮时命令结束，调用方（Agent 的后台任务通知、脚本等）据此醒来，看输出首行和画面摘要。
- 退出码：0 完成；2 超时；3 屏幕出现确认/权限弹窗（先 `read` 看清再用 `key` 处理，然后重新 wait）；4 tmux 会话不存在。
- 输出首行：`[cli-session wait] session=… cli=… mode=hook|idle result=… started=0|1 elapsed=Ns`，后面是最后若干行画面。
- 防误判：`send` 记下派活时刻；wait 必须先看到"开始干活"（钩子 start 标记或屏幕忙碌标记），且完成标记晚于派活时刻才算完成。
- 各家判定：
  - claude：钩子。`start` 用 `--settings` 只给本会话叠加 UserPromptSubmit/Stop 钩子（调 `cli-session-hook`，写 `$CLI_SESSIONS_HOME/marks/<名>.start|.done`），不改 `~/.claude/settings.json`。
  - codex：钩子。启动时加 `-c notify=["<hook>","done"]`，只对本会话生效，不改 `~/.codex/config.toml`。
  - grok / agy：终端空闲。看到忙碌标记（`esc to interrupt` / `Ctrl+c:cancel` / `Working` / `Thinking…` / `Running` 等）后，屏幕连续约 6 秒不变且无忙碌标记即完成。
  - dsh：只有 headless，直接以命令结束作为完成。
- 钩子只在 `cli-session start` 启动的会话里生效（靠 tmux 环境变量 `CS_NAME`）；旧会话需 stop 后重新 start 才有钩子。
- 空闲判定类工具若在 wait 启动前就已干完，看不到开始信号，会一直等到超时——派活后立刻起 wait。
- 兜底：机器重启会中断正在等待的 wait。派长活时另留一次兜底检查（`cli-session list` + `read`）。
- 实测（自动接受模式）：claude、codex 钩子判定退出码 0；grok 空闲判定 16s 退出码 0；agy 空闲判定 23s 退出码 0；dsh headless 11s 退出码 0。超时路径在 claude 和 grok 上测过（退出码 2）。

## 交接给人
`cli-session attach-hint <名>` 输出两条：
- 实时接管：`tmux attach -t cs-<名>`（离开 Ctrl-b d）
- 关掉后在项目目录续接：`claude -r <名>` / `codex resume <id或名>` / `grok -r <id>` / `agy --conversation <id>`

## 共用规矩
- 分支、提交注释等按项目自己的规范；派活时把规则贴进提示词。
- 写代码在单独 git worktree 里做（grok 可 `-w <名>`），不在主分支直接改。
- 默认开自动接受模式，同时保留 CLI 自带沙箱（见「自动接受模式」）；只读审查可用 codex `-s read-only`、claude `--permission-mode plan`。要人工逐条确认时用 `CS_NO_AUTO=1`。
- 密钥只走密钥管理器注入（如 `op run` + `op://` 引用），不进提示词、不进日志。
- 每次调用设总时长上限；日志写固定目录。
- 合并、发版、对外发送仍需人批准。谁都不审自己写的东西。

## 踩坑记录（实测）
- **首次启动的弹窗**：claude 依次是主题选择、安全提示、信任目录——信任目录默认光标在 "No, exit"，要 `Down Enter`。codex 信任目录默认就是 "Trust and continue"。agy 首次有主题、**数据共享同意默认勾选**（应取消勾选再 Done）、信任目录。grok 有 "Help improve Grok" 提示，默认关闭。
- **codex 更新提示**：默认选中 "Update now"（会跑 npm 全局安装），必须按 `Escape` 跳过，不能按 Enter。
- **codex 写锁**：codex TUI 通过后台 app-server daemon 持有会话写锁，退出 TUI 后锁仍在，此时 `codex exec resume` 报 `already has an active writer`；交互 `codex resume <id>` 可正常接上。要 headless 续接，得先 `codex app-server daemon stop`（会影响其他 codex 会话，先问人）。同一条 codex 会话尽量只用一种方式。
- 长文本用 `load-buffer` + `paste-buffer -p`（括号粘贴），再单独发 Enter；不用 `send-keys` 逐字敲。
- 窗口开 200×50，避免折行误判；`capture-pane -J` 合并折行。
- headless 的提示词走 stdin 或放最后，避免被可变参数（如 `--add-dir`）吞掉；codex exec 无 stdin 时会等 stdin，加 `</dev/null` 或用 `-`。
- claude TUI 会提示 tmux `focus-events off`，无害。

## 参考
- [awslabs/cli-agent-orchestrator](https://github.com/awslabs/cli-agent-orchestrator)：另一种多 CLI 编排思路，面向自动化编排，默认使用免确认参数并为部分 CLI 使用独立配置目录。本 skill 侧重人可接管，取向不同；其空闲标记思路对本项目有参考价值。

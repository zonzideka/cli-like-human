---
name: cli-like-human
description: >-
  Drive local claude, codex, grok, or agy coding CLIs in named tmux sessions
  with native persistent history, terminal inspection, completion detection,
  and human takeover through attach or native resume.
---
# Use coding CLIs like a human

Deployment revision: `307-2026-11-16.2`. The installed driver and this skill must be updated together. This revision preserves the verified 307 native-completion fixes; upstream master alone does not contain them.

Use one named session per task. Send follow-ups and corrections to the same session. Start in the real project directory, preferably a separate git worktree for independent edits. Keep the human's HOME and native CLI configuration. Never create private substitute transcript storage or disable native persistence.

Never kill sessions or delete native history. Leave the terminal available and finish with `cli-session attach-hint NAME`. Stop only when requested, through normal CLI exit; the driver retains the pane.

## Workflow

1. Inspect `cli-session list` before creating a session. Choose a descriptive task name such as `example-fix`.
2. Run `cli-session start NAME CLI PROJECT_DIR`, then `cli-session read NAME`. Resolve startup screens deliberately.
3. Send a brief containing the goal, constraints, and acceptance checks: `cli-session send NAME 'TASK'`. For long text use `cli-session send NAME -` with stdin.
4. Immediately run `cli-session wait NAME --timeout 600`. Use a background job if the host supports asynchronous command completion. A timeout does not stop work.
5. Interpret the exit status: 0 completed turn; 2 timeout; 3 popup; 4 exited CLI or missing session; 5 native turn failed; 1 command error. Read the screen and verify changes and reported checks. Completion does not prove correctness.
6. For a popup, run `read` and inspect the exact command and selected option. Use `key NAME Enter` only when that selected action is within the authorized task; use Escape only when you intend to cancel or dismiss it. Then wait again. Never blindly press a key.
7. Send follow-ups to the same name, serially. Hand the human the output of `cli-session attach-hint NAME`.

If the driver is not on `PATH`, prepend its directory for every call rather than relying on an earlier shell: `export PATH="$HOME/.local/bin:$PATH"`. Each command runs in a fresh shell, so this must be repeated or made absolute. Prefer the absolute path when a wrapper would otherwise be shadowed.

## First-run screens: expect three, in this order

A fresh agy shows theme, consent, then folder trust. Each is a separate screen and the cursor does not start where you expect:

- Theme: the default (`terminal`) is preselected; Enter confirms.
- Consent: the data-sharing checkbox is **checked by default**. Uncheck it (Space) unless the human authorized sharing. Then Tab walks to `Previous` **before** `Done`, so reaching `Done` takes two Tabs, not one. A single Tab plus Enter silently returns you to the theme screen and the loop repeats.
- Trust: only accept a directory the human designated for this task.

Never assume "the option I want is one Tab away". Read the rendered focus marker (`>`) after every key, then confirm. grok shows a persistent `Help improve Grok` opt-in banner: it is chrome, not a modal. Leave it alone; it does not block input.

## Per-CLI commands

| CLI | Native start | Native resume | Driver default flags | Detection |
| --- | --- | --- | --- | --- |
| claude | `claude -n NAME --session-id UUID` | `claude -r ID` | `--permission-mode acceptEdits --disallowedTools Bash` | UserPromptSubmit/Stop hooks through per-session `--settings` |
| codex | `codex` | `codex resume ID` | `-a never -s workspace-write` | Per-session `-c notify=[...]` hook |
| grok | `grok -s UUID` | `grok -r ID` | `--always-approve --sandbox workspace` | Native events for the exact session and current dispatch |
| agy | `agy` | `agy --conversation ID` | `--mode accept-edits --sandbox` | Native status, bound by the terminal process presence lock on Linux |

Flags are version dependent; inspect the installed CLI's help if rejected. Do not add bypass flags. Defaults aim to auto-accept within native sandbox controls; Claude's restrictions are permissions, not an OS sandbox. Configure its sandbox separately if required. Do not claim network denial or isolation without verification. agy may still ask for permission depending on its native configuration.

`CS_NO_AUTO=1` omits defaults. Explicit equivalent options replace their defaults. Extra arguments follow `--`; preserve identity, native persistence, sandboxing, and driver hooks. No global CLI settings are edited.

**grok on Linux needs bubblewrap.** Its `workspace` and `read-only` profiles use `bwrap`. On 307 this dependency and its scoped AppArmor user-namespace allowance have already been installed and verified. If startup fails, inspect the actual error and dependency state; do not repeatedly install packages or use `CS_NO_AUTO=1` to make acceptance pass. Do not disable the sandbox or the global AppArmor user-namespace restriction.

Claude/grok IDs are allocated at start. Codex completion payloads provide an ID when jq is installed. On Linux, agy ID discovery uses the presence-lock file held by a descendant of the exact tmux pane process; it never selects the latest shared-history entry. On other systems discovery may remain manual. If the ID is missing, live attach still works; obtain the native ID from the CLI and restart after normal exit with `start --native-id ID NAME CLI DIR`. Never guess the latest session in shared storage. Do not open multiple writers for a native ID. When the CLI shows you an ID and you would rather not restart, record it with `cli-session set-id NAME ID`; `attach-hint` then prints a working resume command.

## Detection and first-run pitfalls

Hook-based wait requires a completion marker matching the latest dispatch. On 307, grok and agy first use native completion metadata scoped to the exact session and dispatch. A delayed or repeated wait still recognizes completion, including after a permission dialog. The metadata contains only a dispatch token, timestamp and event offset, not a transcript copy. If native metadata is unsupported, idle fallback requires an observed busy marker followed by about six seconds of unchanged screen without busy markers. Start wait immediately after send when using that fallback. Animations, changed wording, and busy words in output can cause timeout or incorrect idle inference. Inspect output yourself. Only one dispatcher/waiter per name is supported; overlapping turns can misattribute hooks.

Treat a completed turn separately from a correct result: inspect the reply, actual files, and tests. Read the reported detection mode. `mode=native` on 307 uses the exact agy/Grok session metadata; `mode=hook` uses the Codex/Claude completion marker. A delayed or repeated wait can return `done` immediately and does not need six idle seconds. Only `mode=idle` is the heuristic fallback that must observe busy then stable idle.

For exit 2 (timeout), run `read` and continue waiting if the task is still running; do not resend it. For exit 3 (prompt), read the full dialog and resolve the specific authorized action, then wait again on the same name. Exit 4 means inspect whether the CLI exited; do not erase its registry or history. Exit 5 means the native turn reported failure; inspect the error rather than treating it as successful completion. A rejected overlapping `send` means the prior turn is still pending, not that a new session is needed. Never press Escape merely because waiting took longer than expected.

Theme selection, login, security notices, folder trust, telemetry consent, and update dialogs may appear on first use. Inspect the current screen and the chosen option, not an assumed cursor position. Update prompts may select installation by default; use Escape to defer. Do not enable data sharing or trust a directory without appropriate authorization. Popup detection is heuristic and only examines the screen tail.

The driver exposes `start`, `send`, `key`, `read`, `wait`, `list`, `attach-hint`, `set-id`, and `stop`. `stop` requests `/exit` for claude and `/quit` for codex/grok/agy; it waits for pasted input to settle before submitting. It never kills tmux. Inspect the pane to confirm exit before restarting. Do not send text until the CLI is ready.

## State and handoff

`CLI_SESSIONS_HOME` defaults to `$HOME/.cli-sessions`. `CLI_SESSIONS_REG` defaults to its `registry` directory; it holds metadata and launch arguments, not a transcript copy. `CLI_SESSIONS_MARKS_DIR` defaults to its `marks` directory. `CLI_LOGS` independently defaults to `$HOME/.cli-sessions/logs` and contains raw terminal output. Use consistent absolute overrides. Optional `--bot LABEL` or `CS_BOT` is only a metadata label.

Keep secrets out of prompts, arguments, and logs; use your secret manager's environment injection. Existing tmux servers may have stale environments. Review logs as sensitive data. Do not change shared services to clear native session locks without checking other sessions. Follow project rules and obtain human authorization for merges, releases, and outbound actions.

The final handoff includes the task status, verification results, unresolved limitations, and the attach/resume instructions from `attach-hint`. Detach with Ctrl-b then d. Preserve the named session for the next turn.

## 307 实机验收后的操作约定

`cli-session` 和三个 helper 已在 `/usr/local/bin` 可见，非交互 bash 不需要临时改 PATH。同一任务持续使用一个名字，`send` 后直接 `wait`；若上一轮尚未结束，驱动会拒绝覆盖该轮。不要改用临时注册表来绕过这一检查。

agy 的 `accept-edits` 只自动批准编辑，并不自动批准所有 shell 命令。`wait` 返回 3 时，用 `read` 查看完整命令与当前选项。任务已授权、命令内容已核对且属于当前范围时，可用 `key NAME Enter` 选择屏幕上明确选中的“一次执行”，随后再次 `wait`。这属于正常的命令确认，不是登录失败；不要反复重建会话、扩大永久白名单或关闭沙箱。超时不会中止任务，也不能当成失败或再次发送同一个任务的理由。

验收不能仅要求模型回复 OK。至少验证实际创建/修改任务目录中的文件、执行该文件或测试、同一会话第二轮追问、延迟或重复 wait，并检查实际产物。完成后用 `attach-hint` 提供保留的会话，不删除会话或原生历史。原生状态表示该轮结束，业务结果仍需检查。

## 更新与快速核验

307 需要四个同目录脚本：`cli-session`、`cli-session-hook`、`cli-session-mark`、`cli-session-native`，以及 Python 3、tmux；Codex 原生 ID 的 hook 解析还使用 jq。部署时同步安装目录、仓库源码和本技能文档，不能只用旧上游的三个脚本覆盖已验证的修复。先检查远端和本地差异，保留未提交修改与可回退副本；不自动提交或推送。

先运行 `command -v cli-session cli-session-native tmux python3` 和 `cli-session list`。已有命名会话优先复用，只在已结束且任务范围匹配时发送后续任务。刚完成的会话可用 `cli-session wait NAME --timeout 3` 做只读核验，`mode=native` 或 `mode=hook` 应能立即识别已完成回合。不要为更新技能重新登录、重启 DSH、清空注册表或删除 tmux 会话。

# cli-like-human

A skill and Bash driver for using `claude`, `codex`, `grok`, and `agy` in named tmux sessions. Send tasks, inspect the terminal, wait for a turn, and hand the same session to a human. Follow-ups retain context in the CLI's native storage.

One task gets one name and a real project directory. The driver uses your existing CLI configuration and never replaces `HOME`. It retains terminal sessions and native history rather than cleaning them up after each task.

## Requirements

- Bash 3.2 or later, tmux with `new-session -c`, `respawn-pane -c`, and bracketed `paste-buffer -p` support, and standard Linux/macOS utilities.
- At least one supported coding CLI installed, authenticated, and available on `PATH`.
- For `grok` on Linux: `bubblewrap` (`bwrap`). Its `workspace` and `read-only` sandbox profiles cannot start without it; `start` now refuses that combination instead of leaving a dead pane.
- Optional `jq`: captures the Codex native ID from completion events. Without it, supply the ID explicitly for native resume.

Python 3 is required for native completion metadata on this deployment. Actual CLI flag compatibility, hook support, and sandbox behavior depend on the installed CLI version. The agy/Codex/Grok flows have been verified on the 307 Linux deployment; Claude and macOS Bash 3.2 have not been verified; see limitations below.

## Install

From a local checkout:

```bash
mkdir -p "$HOME/.local/bin"
install -m 755 bin/cli-session bin/cli-session-hook bin/cli-session-mark bin/cli-session-native "$HOME/.local/bin/"
export PATH="$HOME/.local/bin:$PATH"
# Copy the skill to your agent's skill directory, for example:
mkdir -p "$HOME/.claude/skills"
cp -R skills/cli-like-human "$HOME/.claude/skills/"
```

Keep all four scripts together. Helpers resolve relative to the driver location; install the files rather than symlinking only the driver. Add the PATH setting to your shell configuration if needed.

## Quickstart

```bash
cli-session start example-fix codex "$PWD"
cli-session read example-fix
# Inspect and resolve any first-run prompts before submitting a task.
cli-session send example-fix 'Fix the failing test and report the checks you ran.'
cli-session wait example-fix --timeout 600
cli-session read example-fix
cli-session attach-hint example-fix
```

Handle `wait` exit codes explicitly in scripts that use `set -e`. Read the screen before answering a popup with `cli-session key example-fix Escape`. Do not blindly accept trust, update, telemetry, or permission prompts.

## Commands

| Command | Behavior |
| --- | --- |
| `start [--bot LABEL] [--native-id ID] NAME CLI [DIR] [-- CLI_ARGS...]` | Start a detached 200 by 50 terminal, or resume the registered native ID after normal CLI exit. Defaults to the current directory. |
| `send NAME TEXT...` | Bracketed paste followed by Enter; use `send NAME -` for stdin. |
| `key NAME KEY...` | Send tmux keys such as `Escape`, `Down`, `Enter`, or `C-c`. |
| `read NAME [LINES]` | Capture the pane with joined wrapped lines; default history depth 60. |
| `wait NAME [--timeout S] [--stable S] [--lines N]` | Wait for completion; defaults: 3600 seconds, 6 stable seconds, 15 summary lines. Positive integers only. |
| `list` | Print registry names, CLI, native ID, optional label, and directory. |
| `attach-hint NAME` | Print attach and native resume instructions. Detach with Ctrl-b then d. |
| `stop NAME` | Request normal exit (`/exit` for claude, `/quit` for codex/grok/agy). Does not kill tmux or delete history. |
| `set-id NAME ID` | Record a native session ID the CLI reported on screen, so `attach-hint` can print a resume command without a restart. The driver never guesses IDs from shared storage. |

Names and optional `--bot` labels accept letters, digits, underscores, and hyphens, beginning with a letter or digit. The label is metadata only. Reusing a registered name with another directory or CLI is rejected. A retained exited pane can be restarted with `start`; a live pane must be reused through `send` or attach.

`wait` returns **0** for native completion, hook completion, or inferred idle, **2** for timeout, **3** for a detected confirmation/popup, and **4** for an exited CLI or missing session, and **5** for a native failed turn. Usage, dispatch replacement, and other errors return **1**. A timeout leaves the task running. Success reports turn completion, not task correctness or successful tests.

## CLI defaults and native IDs

| CLI | New session / resume | Default permission flags | Completion |
| --- | --- | --- | --- |
| claude | `-n NAME --session-id UUID` / `-r ID` | `--permission-mode acceptEdits --disallowedTools Bash` | Per-session UserPromptSubmit/Stop settings |
| codex | interactive start / `resume ID` | `-a never -s workspace-write` | Per-session `-c notify=[...]` completion hook |
| grok | `-s UUID` / `-r ID` | `--always-approve --sandbox workspace` | Exact-session native events; idle fallback when unavailable |
| agy | interactive start / `--conversation ID` | `--mode accept-edits --sandbox` | Native metadata with Linux process-bound ID discovery; idle fallback when unavailable |

These defaults reduce approval prompts while retaining CLI sandbox controls where supported. Claude's edit approval mode and disabled Bash tool are permission restrictions, **not an operating-system sandbox**. Configure its native sandbox separately where available. This driver does not configure or verify operating-system isolation or guarantee network denial. agy may require additional native permission configuration; the driver never changes global settings.

Equivalent explicit permission options suppress the corresponding default. Set `CS_NO_AUTO=1` to omit all automatic permission flags. Extra arguments are passed as separate quoted arguments; they can change security behavior, persistence, and hook settings. Keep sandboxing enabled and do not supply bypass flags. Do not override session identity or completion hooks through extra arguments.

Claude and grok receive generated UUIDs. Codex IDs are captured from the completion event's `thread-id` when jq is available. agy on Linux binds its ID through the presence lock held by a descendant of the exact tmux pane process. Without that binding, or for Codex without a captured ID, inspect the native session picker/storage and supply `start --native-id ID NAME CLI DIR` when restarting. You can also use that option to resume an existing native session under a new name. The driver deliberately does not guess IDs from unrelated recent files. Until an ID is known, `attach-hint` provides live attach only.

## Configuration

| Variable | Default / purpose |
| --- | --- |
| `CLI_SESSIONS_HOME` | `$HOME/.cli-sessions`; driver state root |
| `CLI_SESSIONS_REG` | `$CLI_SESSIONS_HOME/registry`; directory of per-name metadata files and quoted launchers, not JSON |
| `CLI_LOGS` | `$HOME/.cli-sessions/logs`; raw terminal logs, independent of the state-root override |
| `CLI_SESSIONS_MARKS_DIR` | `$CLI_SESSIONS_HOME/marks`; atomic turn/exit markers |
| `CS_BOT` | Optional label; `--bot` takes precedence |
| `CS_NO_AUTO` | Set to `1` to omit automatic permission flags |

Use consistent configuration for every invocation. Paths may contain spaces, but not tabs or newlines. Relative overrides are discouraged; use absolute paths. `CS_NAME` is assigned internally for hooks. Native CLI storage paths remain under the CLI's own configuration; the driver neither copies nor relocates transcripts. Terminal logs are separate raw screen output and can include sensitive content. State and logs are created with a private umask; secure preexisting parent directories yourself.

## Safety and limitations

- Use a separate git worktree per task when tasks can edit the same project. Inspect changes and test results before accepting work. Merges, releases, and outbound actions need the human's authorization.
- Inject secrets through your secret manager's environment injection; never put them in prompts. Logs and launchers are not redacted: do not pass credentials in CLI arguments. Existing tmux servers may not inherit newly injected environment variables; verify native CLI authentication before sending work.
- Serialize commands per session. Only one turn and waiter should be active per name; simultaneous starts/sends are unsupported. Hook markers correlate to the latest dispatch, so late hooks from overlapping turns can mislead a waiter.
- `send` cannot prove the foreground program is ready. Read first; do not use extra arguments that exit into a shell. The launcher exits when the CLI exits and the pane remains visible; it never falls back to an interactive shell.
- Native completion tracks the exact dispatch timestamp or event offset; delayed and repeated waits can return immediately. Fallback idle detection is heuristic: it must observe a busy marker, then an unchanged screen without busy markers. Start waiting immediately after send. Very fast work, animated interfaces, text containing busy words, changed UI wording, and popups outside the inspected screen tail can defeat detection. Missing hooks time out; there is no silent idle fallback for claude/codex.
- First-run theme, consent, directory trust, login, and update screens require inspection. An update dialog may preselect installation: prefer Escape to defer. Do not rely on fixed cursor positions across CLI versions.
- Native resume can fail while another writer holds the session. Do not stop shared background services to clear a lock without checking other sessions.
- `stop` merely types the normal exit command; it may fail if the CLI is busy or showing a modal. Inspect the pane. The driver never kills sessions; retained dead panes continue to occupy their tmux names.
- Linux acceptance covered agy 1.5.9, Codex 0.169.0 and Grok 1.0.77: file edits, test execution, same-session follow-ups, agy one-time approval, and delayed/repeated waits. This does not establish behavior across other versions or platforms, or prove every sandbox restriction. Log rotation, concurrent registry access and reboot recovery of live terminals are not implemented.

## License

MIT. Copyright (c) 2026 cli-like-human contributors.

307 修复补充：Grok/agy 优先使用准确绑定的原生会话完成状态，支持延迟或重复 wait；不再要求观察到忙碌瞬间。agy 在 Linux 根据 tmux 子进程持有的 presence lock 绑定 ID，不选择共享历史中的最近一条。send 拒绝覆盖尚未结束的回合。具体操作与权限提示处理见 SKILL.md。验证覆盖文件编辑、运行测试、同会话追问和等待恢复；没有关闭沙箱或复制登录凭据。

## Regression checks

Run `python3 -B tests/test_native.py` for native completion correlation, delayed completion, failures, truncated events, missing metadata fallback, and agy identity/timestamp checks. Run `bash -n bin/cli-session bin/cli-session-hook bin/cli-session-mark` for shell syntax. Unit tests complement the recorded Linux live acceptance; they do not replace it.

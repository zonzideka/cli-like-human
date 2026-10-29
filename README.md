# cli-like-human

An agent skill for driving coding CLIs (**Claude Code, Codex, Grok CLI, Antigravity `agy`, DeepSeek Harness `dsh`**) the way a human does — so a human can take over any session at any time.

English | [简体中文](README.zh-CN.md)

## Principles

1. **One named session per task.** Follow-ups and rework go back to the same session (`<project>-<task>-<role>`).
2. **Real project directory + the human's own config.** No custom `HOME`, no private config dirs, no wrapper layers.
3. **Native storage only.** The registry maps *name → native session id*; it never copies content.
4. **Never delete sessions.** Hand off with a ready-to-run attach/resume command.

## What's inside

| Path | Purpose |
|---|---|
| `skills/cli-like-human/SKILL.md` | The skill (English): workflow, per-CLI command matrix, tested pitfalls |
| `skills/cli-like-human/SKILL.zh.md` | Same skill in Chinese |
| `bin/cli-session` | tmux driver: `start / send / wait / read / key / list / attach-hint / stop` |
| `bin/cli-session-hook` | Completion hook (Claude `Stop` / Codex `notify`) that writes marker files for `wait` |
| `examples/dsh-auto.patch.yml` | DeepSeek Harness patch: disable approval prompts, keep the sandbox |

## Requirements

- bash, tmux, python3
- Any of: `claude`, `codex`, `grok`, `agy`, `dsh` (tested with claude 2.1.312, codex 0.162.0, grok 1.0.70, agy 1.4.10, dsh 0.2.1-rc.2)
- Optional: a secret manager such as 1Password CLI (`op run` with `op://` references) for API keys

## Install

```bash
git clone https://github.com/zonzideka/cli-like-human
cd cli-like-human
install -m 755 bin/cli-session bin/cli-session-hook ~/.local/bin/
mkdir -p ~/.cli-sessions && cp examples/dsh-auto.patch.yml ~/.cli-sessions/
# Put the skill wherever your agent loads skills from, e.g.:
cp -r skills/cli-like-human ~/.claude/skills/
```

Environment variables: `CLI_SESSIONS_HOME` (default `~/.cli-sessions`), `CLI_SESSIONS_REG`, `CLI_LOGS`, `CLI_SESSION_HOOK`, `CS_NO_AUTO=1`, `LANG=zh*` for Chinese output.

## Quick start

```bash
cli-session start shop-login-fix-code grok ~/src/shop
cli-session send  shop-login-fix-code "Fix the login redirect bug; run the tests."
cli-session wait  shop-login-fix-code      # 0 done, 2 timeout, 3 prompt on screen, 4 session gone
cli-session read  shop-login-fix-code
cli-session attach-hint shop-login-fix-code
```

## Safe defaults

`cli-session start` enables **auto-accept while keeping each CLI's own sandbox**:

| CLI | Default flags |
|---|---|
| claude | `--permission-mode acceptEdits --disallowedTools Bash` |
| codex | `-a never -s workspace-write` (network stays off) |
| grok | `--always-approve --sandbox workspace` |
| agy | `--mode accept-edits --sandbox` (+ `"toolPermission": "proceed-in-sandbox"` in settings) |
| dsh | headless only, with `examples/dsh-auto.patch.yml` |

It **never** uses `--yolo`, `--dangerously-skip-permissions`, `--dangerously-bypass-approvals-and-sandbox`, or `danger-full-access`. Set `CS_NO_AUTO=1` to get per-action confirmations back. Merges, releases, and outbound messages should still be approved by a human. Keep secrets out of prompts and logs.

## License

MIT © 2026 zonzideka

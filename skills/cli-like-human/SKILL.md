---
name: cli-like-human
description: >-
  Use when an agent needs to drive local coding CLIs (claude / codex / grok / agy, plus headless dsh)
  to write code, review, plan, or follow up on a task. Use them the way a human does: one named session
  per task, in the real project directory, with the human's own config, stored only in native session
  storage, so a human can take over at any time via tmux attach or native resume.
  Not for building unattended batch platforms.
---
# Use CLIs like a human

> 中文版：[SKILL.zh.md](SKILL.zh.md). Both versions have the same content.

Humans use agents; agents use CLIs. To a CLI, the agent *is* the human — so the agent must use it the way a human would, so that a human can pick up seamlessly later. Supports claude / codex / grok / agy, and headless-only dsh. Not for building unattended batch platforms.

## Principles
1. **One named session per task.** Follow-ups and rework go back to the same session; never open a new one. Name it `<project>-<task>-<role>`, e.g. `shop-login-fix-code`.
2. **Real project directory + the human's config.** Start in the project directory (its worktree when writing code) so the CLI reads AGENTS.md / CLAUDE.md, slash commands and model settings itself. Don't change HOME, don't use private config dirs, don't add wrapper layers.
3. **Native storage only.** The session is the CLI's own session file; the registry only maps "name → native id" and never copies content. Don't use `--no-session-persistence` or `codex exec --ephemeral`.
4. **Don't close sessions; leave them for the human.** Don't delete sessions when done; keep the tmux session or exit the CLI normally (not by killing it), and hand over a takeover command.

## Delegate or do it yourself
- **Delegate**: high-output work that can be verified independently — code, long documents, batch processing. The agent splits the task, writes a clear brief (goal, constraints, acceptance criteria), verifies the result and reports to the human.
- **Do it yourself**: one- or two-step jobs. If briefing costs more than doing, don't delegate for its own sake.
- **Always stays with the agent**: the final answer to the human, gate decisions, merges and releases that need human approval.
- When unsure, ask: can I verify the delegated result against one clear criterion? If yes, delegate; if not, define the criterion first.

## Choosing a mode
- **tmux interactive (default)**: multi-turn, long tasks, or when a human may take over midway. The human can `tmux attach` to watch live.
- **headless + resume**: single short questions, structured (JSON) output, CI-style checks. Pass the same session name/id every turn; the human can still view it later with native resume.

## Script `cli-session` (put it on PATH, e.g. `~/.local/bin`)
```
cli-session start <name> <claude|codex|grok|agy> [dir] [-- extra args]   # start TUI; resumes if name is registered
cli-session send <name> "prompt"     # or: send <name> - (read stdin); uses load-buffer/paste-buffer
cli-session wait <name> [--timeout s] # 0 done / 2 timeout / 3 prompt on screen / 4 session gone
cli-session read <name> [lines=60]   # capture-pane
cli-session key <name> Escape|Enter|Down …   # answer prompts
cli-session list | attach-hint <name> | stop <name>   # stop = exit CLI normally, session kept
```
Registry: `~/.cli-sessions/registry.json` (override with `CLI_SESSIONS_HOME` / `CLI_SESSIONS_REG`); screen logs: `~/.cli-sessions/logs/<name>.tty.log` (`CLI_LOGS`). With `LANG=zh*` the script prints Chinese.
Standard loop: `start → wait (handle prompts) → send → wait → read → send follow-ups… → attach-hint to hand over`.

## Command matrix (tested: claude 2.1.309 / codex 0.162.0 / grok 1.0.70 / agy 1.4.2)
| | Named session | One-shot headless | Resume | Human's session list |
|---|---|---|---|---|
| claude | `claude -n <name> --session-id <uuid>` (name stored as customTitle) | `-p -n <name> --session-id <uuid> --output-format json` (returns session_id) | `claude -r <name or id>`, also with -p | `/resume` (shows names) |
| codex | no name flag; `/rename <name>` inside the TUI | `codex exec --json -s read-only …`; first line `thread.started` carries thread_id | `codex resume <id or name>`; `codex exec resume <id or name> -` | `codex resume` picker; **exec sessions only appear with `--include-non-interactive`** |
| grok | `grok -s <uuid>` (custom id honored) | `grok -s <uuid> -p "…" --always-approve --sandbox workspace --output-format json` | `grok -r <id>` | `grok sessions list` includes headless sessions |
| agy | no name flag, id only | `agy -p "…" --output-format json`, returns `conversation_id` | `agy --conversation <id>` | files at `~/.gemini/antigravity-cli/conversations/<id>.db`; interactive list unverified |

Unverified: where grok's `-r <title>` title comes from; agy's session-list command; codex naming other than `/rename`.

## Fifth CLI: DeepSeek Harness (dsh, tested 0.2.1-rc.2)
- `npm i -g @deepseek-ai/dsh` (developer preview; expect breaking changes).
- Inject the key only from a secret manager (e.g. `op run`), never write it to files: `DEEPSEEK_API_KEY=op://<vault>/<item>/credential`.
- One-shot: `dsh headless "…"` (result on stdout, diagnostics on stderr; `--json` streams events; `--session-id <id>` continues a session; `-` reads the task from stdin).
- Interactive: `dsh tui` (`--resume <session>`); web UI `dsh web --no-open` (default 127.0.0.1:3080); automation `dsh --profile acp` (ACP stdio).
- Unverified: session-list command; whether tui works with `cli-session`.

## Auto-accept mode (on by default)
`cli-session start` adds "auto-accept, keep sandbox" flags: file edits and commands no longer prompt, but writes are limited to the working directory (plus temp dirs each sandbox allows), and codex keeps network off. Flags you pass yourself are not duplicated; `CS_NO_AUTO=1 cli-session start …` disables the defaults. Never use sandbox-bypassing switches (codex `--dangerously-bypass-approvals-and-sandbox`/`--yolo`, claude/agy `--dangerously-skip-permissions`, grok always-approve without `--sandbox`, dsh `danger-full-access`).

| CLI | Interactive (cli-session default) | Headless |
|---|---|---|
| claude 2.1.312 | `--permission-mode acceptEdits --disallowedTools Bash` (auto-accept edits only, no Bash) | `claude -p --permission-mode acceptEdits --disallowedTools Bash "task"` |
| codex 0.162.0 | `-a never -s workspace-write` | `codex exec -s workspace-write "task"` (exec never asks for approval) |
| grok 1.0.70 | `--always-approve --sandbox workspace` | `grok -p "task" --always-approve --sandbox workspace` |
| agy 1.4.10 | `--mode accept-edits --sandbox`, plus `"toolPermission": "proceed-in-sandbox"` in `~/.gemini/antigravity-cli/settings.json` | `agy -p "task" --mode accept-edits --sandbox` |
| dsh 0.2.1-rc.2 | no TUI profile; not supported by `cli-session start` | inject `DEEPSEEK_API_KEY` via a secret manager, then `dsh --profile headless --patch ~/.cli-sessions/dsh-auto.patch.yml "task"` (patch only sets approval to never; sandbox stays workspace-write) |

Sandbox tests (writing outside the work dir to `~/outside-<cli>.txt`; grok/codex/agy sandboxes all allow /tmp, so don't test with /tmp):
- codex: `Read-only file system`, blocked. grok: `Permission denied`, blocked. agy: `Read-only file system`, blocked.
- dsh: `Read-only file system`; the sandbox offers escalation, but approval is off so escalation is denied.
- claude: no Bash; Write outside the work dir shows `Do you want to create …?` (wait returns 3) — a permission prompt, not a sandbox. Answer No; don't choose "always allow" for your whole HOME, and don't type `! command` as claude suggests.
- agy `--mode auto` logged `auto mode is unavailable, falling back to default` on the test machine, so it isn't used; with `accept-edits` alone `ls` still prompts `Run this command?` until proceed-in-sandbox is set.
- The first visit to a new directory still asks to trust it (claude/codex/agy); codex may also show an update prompt (press Escape). Handle these once with `key`.

## Wake on done: `cli-session wait`
After dispatching, run in the background: `cli-session wait <name> [--timeout s, default 3600] [--stable s, default 6] [--lines summary lines, default 15]`. It exits when the CLI finishes the turn, so the caller (an agent's background-job notification, a script, …) wakes up and reads the first line and the screen summary.
- Exit codes: 0 done; 2 timeout; 3 confirmation/permission prompt on screen (`read` it, answer with `key`, then wait again); 4 tmux session gone.
- First line: `[cli-session wait] session=… cli=… mode=hook|idle result=… started=0|1 elapsed=Ns`, then the last screen lines.
- No false positives: `send` records the dispatch time; wait requires a "started" signal (hook start mark or a busy marker) and a done mark newer than dispatch.
- Detection per CLI:
  - claude: hook. `start` overlays UserPromptSubmit/Stop hooks for this session only via `--settings` (calling `cli-session-hook`, which writes `$CLI_SESSIONS_HOME/marks/<name>.start|.done`); `~/.claude/settings.json` is untouched.
  - codex: hook. Started with `-c notify=["<hook>","done"]`, this session only; `~/.codex/config.toml` is untouched.
  - grok / agy: terminal idle. After a busy marker (`esc to interrupt` / `Ctrl+c:cancel` / `Working` / `Thinking…` / `Running` …), ~6 s of unchanged screen without busy markers means done.
  - dsh: headless only; the command exiting means done.
- Hooks only work in sessions launched by `cli-session start` (via tmux env `CS_NAME`); stop and re-start older sessions to get hooks.
- For idle-detected CLIs, if the work finishes before wait starts, no start signal is seen and wait runs to timeout — start wait right after dispatch.
- Fallback: a machine restart kills a running wait. For long jobs, schedule a fallback check (`cli-session list` + `read`).
- Tested (auto-accept mode): claude and codex via hook, exit 0; grok idle 16 s, exit 0; agy idle 23 s, exit 0; dsh headless 11 s, exit 0. Timeout path tested on claude and grok (exit 2).

## Handing over
`cli-session attach-hint <name>` prints two lines:
- Live takeover: `tmux attach -t cs-<name>` (detach with Ctrl-b d)
- After closing, resume in the project dir: `claude -r <name>` / `codex resume <id or name>` / `grok -r <id>` / `agy --conversation <id>`

## Shared rules
- Follow the project's own branch and commit conventions; paste them into the prompt when delegating.
- Write code in a separate git worktree (grok: `-w <name>`), never directly on the main branch.
- Auto-accept is on by default with each CLI's sandbox kept (see "Auto-accept mode"); for read-only review use codex `-s read-only` or claude `--permission-mode plan`. Use `CS_NO_AUTO=1` for per-action confirmation.
- Secrets only through a secret manager (e.g. `op run` + `op://` references), never in prompts or logs.
- Put a total time limit on every call; write logs to a fixed directory.
- Merges, releases and outbound messages still need human approval. Nobody reviews their own work.

## Pitfalls (tested)
- **First-run prompts**: claude shows theme, security notice, then trust-folder — the cursor defaults to "No, exit", so send `Down Enter`. codex's trust prompt defaults to "Trust and continue". agy shows theme, a **data-sharing consent that is checked by default** (uncheck, then Done), and trust-folder. grok shows "Help improve Grok", off by default.
- **codex update prompt**: "Update now" is preselected (runs a global npm install) — press `Escape`, never Enter.
- **codex write lock**: the codex TUI holds the session write lock through a background app-server daemon that survives exiting the TUI, so `codex exec resume` fails with `already has an active writer`; interactive `codex resume <id>` works. To resume headless you must `codex app-server daemon stop` (affects other codex sessions — ask the human first). Stick to one mode per codex session.
- Send long text with `load-buffer` + `paste-buffer -p` (bracketed paste) and a separate Enter; don't type it with `send-keys`.
- Use a 200×50 window to avoid wrap misdetection; `capture-pane -J` joins wrapped lines.
- In headless mode put the prompt on stdin or last so variadic flags (e.g. `--add-dir`) don't swallow it; codex exec waits on stdin when none is given — add `</dev/null` or use `-`.
- claude's TUI suggests tmux `focus-events off`; harmless.

## References
- [awslabs/cli-agent-orchestrator](https://github.com/awslabs/cli-agent-orchestrator): another approach to orchestrating multiple CLIs, aimed at automated orchestration; by default it uses no-prompt flags and per-terminal config dirs for some CLIs. This skill focuses on human takeover instead; its idle-marker approach was a useful reference.

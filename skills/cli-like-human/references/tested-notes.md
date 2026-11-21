# Tested notes (historical field data)

These notes were collected before 2026-10-29 with the **old driver** (`ae42075`). They are historical observations, not guarantees: the current driver does not depend on any of these values. Every item carries a status tag:

- `recorded (old driver)` — observed once with the old driver, never re-verified since.
- `re-verified YYYY-MM-DD on vX` — explicitly re-checked on driver version `vX`.
- `unverified` — never confirmed.

CLI versions are kept exactly as originally recorded and are deliberately **not** normalised: claude 2.1.309 / 2.1.312, codex 0.162.0, grok 1.0.70, agy 1.4.2 / 1.4.10. Versions differ between sections because the original notes were taken at different times.

No item below has been re-verified on the current driver, so unless a line says otherwise its status is `recorded (old driver)`.

## 1. First-run dialogs and default cursor positions

The sequence you were *likely* to see on a fresh CLI version. These are not key scripts: always inspect the live screen. Trusting a directory or enabling data sharing requires human authorization.

- claude 2.1.309: theme selection, then a security notice, then folder trust. The trust dialog's default cursor was on **"No, exit"**; the recorded workaround was `Down Enter`. `status: recorded (old driver)`
- codex 0.162.0: the trust dialog defaulted to **"Trust and continue"**. The update prompt defaulted to **"Update now"** (which runs a global npm install); press `Escape` to defer. `status: recorded (old driver)`
- agy 1.4.2: theme selection, then a **data-sharing consent that was checked by default** (uncheck it, then Done), then folder trust. `status: recorded (old driver)`
- grok 1.0.70: "Help improve Grok" was off by default. `status: recorded (old driver)`
- The first visit to a new directory still asked for trust on claude, codex, and agy; codex could also show the update prompt. Handle these once with `key`, after reading the screen. `status: recorded (old driver)`

## 2. Session command matrix

The headless column is for reference only: `cli-session` does not drive headless mode.

| CLI | Named session | One-shot headless | Resume | Human-visible session list | Status |
| --- | --- | --- | --- | --- | --- |
| claude 2.1.309 | `claude -n <name> --session-id <uuid>` (name stored as customTitle) | `claude -p -n <name> --session-id <uuid> --output-format json` (returns session_id) | `claude -r <name or id>`, also with `-p` | `/resume` (shows names) | recorded (old driver) |
| codex 0.162.0 | no name flag; `/rename <name>` inside the TUI | `codex exec --json -s read-only ...`; first line `thread.started` carries thread_id | `codex resume <id or name>`; `codex exec resume <id or name> -` | `codex resume` picker; exec sessions appear only with `--include-non-interactive` | recorded (old driver) |
| grok 1.0.70 | `grok -s <uuid>` (custom id honoured) | `grok -s <uuid> -p "..." --always-approve --sandbox workspace --output-format json` | `grok -r <id>` | `grok sessions list` includes headless sessions | recorded (old driver) |
| agy 1.4.2 | no name flag, id only | `agy -p "..." --output-format json` (returns conversation_id) | `agy --conversation <id>` | files at `~/.gemini/antigravity-cli/conversations/<id>.db`; interactive list unverified | recorded (old driver) |

Explicitly unverified in the original notes: where grok's `-r <title>` title comes from; agy's session-list command; codex naming methods other than `/rename`. `status: unverified`

## 3. Auto-accept flags (interactive vs headless)

`cli-session start` added auto-accept-with-sandbox flags: edits and commands stopped prompting while writes stayed inside the working directory (plus temp directories each sandbox allows). Flags you passed yourself were not duplicated; `CS_NO_AUTO=1 cli-session start ...` disabled the defaults. `status: recorded (old driver)`

| CLI | Interactive (cli-session default) | Headless | Status |
| --- | --- | --- | --- |
| claude 2.1.312 | `--permission-mode acceptEdits --disallowedTools Bash` (auto-accept edits only, no Bash) | `claude -p --permission-mode acceptEdits --disallowedTools Bash "task"` | recorded (old driver) |
| codex 0.162.0 | `-a never -s workspace-write` | `codex exec -s workspace-write "task"` (exec never asks for approval) | recorded (old driver) |
| grok 1.0.70 | `--always-approve --sandbox workspace` | `grok -p "task" --always-approve --sandbox workspace` | recorded (old driver) |
| agy 1.4.10 | `--mode accept-edits --sandbox`, plus `"toolPermission": "proceed-in-sandbox"` in the user's own `~/.gemini/antigravity-cli/settings.json` | `agy -p "task" --mode accept-edits --sandbox` | recorded (old driver) |

- agy needed `"toolPermission": "proceed-in-sandbox"` in the **user's own** settings to stop asking for confirmation. The driver does not change global settings; whether to set it is the human's decision. `status: recorded (old driver)`
- agy `--mode auto` logged `auto mode is unavailable, falling back to default` on the test machine, so it was not used. `status: recorded (old driver)`
- Never use sandbox-bypassing switches: codex `--dangerously-bypass-approvals-and-sandbox` / `--yolo`, claude and agy `--dangerously-skip-permissions`, grok always-approve without `--sandbox`, and dsh `danger-full-access`. `status: recorded (old driver)`

## 4. Sandbox write tests

Method: write to `~/outside-<cli>.txt`, **outside** the working directory. Do **not** test with `/tmp`: the grok, codex, and agy sandboxes all allow `/tmp`. `status: recorded (old driver)`

- codex 0.162.0: `Read-only file system`, blocked. `status: recorded (old driver)`
- grok 1.0.70: `Permission denied`, blocked. `status: recorded (old driver)`
- agy 1.4.10: `Read-only file system`, blocked. `status: recorded (old driver)`
- claude 2.1.312: no Bash tool; Write outside the work dir showed `Do you want to create ...?` (`wait` returned 3). This is a **permission prompt, not a sandbox**. Answer No; do not choose "always allow" for the whole HOME, and do not type the `! command` suggestion claude offers. `status: recorded (old driver)`
- agy with only `accept-edits`: `ls` still prompted `Run this command?` until proceed-in-sandbox was set. `status: recorded (old driver)`

## 5. Completion detection results

Old-driver results, kept for historical comparison:

- claude 2.1.312 and codex 0.162.0: completion via hook, exit 0. `status: recorded (old driver)`
- grok 1.0.70: idle detection after about 16 s, exit 0. `status: recorded (old driver)`
- agy 1.4.10: idle detection after about 23 s, exit 0. `status: recorded (old driver)`
- Timeout path (exit 2) was exercised on claude and grok. `status: recorded (old driver)`
- The current driver's `dead` and `stalled` results have **no real-CLI data**: they are covered only by fake-CLI smoke tests. `status: unverified`

## 6. Operational pitfalls

- codex 0.162.0: the TUI holds the session write lock through a background app-server daemon that survives exiting the TUI, so `codex exec resume` fails with `already has an active writer`; interactive `codex resume <id>` works. `codex app-server daemon stop` affects other codex sessions — ask the human first. Do not mix interactive and headless modes in one codex session. `status: recorded (old driver)`
- In headless mode put the prompt on stdin or last, so variadic flags (for example `--add-dir`) cannot swallow it; `codex exec` waits on stdin when none is given, so add `</dev/null` or use `-`. `status: recorded (old driver)`
- Send long text with `load-buffer` + `paste-buffer -p` (bracketed paste) and a separate Enter; do not type it with `send-keys`. `status: recorded (old driver)`
- Use a 200x50 window to avoid wrap misdetection; `capture-pane -J` joins wrapped lines. `status: recorded (old driver)`
- claude's TUI suggests tmux `focus-events off`; harmless. `status: recorded (old driver)`

## 7. Unsupported CLI (historical record)

DeepSeek Harness (dsh) 0.2.1-rc.2 was a developer preview with breaking changes and was never supported by the driver; it is recorded here only as history.

- Install was `npm i -g @deepseek-ai/dsh`; inject the API key only through your secret manager, never into a file. `status: recorded (old driver)`
- Modes seen: `dsh headless "..."`, `dsh tui`, `dsh web --no-open` (default 127.0.0.1:3080), and `dsh --profile acp` (ACP stdio). `status: recorded (old driver)`
- Sandbox write test: `Read-only file system`; the sandbox offered escalation but approval was off, so escalation was denied. `status: recorded (old driver)`
- The original `examples/dsh-auto.patch.yml` only set approval to never while keeping the sandbox at workspace-write; its contents are not reproduced here. `status: recorded (old driver)`
- Unverified: the session-list command, and whether `dsh tui` works with `cli-session`. `status: unverified`

## 8. References

- [awslabs/cli-agent-orchestrator](https://github.com/awslabs/cli-agent-orchestrator): another approach to orchestrating multiple CLIs, aimed at automated orchestration; by default it uses no-prompt flags and per-terminal config directories for some CLIs. This skill focuses on human takeover instead; its idle-marker approach was a useful reference. `status: recorded (old driver)`

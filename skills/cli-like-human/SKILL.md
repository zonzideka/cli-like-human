---
name: cli-like-human
description: >-
  Drive local claude, codex, grok, or agy coding CLIs in named tmux sessions
  with native persistent history, terminal inspection, completion detection,
  and human takeover through attach or native resume.
---
# Use coding CLIs like a human

Use one named session per task. Send follow-ups and corrections to the same session. Start in the real project directory, preferably a separate git worktree for independent edits. Keep the human's HOME and native CLI configuration. Never create private substitute transcript storage or disable native persistence.

Never kill sessions or delete native history. Leave the terminal available and finish with `cli-session attach-hint NAME`. Stop only when requested, through normal CLI exit; the driver retains the pane.

## Workflow

1. Inspect `cli-session list` before creating a session. Choose a descriptive task name such as `example-fix`.
2. Run `cli-session start NAME CLI PROJECT_DIR`, then `cli-session read NAME`. Resolve startup screens deliberately.
3. Send a brief containing the goal, constraints, and acceptance checks: `cli-session send NAME 'TASK'`. For long text use `cli-session send NAME -` with stdin.
4. Immediately run `cli-session wait NAME --timeout 600`. Use a background job if the host supports asynchronous command completion. A timeout does not stop work.
5. Interpret the exit status: 0 completed turn; 2 timeout; 3 popup; 4 exited CLI or missing session; 1 command error. Read the screen and verify changes and reported checks. Completion does not prove correctness.
6. For a popup, read before sending specific keys with `cli-session key NAME Escape` or another appropriate key sequence. Then wait again. Never blindly press Enter.
7. Send follow-ups to the same name, serially. Hand the human the output of `cli-session attach-hint NAME`.

## Per-CLI commands

| CLI | Native start | Native resume | Driver default flags | Detection |
| --- | --- | --- | --- | --- |
| claude | `claude -n NAME --session-id UUID` | `claude -r ID` | `--permission-mode acceptEdits --disallowedTools Bash` | UserPromptSubmit/Stop hooks through per-session `--settings` |
| codex | `codex` | `codex resume ID` | `-a never -s workspace-write` | Per-session `-c notify=[...]` hook |
| grok | `grok -s UUID` | `grok -r ID` | `--always-approve --sandbox workspace` | Busy then stable idle |
| agy | `agy` | `agy --conversation ID` | `--mode accept-edits --sandbox` | Busy then stable idle |

Flags are version dependent; inspect the installed CLI's help if rejected. Do not add bypass flags. Defaults aim to auto-accept within native sandbox controls; Claude's restrictions are permissions, not an OS sandbox. Configure its sandbox separately if required. Do not claim network denial or isolation without verification. agy may still ask for permission depending on its native configuration.

`CS_NO_AUTO=1` omits defaults. Explicit equivalent options replace their defaults. Extra arguments follow `--`; preserve identity, native persistence, sandboxing, and driver hooks. No global CLI settings are edited.

Claude/grok IDs are allocated at start. Codex completion payloads provide an ID when jq is installed. agy ID discovery is manual. If the ID is missing, live attach still works; obtain the native ID from the CLI and restart after normal exit with `start --native-id ID NAME CLI DIR`. Never guess the latest session in shared storage. Do not open multiple writers for a native ID.

## Detection and first-run pitfalls

Hook-based wait requires a completion marker matching the latest dispatch. Idle wait requires an observed busy marker followed by about six seconds of unchanged screen without busy markers. Start wait immediately after send: short work can finish before busy is observed. Animations, changed wording, and busy words in output can cause timeout or incorrect idle inference. Inspect output yourself. Only one dispatcher/waiter per name is supported; overlapping turns can misattribute hooks.

Theme selection, login, security notices, folder trust, telemetry consent, and update dialogs may appear on first use. Inspect the current screen and the chosen option, not an assumed cursor position. Update prompts may select installation by default; use Escape to defer. Do not enable data sharing or trust a directory without appropriate authorization. Popup detection is heuristic and only examines the screen tail.

The driver exposes `start`, `send`, `key`, `read`, `wait`, `list`, `attach-hint`, and `stop`. `stop` requests `/exit` for claude and `/quit` for codex/grok; for agy attach and exit normally. It never kills tmux. Inspect the pane to confirm exit before restarting. Do not send text until the CLI is ready.

## State and handoff

`CLI_SESSIONS_HOME` defaults to `$HOME/.cli-sessions`. `CLI_SESSIONS_REG` defaults to its `registry` directory; it holds metadata and launch arguments, not a transcript copy. `CLI_SESSIONS_MARKS_DIR` defaults to its `marks` directory. `CLI_LOGS` independently defaults to `$HOME/.cli-sessions/logs` and contains raw terminal output. Use consistent absolute overrides. Optional `--bot LABEL` or `CS_BOT` is only a metadata label.

Keep secrets out of prompts, arguments, and logs; use your secret manager's environment injection. Existing tmux servers may have stale environments. Review logs as sensitive data. Do not change shared services to clear native session locks without checking other sessions. Follow project rules and obtain human authorization for merges, releases, and outbound actions.

The final handoff includes the task status, verification results, unresolved limitations, and the attach/resume instructions from `attach-hint`. Detach with Ctrl-b then d. Preserve the named session for the next turn.

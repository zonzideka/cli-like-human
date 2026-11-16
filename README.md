# cli-like-human

A skill and Bash driver for using `claude`, `codex`, `grok`, and `agy` in named tmux sessions. Send tasks, inspect the terminal, wait for a turn, and hand the same session to a human. Follow-ups retain context in the CLI's native storage.

One task gets one name and a real project directory. The driver uses your existing CLI configuration and never replaces `HOME`. It retains terminal sessions and native history rather than cleaning them up after each task.

## Requirements

- Bash 3.2 or later, tmux with `new-session -c`, `respawn-pane -c`, and bracketed `paste-buffer -p` support, and standard Linux/macOS utilities.
- At least one supported coding CLI installed, authenticated, and available on `PATH`.
- For `grok` on Linux: `bubblewrap` (`bwrap`). Its `workspace` and `read-only` sandbox profiles cannot start without it; `start` now refuses that combination instead of leaving a dead pane.
- Optional `jq`: captures the Codex native ID from completion events. Without it, supply the ID explicitly for native resume.

No Python dependency. Actual CLI flag compatibility, hook support, and sandbox behavior depend on the installed CLI version. Linux/macOS live CLI integration and macOS Bash 3.2 have not been verified for this release; see limitations below.

## Install

From a local checkout:

```bash
mkdir -p "$HOME/.local/bin"
install -m 755 bin/cli-session bin/cli-session-hook bin/cli-session-mark "$HOME/.local/bin/"
export PATH="$HOME/.local/bin:$PATH"
# Copy the skill to your agent's skill directory, for example:
mkdir -p "$HOME/.claude/skills"
cp -R skills/cli-like-human "$HOME/.claude/skills/"
```

Keep all three scripts together. Helpers resolve relative to the driver location; install the files rather than symlinking only the driver. Add the PATH setting to your shell configuration if needed.

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
| `stop NAME` | Request normal exit (`/exit` for claude, `/quit` for codex/grok). Does not kill tmux or delete history. For agy, attach and exit normally. |
| `set-id NAME ID` | Record a native session ID the CLI reported on screen, so `attach-hint` can print a resume command without a restart. The driver never guesses IDs from shared storage. |

Names and optional `--bot` labels accept letters, digits, underscores, and hyphens, beginning with a letter or digit. The label is metadata only. Reusing a registered name with another directory or CLI is rejected. A retained exited pane can be restarted with `start`; a live pane must be reused through `send` or attach.

`wait` returns **0** for hook completion or inferred idle, **2** for timeout, **3** for a detected confirmation/popup, and **4** for an exited CLI or missing session. Usage, dispatch replacement, and other errors return **1**. A timeout leaves the task running. Success reports turn completion, not task correctness or successful tests.

## CLI defaults and native IDs

| CLI | New session / resume | Default permission flags | Completion |
| --- | --- | --- | --- |
| claude | `-n NAME --session-id UUID` / `-r ID` | `--permission-mode acceptEdits --disallowedTools Bash` | Per-session UserPromptSubmit/Stop settings |
| codex | interactive start / `resume ID` | `-a never -s workspace-write` | Per-session `-c notify=[...]` completion hook |
| grok | `-s UUID` / `-r ID` | `--always-approve --sandbox workspace` | Busy marker then stable idle screen |
| agy | interactive start / `--conversation ID` | `--mode accept-edits --sandbox` | Busy marker then stable idle screen |

These defaults reduce approval prompts while retaining CLI sandbox controls where supported. Claude's edit approval mode and disabled Bash tool are permission restrictions, **not an operating-system sandbox**. Configure its native sandbox separately where available. This driver does not configure or verify operating-system isolation or guarantee network denial. agy may require additional native permission configuration; the driver never changes global settings.

Equivalent explicit permission options suppress the corresponding default. Set `CS_NO_AUTO=1` to omit all automatic permission flags. Extra arguments are passed as separate quoted arguments; they can change security behavior, persistence, and hook settings. Keep sandboxing enabled and do not supply bypass flags. Do not override session identity or completion hooks through extra arguments.

Claude and grok receive generated UUIDs. Codex IDs are captured from the completion event's `thread-id` when jq is available. For agy, or Codex without a captured ID, inspect the native session picker/storage and supply `start --native-id ID NAME CLI DIR` when restarting. You can also use that option to resume an existing native session under a new name. The driver deliberately does not guess IDs from unrelated recent files. Until an ID is known, `attach-hint` provides live attach only.

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
- Idle detection is heuristic: it must observe a busy marker, then an unchanged screen without busy markers. Start waiting immediately after send. Very fast work, animated interfaces, text containing busy words, changed UI wording, and popups outside the inspected screen tail can defeat detection. Missing hooks time out; there is no silent idle fallback for claude/codex.
- First-run theme, consent, directory trust, login, and update screens require inspection. An update dialog may preselect installation: prefer Escape to defer. Do not rely on fixed cursor positions across CLI versions.
- Native resume can fail while another writer holds the session. Do not stop shared background services to clear a lock without checking other sessions.
- `stop` merely types the normal exit command; it may fail if the CLI is busy or showing a modal. Inspect the pane. The driver never kills sessions; retained dead panes continue to occupy their tmux names.
- No live CLI, authentication, sandbox enforcement, or cross-version integration claims are made. Local fake-CLI checks exercise the driver, not vendor implementations. Log rotation, concurrent registry access, reboot recovery of live terminals, and automatic agy ID discovery are not implemented.

## License

MIT. Copyright (c) 2026 cli-like-human contributors.

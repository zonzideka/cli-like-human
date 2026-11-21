---
name: cli-like-human
description: >-
  Drive local claude, codex, grok, or agy coding CLIs in named tmux sessions
  with native persistent history, terminal inspection, completion detection,
  and human takeover through attach or native resume.
---
# Use coding CLIs like a human

Use one named session per task; send follow-ups to the same session. Start in the real project directory, preferably a separate worktree. Keep the human's HOME and native CLI configuration; never substitute transcript storage or disable native persistence.

Never kill sessions or delete native history. Finish with `cli-session attach-hint NAME`. Stop only on request through normal CLI exit; the driver retains the pane.

## Workflow

1. Inspect `cli-session list` before creating a session. Choose a descriptive task name such as `example-fix`.
2. Run `cli-session start NAME CLI PROJECT_DIR`, then `cli-session read NAME`. Resolve startup screens deliberately.
3. Send a brief with goal, constraints, and acceptance checks: `cli-session send NAME 'TASK'` (`send NAME -` for stdin).
4. Immediately run `cli-session wait NAME --timeout 600 --stall 300` in the background; long tasks may add `--artifact PATH` to a product that should keep growing. Exit 2 is not failure: report progress, then re-attach `wait` — a pending turn must never go unobserved. If the host supports timers, also schedule `cli-session status NAME --lines 0` to catch a wait killed by restart or background-task termination.
5. Interpret the exit status: 0 completed turn; 2 timeout; 3 popup; 4 exited CLI (`dead` = launcher killed) or missing session; 5 stalled (alive but no activity for `--stall` seconds; read the screen before deciding); 1 command error. Verify with the checklist below.
6. For a popup, read before sending specific keys with `cli-session key NAME Escape` or another appropriate sequence. Then wait again. Never blindly press Enter.
7. Send follow-ups to the same name, serially. Hand the human the output of `cli-session attach-hint NAME`.

## Verify before reporting

1. Re-run the checks the CLI claims it ran (tests, lint, build) yourself and read the real output, not its summary; confirm the diff matches the claim.
2. Spot-check that fixtures come from real data: recompute one yourself (e.g. `sha256sum` a fixture against the asserted value). Plausible invented values are a known failure mode.
3. Check platform guards: tests or helpers using OS-specific APIs, paths, or shells must skip or adapt elsewhere; compare against the CI matrix. A Windows-only helper once broke Linux CI.
4. Regression spot-check: revert only non-test changes (`git stash push -- <src paths>`), re-run the test — it must go red; restore and confirm green. A test that stays green is not a regression test.
5. Confirm no test was made green by skipping, deleting, or weakening assertions.
6. Distinguish "I verified this myself" from "the CLI claims this" in the report.

## Patrol

For cli-session sessions: run `cli-session list`, then `status NAME --lines 0` for each `TURN=pending`. On `stalled`/`dead`/`exited`, read the screen and log tail before reporting; never kill or restart. For processes you started (`nohup`/background CLI): record PID, start time, log path, expected artifact path, and wrap as `cmd >LOG 2>&1; echo $? >LOG.rc`. Each check: (1) `kill -0 PID` and `ps -o stat= -p PID` is not `Z`/`T`; (2) `.rc` file appeared (read its code); (3) log size/mtime grew; (4) artifact size/mtime grew. Process gone with no `.rc` = silent death; report at once with the log tail. Cadence for both: first check within 60-120 s of start, then every ≤5 min or one third of the stall threshold (shorter wins), and once more before each report. Use the host's timer or a background job; no resident daemon. Stop once a terminal state is reported.

## Detection and first-run pitfalls

Hook wait requires a completion marker matching the latest dispatch; idle wait needs an observed busy marker then about six seconds of unchanged screen without busy markers. Start wait immediately after send: short work can finish before busy is seen. Animations, changed wording, and busy words can cause timeout or wrong idle inference. `status` never infers idle completion: unproven completion surfaces as `stalled`. Inspect output yourself; only one dispatcher/waiter per name.

Theme, login, security notices, folder trust, telemetry consent, and update dialogs may appear on first use. Inspect the screen and chosen option, not an assumed cursor position. Update prompts may preselect installation; use Escape to defer. Do not enable data sharing or trust a directory without authorization. Popup detection is heuristic and only reads the screen tail.

Version-specific field notes (first-run dialogs, default cursor positions, sandbox write tests, resume and session-list commands): [references/tested-notes.md](references/tested-notes.md). They are historical observations, not guarantees; always inspect the live screen.

The driver exposes `start`, `send`, `key`, `read`, `wait`, `status`, `list`, `attach-hint`, and `stop`. `stop` requests `/exit` for claude and `/quit` for codex/grok; for agy attach and exit normally. It never kills tmux. Inspect the pane to confirm exit before restarting. Do not send text until the CLI is ready.

## Per-CLI commands

| CLI | Native start | Native resume | Driver default flags | Detection |
| --- | --- | --- | --- | --- |
| claude | `claude -n NAME --session-id UUID` | `claude -r ID` | `--permission-mode acceptEdits --disallowedTools Bash` | UserPromptSubmit/Stop hooks via per-session `--settings` |
| codex | `codex` | `codex resume ID` | `-a never -s workspace-write` | Per-session `-c notify=[...]` hook |
| grok | `grok -s UUID` | `grok -r ID` | `--always-approve --sandbox workspace` | Busy then stable idle |
| agy | `agy` | `agy --conversation ID` | `--mode accept-edits --sandbox` | Busy then stable idle |

Flags are version dependent; inspect the installed CLI's help if rejected. Never add bypass flags. Defaults auto-accept within native sandbox controls; Claude's restrictions are permissions, not an OS sandbox. Do not claim network denial or isolation without verification. `CS_NO_AUTO=1` omits defaults; explicit equivalents replace them; extra arguments follow `--`. No global settings are edited.

Claude/grok IDs are allocated at start. Codex completion payloads provide an ID when jq is installed. agy ID discovery is manual. If the ID is missing, live attach still works; obtain the native ID and restart after normal exit with `start --native-id ID NAME CLI DIR`. Never guess the latest session in shared storage or open multiple writers for one ID.

## State and handoff

`CLI_SESSIONS_HOME` defaults to `$HOME/.cli-sessions`. `CLI_SESSIONS_REG` defaults to its `registry` directory; it holds metadata and launch arguments, not a transcript copy. `CLI_SESSIONS_MARKS_DIR` defaults to its `marks` directory (turn/exit markers and `NAME.screen`); `$CLI_SESSIONS_HOME/waivers/` holds local secret-rule waivers. `CLI_LOGS` independently defaults to `$HOME/.cli-sessions/logs` and contains raw terminal output. Use consistent absolute overrides. Optional `--bot LABEL` or `CS_BOT` is metadata only.

Keep secrets out of prompts, arguments, and logs; use your secret manager's environment injection. An exception needs a written record: one file `$CLI_SESSIONS_HOME/waivers/NAME.waiver`, `key: value` lines with fields `rule`, `scope`, `reason`, `granted-by`, `date`, `review-by`. No waiver = rule applies; an expired `review-by` counts as none until renewed. A waiver never travels with the skill and must not be stored in the skill or project repo. The agent may only record a human-granted exception (`granted-by` is the human's name), never grant or extend one; it covers only secret injection, not sandbox/bypass flags, merge/release authorization, or the no-kill rule. Describe the secret's source and location, never its value. Review logs as sensitive data. Do not change shared services to clear native session locks without checking other sessions. Obtain human authorization for merges, releases, and outbound actions.

When a delegated task runs longer than about 15 minutes, tell the human the reporting cadence (default every 30 minutes) and report at each interval, and immediately on any exit 4 or 5 from `wait`/`status`. Silence is not a status.

The final handoff includes task status, verification results, unresolved limitations, and `attach-hint` instructions. Detach with Ctrl-b then d. Preserve the named session for the next turn.

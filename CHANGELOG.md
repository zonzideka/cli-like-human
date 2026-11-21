# Changelog

All notable changes to this project are documented in this file. The format follows Keep a Changelog, and the project adheres to Semantic Versioning.

## [0.2.0] - 2026-11-21

### Added

- `cli-session status NAME [--stall S] [--artifact PATH] [--lines N]`: one-shot health probe for patrols. Reports `done`, `idle`, `active`, `prompt`, `stalled`, `exited`, `dead`, or `gone` with the same exit-code family as `wait` (0/2/3/4) plus 5 = stalled. It never sends keys.
- `wait --stall S` and `wait --artifact PATH`: optional stall detection. Without an artifact, activity means a screen change or terminal-log growth; with one, its mtime is the progress contract. Disabled by default for compatibility.
- `list` appends `STATE`, `TURN`, and `LOG_AGE` columns; the first five columns are unchanged.
- `cli-session --version` / `cli-session version`.
- SKILL.md: a concrete "Verify before reporting" checklist, a patrol pattern with cadence for both driver sessions and processes started outside the driver, a local secret-rule waiver record, and a progress-reporting convention.
- `skills/cli-like-human/references/tested-notes.md`: per-CLI field notes restored from the first edition, with version and status annotations. These are historical observations, not guarantees.
- `tests/smoke.sh`: fake-CLI smoke tests on an isolated tmux server.

### Fixed

- `wait` no longer runs to timeout when the session launcher is killed without writing an exit marker; it returns 4 with `result=dead`.
- Idle-mode completions inferred by `wait` are recorded as done marks so later `status` and `list` calls see the finished turn.
- A vanished tmux session is reported as `gone` even when other sessions exist on the same server.

### Compatibility

- `wait` without the new options behaves as before: same exit codes, same first line.
- New exit code 5 only appears with `--stall` (wait) or from `status`.
- `list` output has three extra trailing columns.

### Limitations

- Stall detection is heuristic: animated UIs count as activity unless `--artifact` is passed.
- `status` never infers completion for idle-mode CLIs; unproven completion surfaces as `stalled`.
- Patrols are scheduled by the caller; there is no daemon, auto-restart, auto-kill, or notification.
- Live vendor-CLI integration and macOS Bash 3.2 remain unverified; new detection paths are covered by fake-CLI smoke tests only.

## [0.1.0] - 2026-10-29

- Generic, English-only rewrite: one named tmux session per task, native persistent history, terminal inspection, hook or idle completion detection, and human takeover through attach or native resume.
- Commands: `start`, `send`, `key`, `read`, `wait`, `list`, `attach-hint`, `stop`.
- Bash 3.2 compatible driver with optional `jq` for Codex native IDs; no new runtime dependencies.

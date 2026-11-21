#!/usr/bin/env bash
# Fake-CLI smoke tests for cli-session. Isolated tmux server, no user state.
set -uo pipefail
ROOT=$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null && pwd -P)
TAB=$'\t'
pass=0; fail=0

for f in "$ROOT"/bin/*; do
  if ! bash -n "$f"; then printf 'FAIL syntax: %s\n' "$f"; exit 1; fi
done
if command -v shellcheck >/dev/null 2>&1; then
  if ! shellcheck "$ROOT"/bin/*; then printf 'FAIL shellcheck\n'; exit 1; fi
else
  printf 'NOTE: shellcheck not installed; skipping.\n'
fi
command -v tmux >/dev/null || { printf 'FAIL tmux is required\n'; exit 1; }

TMP=$(mktemp -d)
FAKEDIR="$TMP/fakebin"
mkdir -p "$FAKEDIR" "$TMP/tmux" "$TMP/notmux"
ln -sf "$ROOT/tests/fake-cli" "$FAKEDIR/grok"
ln -sf "$ROOT/tests/fake-cli" "$FAKEDIR/codex"
ln -sf "$(command -v bash)" "$TMP/notmux/bash"
ln -sf "$(command -v dirname)" "$TMP/notmux/dirname"
export TMUX_TMPDIR="$TMP/tmux"
export PATH="$FAKEDIR:$ROOT/bin:$PATH"
trap 'tmux kill-server >/dev/null 2>&1 || true; rm -rf "$TMP"' EXIT

expect_eq() {
  if [ "$2" = "$3" ]; then return 0; fi
  printf '  %s: expected [%s] got [%s]\n' "$1" "$2" "$3" >&2
  return 1
}
expect_has() {
  case $3 in *"$2"*) return 0;; esac
  printf '  %s: [%s] not found in [%s]\n' "$1" "$2" "$3" >&2
  return 1
}
expect_match() {
  if printf '%s\n' "$3" | grep -Eq -- "$2"; then return 0; fi
  printf '  %s: [%s] does not match /%s/\n' "$1" "$3" "$2" >&2
  return 1
}
expect_range() {
  if [ "$3" -ge "$2" ] && [ "$3" -le "$4" ]; then return 0; fi
  printf '  %s: %s not in [%s,%s]\n' "$1" "$3" "$2" "$4" >&2
  return 1
}
new_env() {
  tmux kill-server >/dev/null 2>&1 || true
  T=$(mktemp -d "$TMP/case.XXXXXXXX")
  export CLI_SESSIONS_HOME="$T/sessions"
  export CLI_LOGS="$T/logs"
  mkdir -p "$CLI_SESSIONS_HOME" "$CLI_LOGS"
  MARKS="$CLI_SESSIONS_HOME/marks"
  REG="$CLI_SESSIONS_HOME/registry"
  unset FAKE_MODE FAKE_ARTIFACT
}
start_fake() {
  sname=$1; scli=$2; fmode=$3
  FAKE_MODE=$fmode; export FAKE_MODE
  tmux set-environment -g FAKE_MODE "$fmode" >/dev/null 2>&1 || true
  if [ $# -ge 4 ]; then
    FAKE_ARTIFACT=$4; export FAKE_ARTIFACT
    tmux set-environment -g FAKE_ARTIFACT "$4" >/dev/null 2>&1 || true
  else
    unset FAKE_ARTIFACT
    tmux set-environment -gu FAKE_ARTIFACT >/dev/null 2>&1 || true
  fi
  cli-session start "$sname" "$scli" "$T" >/dev/null
}

S1() {
  start_fake s1 grok hang
  cli-session send s1 'go' >/dev/null
  pid=$(tmux display-message -p -t '=cs-s1:' '#{pane_pid}')
  [ -n "$pid" ] || { printf '  no pane pid\n' >&2; return 1; }
  pkill -9 -P "$pid" 2>/dev/null || true
  kill -9 "$pid" 2>/dev/null || true
  sleep 1
  out=$(cli-session wait s1 --timeout 30 2>&1); rc=$?
  first=${out%%$'\n'*}
  expect_eq rc 4 "$rc" && expect_has result 'result=dead' "$first"
}
S2() {
  start_fake s2 grok die
  out=$(cli-session wait s2 --timeout 10 2>&1); rc=$?
  first=${out%%$'\n'*}
  expect_eq rc 4 "$rc" && expect_has result 'result=gone' "$first" &&
    expect_eq exitfile 3 "$(cat "$MARKS/s2.exit" 2>/dev/null)" &&
    expect_eq logbytes 0 "$(wc -c < "$CLI_LOGS/s2.tty.log" | tr -d ' ')"
}
S3() {
  start_fake s3 grok hang
  cli-session send s3 'go' >/dev/null
  t0=$SECONDS
  out=$(cli-session wait s3 --timeout 30 --stall 5 2>&1); rc=$?
  elapsed=$((SECONDS-t0))
  first=${out%%$'\n'*}
  expect_eq rc 5 "$rc" && expect_has result 'result=stalled' "$first" &&
    expect_has activity 'activity_age=' "$first" && expect_range elapsed 4 "$elapsed" 9
}
S4() {
  start_fake s4 grok spin
  cli-session send s4 'go' >/dev/null
  out=$(cli-session wait s4 --timeout 30 --stall 5 --artifact "$T/out" 2>&1); rc=$?
  first=${out%%$'\n'*}
  expect_eq rc 5 "$rc" && expect_has artifact 'artifact_bytes=-' "$first"
}
S5() {
  start_fake s5 grok spin-artifact "$T/out"
  cli-session send s5 'go' >/dev/null
  out=$(cli-session wait s5 --timeout 10 --stall 5 --artifact "$T/out" 2>&1); rc=$?
  first=${out%%$'\n'*}
  expect_eq rc 2 "$rc" && expect_has result 'result=timeout' "$first"
}
S6() {
  start_fake s6 grok work
  cli-session send s6 'go' >/dev/null
  out=$(cli-session wait s6 --timeout 30 2>&1); rc=$?
  first=${out%%$'\n'*}
  expect_eq rc 0 "$rc" && expect_has mode 'mode=idle' "$first" &&
    expect_has result 'result=done' "$first" &&
    expect_eq done "$(cat "$MARKS/s6.sent" 2>/dev/null)" "$(cat "$MARKS/s6.done" 2>/dev/null)"
}
S7() {
  start_fake s7 grok hang
  cli-session send s7 'go' >/dev/null
  out=$(cli-session wait s7 --timeout 8 2>&1); rc=$?
  first=${out%%$'\n'*}
  expect_eq rc 2 "$rc" &&
    expect_match format '^\[cli-session wait\] session=s7 cli=grok mode=idle result=timeout elapsed=[0-9]+s$' "$first"
}
S8() {
  start_fake s8 codex work
  cli-session send s8 'go' >/dev/null
  out=$(cli-session wait s8 --timeout 30 2>&1); rc=$?
  first=${out%%$'\n'*}
  expect_eq rc 0 "$rc" && expect_has mode 'mode=hook' "$first" &&
    expect_has result 'result=done' "$first"
}
S9() {
  start_fake s9 grok prompt
  out=$(cli-session wait s9 --timeout 10 2>&1); rc=$?
  first=${out%%$'\n'*}
  expect_eq rc 3 "$rc" && expect_has result 'result=prompt' "$first"
}
S10() {
  start_fake s10 grok silent
  out=$(cli-session wait s10 --stall abc 2>&1); rc=$?
  { [ "$rc" -eq 1 ] && expect_has prefix 'cli-session:' "$out"; } || return 1
  out=$(cli-session wait s10 --artifact 2>&1); rc=$?
  { [ "$rc" -eq 1 ] && expect_has prefix 'cli-session:' "$out"; } || return 1
}

T2_1() {
  start_fake st1 grok silent
  out=$(cli-session status st1 --lines 0 2>&1); rc=$?
  first=${out%%$'\n'*}
  expect_eq rc 0 "$rc" && expect_has result 'result=idle' "$first" &&
    expect_has turn 'turn=none' "$first" &&
    expect_eq lines 1 "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
}
T2_2() {
  start_fake st2 grok work
  cli-session send st2 'go' >/dev/null
  cli-session wait st2 --timeout 30 >/dev/null 2>&1 || true
  out=$(cli-session status st2 --lines 0 2>&1); rc=$?
  first=${out%%$'\n'*}
  expect_eq rc 0 "$rc" && expect_has result 'result=done' "$first" &&
    expect_has mode 'mode=idle' "$first" && expect_has turn 'turn=done' "$first"
}
T2_3() {
  start_fake st3 codex work
  cli-session send st3 'go' >/dev/null
  cli-session wait st3 --timeout 30 >/dev/null 2>&1 || true
  out=$(cli-session status st3 --lines 0 2>&1); rc=$?
  first=${out%%$'\n'*}
  expect_eq rc 0 "$rc" && expect_has result 'result=done' "$first" &&
    expect_has mode 'mode=hook' "$first"
}
T2_4() {
  start_fake st4 grok hang
  cli-session send st4 'go' >/dev/null
  out=$(cli-session status st4 --stall 3 --lines 0 2>&1); rc=$?
  first=${out%%$'\n'*}
  { [ "$rc" -eq 2 ] && expect_has result 'result=active' "$first" &&
    expect_has screen 'screen_age=-' "$first"; } || return 1
  sleep 4
  out=$(cli-session status st4 --stall 3 --lines 0 2>&1); rc=$?
  first=${out%%$'\n'*}
  expect_eq rc2 5 "$rc" && expect_has result2 'result=stalled' "$first"
}
T2_5() {
  start_fake st5 grok silent
  sleep 2
  cli-session send st5 'go' >/dev/null
  sleep 4
  out=$(cli-session status st5 --stall 3 --lines 0 2>&1); rc=$?
  first=${out%%$'\n'*}
  expect_eq rc 5 "$rc" && expect_has result 'result=stalled' "$first" &&
    expect_has logbytes 'log_bytes=0' "$first"
}
T2_6() {
  start_fake st6 grok spin
  cli-session send st6 'go' >/dev/null
  sleep 4
  out=$(cli-session status st6 --stall 3 --artifact "$T/missing" --lines 0 2>&1); rc=$?
  first=${out%%$'\n'*}
  expect_eq rc 5 "$rc" && expect_has result 'result=stalled' "$first" &&
    expect_has artifact 'artifact_bytes=-' "$first"
}
T2_7() {
  start_fake st7 grok die
  sleep 1
  out=$(cli-session status st7 --lines 0 2>&1); rc=$?
  first=${out%%$'\n'*}
  expect_eq rc 4 "$rc" && expect_has result 'result=exited' "$first" &&
    expect_has rcfield 'rc=3' "$first"
}
T2_8() {
  start_fake st8 grok hang
  cli-session send st8 'go' >/dev/null
  pid=$(tmux display-message -p -t '=cs-st8:' '#{pane_pid}')
  pkill -9 -P "$pid" 2>/dev/null || true
  kill -9 "$pid" 2>/dev/null || true
  sleep 1
  out=$(cli-session status st8 --lines 0 2>&1); rc=$?
  first=${out%%$'\n'*}
  expect_eq rc 4 "$rc" && expect_has result 'result=dead' "$first"
}
T2_9() {
  start_fake st9 grok silent
  tmux kill-session -t '=cs-st9' 2>/dev/null || true
  out=$(cli-session status st9 --lines 0 2>&1); rc=$?
  first=${out%%$'\n'*}
  expect_eq rc 4 "$rc" && expect_has result 'result=gone' "$first"
}
T2_10() {
  out=$(cli-session status nosuch --lines 0 2>&1); rc=$?
  first=${out%%$'\n'*}
  expect_eq rc 4 "$rc" && expect_has result 'result=gone' "$first"
}
snapshot_state() {
  find "$MARKS" -type f 2>/dev/null | sort | while IFS= read -r f; do
    case ${f##*/} in *.screen) continue;; esac
    stat -c '%n %Y %s' "$f"
  done
  find "$REG" -type f 2>/dev/null | sort | while IFS= read -r f; do stat -c '%n %Y %s' "$f"; done
}
T2_11() {
  start_fake st11 grok hang
  cli-session send st11 'go' >/dev/null
  before=$(snapshot_state)
  read_before=$(cli-session read st11 20)
  out=$(cli-session status st11 --lines 0 2>&1); rc=$?
  after=$(snapshot_state)
  read_after=$(cli-session read st11 20)
  expect_eq rc 2 "$rc" && expect_eq read "$read_before" "$read_after" &&
    expect_eq state "$before" "$after"
}
T2_12() {
  start_fake st12 grok work
  out=$(cli-session status st12 --lines 0 2>&1); rc=$?
  expect_eq rc 0 "$rc" &&
    expect_eq lines 1 "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
}

T3() {
  start_fake l1 grok work
  cli-session send l1 'go' >/dev/null
  cli-session wait l1 --timeout 30 >/dev/null 2>&1 || true
  start_fake l2 grok die
  sleep 1
  start_fake l3 grok hang
  cli-session send l3 'go' >/dev/null
  pid=$(tmux display-message -p -t '=cs-l3:' '#{pane_pid}')
  pkill -9 -P "$pid" 2>/dev/null || true
  kill -9 "$pid" 2>/dev/null || true
  start_fake l4 grok silent
  tmux kill-session -t '=cs-l4' 2>/dev/null || true
  sleep 1

  out=$(cli-session list)
  header=${out%%$'\n'*}
  expected="NAME${TAB}CLI${TAB}NATIVE_ID${TAB}LABEL${TAB}DIRECTORY${TAB}STATE${TAB}TURN${TAB}LOG_AGE"
  expect_eq header "$expected" "$header" || return 1
  row_l1=$(printf '%s\n' "$out" | grep -E '^l1'$'\t' || true)
  row_l2=$(printf '%s\n' "$out" | grep -E '^l2'$'\t' || true)
  row_l3=$(printf '%s\n' "$out" | grep -E '^l3'$'\t' || true)
  row_l4=$(printf '%s\n' "$out" | grep -E '^l4'$'\t' || true)
  expect_eq l1_state alive "$(printf '%s\n' "$row_l1" | cut -f6)" &&
    expect_eq l1_turn done "$(printf '%s\n' "$row_l1" | cut -f7)" &&
    expect_eq l2_state exited:3 "$(printf '%s\n' "$row_l2" | cut -f6)" &&
    expect_match l3_state '^dead:' "$(printf '%s\n' "$row_l3" | cut -f6)" &&
    expect_eq l4_state gone "$(printf '%s\n' "$row_l4" | cut -f6)" || return 1
  compat="l1${TAB}grok${TAB}$(printf '%s\n' "$row_l1" | cut -f3)${TAB}${TAB}$T"
  expect_eq first5 "$compat" "$(printf '%s\n' "$row_l1" | cut -f1-5)" || return 1
  m1=$(snapshot_state)
  cli-session list >/dev/null
  expect_eq no-side-effects "$m1" "$(snapshot_state)" || return 1
  new_env
  expect_eq empty 1 "$(cli-session list | wc -l | tr -d ' ')"
}

V1() {
  v=$(cli-session --version); rc=$?
  expect_eq rc 0 "$rc" || return 1
  latest=$(grep -m1 -oE '[0-9]+\.[0-9]+\.[0-9]+' "$ROOT/CHANGELOG.md" || true)
  expect_eq version "cli-session $latest" "$v" && expect_eq version2 "cli-session $latest" "$(cli-session version)" &&
    expect_eq no-tmux 0 "$(PATH="$TMP/notmux" "$ROOT/bin/cli-session" --version >/dev/null 2>&1; printf '%s' "$?")"
}

ALL='S1 S2 S3 S4 S5 S6 S7 S8 S9 S10 T2_1 T2_2 T2_3 T2_4 T2_5 T2_6 T2_7 T2_8 T2_9 T2_10 T2_11 T2_12 T3 V1'
if [ $# -gt 0 ]; then selected=" $* "; else selected=" $ALL "; fi
for s in $ALL; do
  case $selected in
    *" $s "*) ;;
    *) continue;;
  esac
  new_env
  if "$s"; then printf 'PASS %s\n' "$s"; pass=$((pass+1)); else printf 'FAIL %s\n' "$s"; fail=$((fail+1)); fi
done
printf 'Summary: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

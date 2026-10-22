#!/usr/bin/env bash
# ==========================================
#  openmcp-ai :: smoke tests
# ==========================================
#  Everything that can be checked without an Android phone:
#
#    - every shell script parses (bash -n)
#    - every JSON asset is valid
#    - the installers survive --help and --dry-run
#    - --dry-run leaves the filesystem alone
#    - --uninstall removes only its own .bashrc block
#    - the banner box stays square with Thai text
#    - package names that no longer exist never come back
#
#  Usage:
#    bash tests/smoke.sh
#    SMOKE_SCHEMA=1 bash tests/smoke.sh   # also validate assets against
#                                        # the live opencode.ai schemas
#
#  Nothing here touches the network unless SMOKE_SCHEMA=1, and nothing here
#  installs anything: every run happens in a throwaway HOME.
#
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0
FAILED_LIST=""

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  G=$'\033[32m'; R=$'\033[31m'; B=$'\033[1m'; D=$'\033[2m'; N=$'\033[0m'
else
  G=""; R=""; B=""; D=""; N=""
fi

section() { printf '\n%s%s%s\n' "$B" "$1" "$N"; }
pass()    { PASS=$((PASS + 1)); printf '  %sok%s   %s\n' "$G" "$N" "$1"; }
fail()    { FAIL=$((FAIL + 1)); FAILED_LIST="${FAILED_LIST}- $1"$'\n'
            printf '  %sFAIL%s %s\n' "$R" "$N" "$1"
            [ -n "${2:-}" ] && printf '       %s%s%s\n' "$D" "$2" "$N"; }

# Run a command, pass if it exits 0, show the tail of the output otherwise.
expect_ok() {
  local name="$1"; shift
  local out
  if out="$("$@" 2>&1)"; then
    pass "$name"
  else
    fail "$name" "exit $? — $(printf '%s' "$out" | tail -n 3 | tr '\n' ' ')"
  fi
}

# Throwaway HOME shaped like a Termux home so install.sh recognises it.
make_fixture() {
  local root
  root="$(mktemp -d)"
  mkdir -p "$root/com.termux/files/usr/bin" \
           "$root/com.termux/files/home"
  mkdir -p "$root/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs/root"
  printf '%s' "$root"
}

# Build a PATH with every system binary except the named ones, then install
# no-op stubs for the container tools. This lets a script believe it is on
# Termux while the real proot-distro is never touched.
make_shim() {
  local dir="$1"; shift
  local hidden=" $* " p n
  mkdir -p "$dir"
  for p in /usr/bin/* /usr/sbin/*; do
    n="${p##*/}"
    case "$hidden" in *" $n "*) continue ;; esac
    [ -e "$dir/$n" ] && continue
    ln -s "$p" "$dir/$n" 2>/dev/null || true
  done
  for n in "$@"; do
    printf '#!/bin/sh\nexit 0\n' > "$dir/$n"
    chmod +x "$dir/$n"
  done
}

# ==========================================================================
section "1. Shell syntax"
# ==========================================================================
syntax_fail=0
while IFS= read -r f; do
  if ! err="$(bash -n "$f" 2>&1)"; then
    fail "syntax: ${f#$REPO_ROOT/}" "$err"
    syntax_fail=1
  fi
done < <(find "$REPO_ROOT" -path "$REPO_ROOT/.git" -prune -o -name '*.sh' -type f -print)
[ "$syntax_fail" -eq 0 ] && pass "all shell scripts parse"
# The skill scripts have no .sh suffix requirement but do have one.
for f in "$REPO_ROOT"/assets/skills/*/scripts/*.sh; do
  [ -f "$f" ] || continue
  if err="$(bash -n "$f" 2>&1)"; then pass "syntax: ${f#$REPO_ROOT/}"; else fail "syntax: ${f#$REPO_ROOT/}" "$err"; fi
done

# ==========================================================================
section "2. JSON assets"
# ==========================================================================
if ! command -v python3 >/dev/null 2>&1; then
  fail "python3 is required for the JSON checks"
else
  for j in "$REPO_ROOT"/assets/*.json; do
    [ -f "$j" ] || continue
    if err="$(python3 -m json.tool "$j" 2>&1 >/dev/null)"; then
      pass "json: ${j#$REPO_ROOT/}"
    else
      fail "json: ${j#$REPO_ROOT/}" "$err"
    fi
  done
fi

# ==========================================================================
section "3. Known-bad package and flag names"
# ==========================================================================
# `nodejs-lts` does not exist on Ubuntu; apt exits 100 and set -e kills the run.
if grep -rqE 'apt(-get)? install[^|]*nodejs-lts' "$REPO_ROOT"/scripts "$REPO_ROOT"/install.sh 2>/dev/null; then
  fail "no script installs the non-existent 'nodejs-lts' package" \
       "found in: $(grep -rlE 'apt(-get)? install[^|]*nodejs-lts' "$REPO_ROOT"/scripts "$REPO_ROOT"/install.sh | tr '\n' ' ')"
else
  pass "no script installs the non-existent 'nodejs-lts' package"
fi

# The old sed range ate two unrelated lines of the user's .bashrc.
if grep -q ',+4d' "$REPO_ROOT/install.sh" 2>/dev/null; then
  fail "install.sh does not over-delete during --uninstall"
else
  pass "install.sh does not over-delete during --uninstall"
fi

# ==========================================================================
section "4. install.sh (Termux side)"
# ==========================================================================
# A throwaway Termux-shaped home keeps every check off the real device and
# makes the suite behave the same on a phone and on a CI runner.
fx="$(make_fixture)"
fx_home="$fx/com.termux/files/home"
fx_prefix="$fx/com.termux/files/usr"
run_install() {
  env OPENMCP_ASSUME_TERMUX=1 \
      HOME="$fx_home" PREFIX="$fx_prefix" OPENMCP_DIR="$REPO_ROOT" \
      bash "$REPO_ROOT/install.sh" "$@"
}

expect_ok "--help exits 0" env OPENMCP_ASSUME_TERMUX=1 bash "$REPO_ROOT/install.sh" --help
expect_ok "--dry-run exits 0" run_install --dry-run
expect_ok "--dry-run --uninstall exits 0 (PURGE was unbound)" run_install --dry-run --uninstall
expect_ok "--dry-run --uninstall --purge exits 0" run_install --dry-run --uninstall --purge

# --dry-run must not create anything.
run_install --dry-run >/dev/null 2>&1
if [ -e "$fx_home/.openmcp_aliases" ]; then
  fail "--dry-run writes nothing" "created .openmcp_aliases"
else
  pass "--dry-run writes nothing"
fi

# A real install run must add its block to .bashrc.
printf '# user line one\nexport KEEP_ME=1\n' > "$fx_home/.bashrc"
install_shim="$fx/shim"
make_shim "$install_shim" git proot-distro pkg
run_fixture_install() {
  env OPENMCP_ASSUME_TERMUX=1 \
      HOME="$fx_home" PREFIX="$fx_prefix" OPENMCP_DIR="$REPO_ROOT" PATH="$install_shim" \
      bash "$REPO_ROOT/install.sh" "$@"
}
run_fixture_install >/dev/null 2>&1
if grep -q 'openmcp-ai / Termux aliases' "$fx_home/.bashrc" 2>/dev/null &&
   [ -f "$fx_home/.openmcp_aliases" ]; then
  pass "install adds its alias block"
else
  fail "install adds its alias block" "$(tr '\n' '|' < "$fx_home/.bashrc" 2>/dev/null)"
fi

# --uninstall must remove its own block and leave the rest of .bashrc alone.
run_fixture_install --uninstall >/dev/null 2>&1
if grep -q 'KEEP_ME' "$fx_home/.bashrc"; then
  pass "--uninstall keeps unrelated .bashrc lines"
else
  fail "--uninstall keeps unrelated .bashrc lines" \
       "remaining: $(tr '\n' '|' < "$fx_home/.bashrc" 2>/dev/null)"
fi
if grep -q 'openmcp-ai / Termux aliases' "$fx_home/.bashrc" 2>/dev/null; then
  fail "--uninstall removes its own .bashrc block"
else
  pass "--uninstall removes its own .bashrc block"
fi
if [ -e "$fx_home/.openmcp_aliases" ]; then
  fail "--uninstall removes the alias file"
else
  pass "--uninstall removes the alias file"
fi

# ==========================================================================
section "5. ubuntu-setup.sh (container side)"
# ==========================================================================
expect_ok "--help exits 0" bash "$REPO_ROOT/scripts/ubuntu-setup.sh" --help
expect_ok "--dry-run exits 0" bash "$REPO_ROOT/scripts/ubuntu-setup.sh" --dry-run

# The plan must still succeed on a machine where none of the tools are
# installed yet - the post-install probes used to abort a dry run.
hostless="$(make_fixture)"
hostless_shim="$hostless/shim"
make_shim "$hostless_shim" node nodejs npm npx opencode opencode2 claude bun bunx
if out="$(env PATH="$hostless_shim" HOME="$hostless/home" \
          bash "$REPO_ROOT/scripts/ubuntu-setup.sh" --dry-run 2>&1)"; then
  pass "--dry-run exits 0 when node/npm/opencode are missing"
else
  fail "--dry-run exits 0 when node/npm/opencode are missing" \
       "$(printf '%s' "$out" | tail -n 3 | tr '\n' ' ')"
fi
if printf '%s' "$out" | grep -q 'nodejs kee\|Unable to locate'; then
  fail "--dry-run mentions only real apt packages"
else
  pass "--dry-run mentions only real apt packages"
fi

# ==========================================================================
section "6. mcp-setup.sh"
# ==========================================================================
expect_ok "--dry-run exits 0" bash "$REPO_ROOT/scripts/mcp-setup.sh" --dry-run
expect_ok "--uninstall --dry-run exits 0" bash "$REPO_ROOT/scripts/mcp-setup.sh" --uninstall --dry-run

# ==========================================================================
section "7. UI layout"
# ==========================================================================
if command -v python3 >/dev/null 2>&1; then
  # Independent width calculation: Thai combining marks are zero-width and
  # only East-Asian Wide/Fullwidth characters take two columns.
  width_prog='
import sys, unicodedata
def width(s):
    total = 0
    for ch in s:
        if unicodedata.category(ch) in ("Mn", "Me", "Cf"):
            continue
        total += 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
    return total
widths = [(width(l), l) for l in sys.stdin.read().splitlines() if l.strip()]
sys.exit(0 if len({w for w, _ in widths}) == 1 else 1)
'
  for title in "openmcp-ai  •  OpenCode + MCP" \
               "openmcp-ai :: ติดตั้งภายใน Ubuntu" \
               "openmcp-ai :: ตรวจสอบสถานะ"; do
    if printf '%s\n' "$title" | TITLE="$title" REPO="$REPO_ROOT" \
         env NO_COLOR=1 bash -c '. "$REPO/scripts/lib/ui.sh"; banner "$TITLE"' \
         | python3 -c "$width_prog"; then
      pass "banner box stays square: $title"
    else
      fail "banner box stays square: $title"
    fi
  done

  # summary_row must pad by display width so Thai labels align with ASCII.
  if cols="$(env NO_COLOR=1 REPO="$REPO_ROOT" bash -c '
        . "$REPO/scripts/lib/ui.sh"
        summary_row "node" "v22.22.1"
        summary_row "รายการ container" "u-list"
      ' | python3 -c '
import sys, unicodedata
def width(s):
    return sum(2 if unicodedata.east_asian_width(c) in ("W","F") else 1
               for c in s if unicodedata.category(c) not in ("Mn","Me","Cf"))
starts = {width(l.split(" ", 2)[1]) for l in sys.stdin.read().splitlines() if l.strip()}
print(len(starts) == 1)
')"; then
    if [ "$cols" = "True" ]; then
      pass "summary rows align across Thai and ASCII labels"
    else
      fail "summary rows align across Thai and ASCII labels"
    fi
  fi
fi

# ==========================================================================
section "8. Live schema (optional: SMOKE_SCHEMA=1)"
# ==========================================================================
if [ "${SMOKE_SCHEMA:-0}" = "1" ]; then
  if ! command -v python3 >/dev/null 2>&1; then
    fail "SMOKE_SCHEMA needs python3"
  elif ! python3 -c 'import jsonschema' 2>/dev/null; then
    fail "SMOKE_SCHEMA needs the jsonschema module" "pip install jsonschema"
  else
    check_schema() {
      local asset="$1" url="$2" tmp
      tmp="$(mktemp)"
      if ! curl -fsSL "$url" -o "$tmp" 2>/dev/null; then
        fail "fetch schema $url"; rm -f "$tmp"; return
      fi
      if python3 - "$asset" "$tmp" <<'PY'
import json, sys, jsonschema
asset, schema_path = sys.argv[1], sys.argv[2]
with open(asset, encoding="utf-8") as fh:
    cfg = json.load(fh)
with open(schema_path, encoding="utf-8") as fh:
    schema = json.load(fh)
errors = sorted(jsonschema.Draft202012Validator(schema).iter_errors(cfg),
                key=lambda e: list(e.path))
for error in errors:
    print(f"{list(error.path)}: {error.message[:200]}")
sys.exit(1 if errors else 0)
PY
      then
        pass "schema: ${asset#$REPO_ROOT/}"
      else
        fail "schema: ${asset#$REPO_ROOT/}"
      fi
      rm -f "$tmp"
    }
    check_schema "$REPO_ROOT/assets/opencode.json" "https://opencode.ai/config.json"
    check_schema "$REPO_ROOT/assets/cli.json" "https://opencode.ai/v2/cli.json"
  fi
else
  printf '  %sskip%s set SMOKE_SCHEMA=1 to validate against the live schemas\n' "$D" "$N"
fi

# ==========================================================================
printf '\n%s%d passed, %d failed%s\n' "$B" "$PASS" "$FAIL" "$N"
if [ "$FAIL" -gt 0 ]; then
  printf '\n%sFailed:%s\n%s' "$R" "$N" "$FAILED_LIST"
  exit 1
fi
exit 0

#!/usr/bin/env bash
#
# check-mcp.sh - health check and configuration audit for MCP servers.
#
# Usage: check-mcp.sh [directory]
#
# Exit codes:
#   0  every reachable server is connected
#   1  at least one server failed
#   2  no servers configured for this location
#
# The audit reads the same configuration files OpenCode reads, so it catches
# problems the status list cannot: an unresolved binary, a missing environment
# variable, or a secret written straight into the config.

set -uo pipefail

DIR="${1:-$PWD}"
if ! cd "$DIR" 2>/dev/null; then
  echo "Cannot enter directory: $DIR" >&2
  exit 2
fi
DIR="$PWD"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
warn() { printf '\033[33m!  %s\033[0m\n' "$1"; }
bad()  { printf '\033[31mx  %s\033[0m\n' "$1"; }
ok()   { printf '\033[32mok %s\033[0m\n' "$1"; }

bold "MCP audit"
echo "Location: $DIR"
echo

bold "Status"
echo "-------"
# A brand new project location can race the config watcher: the first call may
# report nothing even though the config file is already on disk. Retry when a
# project config exists.
has_project_config=0
for candidate in "opencode.json" "opencode.jsonc" ".opencode/opencode.json" ".opencode/opencode.jsonc"; do
  [ -f "$DIR/$candidate" ] && has_project_config=1
done

LIST=""
for _ in 1 2 3; do
  LIST=$(opencode mcp list 2>&1)
  if ! printf '%s' "$LIST" | grep -q "No MCP servers configured"; then
    break
  fi
  [ "$has_project_config" -eq 1 ] || break
  sleep 2
done

if printf '%s' "$LIST" | grep -q "No MCP servers configured"; then
  echo "$LIST"
  echo
  warn "No MCP servers configured for this location."
  exit 2
fi
printf '%s\n' "$LIST"
echo

CONNECTED=$(printf '%s\n' "$LIST" | grep -c '^✓' || true)
PENDING=$(printf '%s\n' "$LIST" | grep -c '^○' || true)
DISABLED=$(printf '%s\n' "$LIST" | grep -cE '^○.*[[:space:]]disabled$' || true)
# A disabled server also prints the pending glyph - do not count it twice.
PENDING=$((PENDING - DISABLED))
FAILED=$(printf '%s\n' "$LIST" | grep -c '^✗' || true)
echo "connected: $CONNECTED   pending: $PENDING   failed: $FAILED   disabled: $DISABLED"
echo

# A server missing "type" is dropped silently and never appears in the list.
# Diff the configured names against the listed names to catch it.
if command -v python3 >/dev/null 2>&1; then
  MISSING=$(python3 - "$DIR" <<'PY'
import json, os, sys

target = sys.argv[1]

def load(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return None

names = set()
def collect(cfg):
    if not isinstance(cfg, dict):
        return
    block = cfg.get("mcp")
    if isinstance(block, dict) and isinstance(block.get("servers"), dict):
        names.update(block["servers"].keys())

global_dir = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config/opencode")
for n in ("opencode.json", "opencode.jsonc"):
    collect(load(os.path.join(global_dir, n)))

dirs = []
probe = target
while True:
    dirs.append(probe)
    parent = os.path.dirname(probe)
    if parent == probe:
        break
    probe = parent
dirs.reverse()

for d in dirs:
    for n in ("opencode.json", "opencode.jsonc"):
        collect(load(os.path.join(d, n)))
for d in dirs:
    for n in ("opencode.json", "opencode.jsonc"):
        collect(load(os.path.join(d, ".opencode", n)))

for name in sorted(names):
    print(name)
PY
)
  LISTED=$(printf '%s\n' "$LIST" | awk '{print $2}' | sort -u)
  for name in $MISSING; do
    if ! printf '%s\n' "$LISTED" | grep -qx "$name"; then
      bad "server '$name' is configured but never appears in opencode mcp list - check its 'type' field"
    fi
  done
fi

if command -v python3 >/dev/null 2>&1; then
  bold "Configuration audit"
  echo "-------------------"
  python3 - "$DIR" <<'PY'
import json, os, re, shutil, sys

target = sys.argv[1]

def load(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except FileNotFoundError:
        return None
    except json.JSONDecodeError as exc:
        print(f"x  {path}: invalid JSON ({exc})")
        return None

# Merge config in OpenCode's precedence order: global first, then direct
# project files from the root down, then .opencode/ files, then system config.
servers = {}
order = []

def merge(cfg, label):
    if not isinstance(cfg, dict):
        return
    block = cfg.get("mcp")
    if not isinstance(block, dict):
        return
    block = block.get("servers")
    if not isinstance(block, dict):
        return
    for name, spec in block.items():
        if name not in servers:
            order.append(name)
        servers[name] = (spec, label)

global_dir = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config/opencode")
for name in ("opencode.json", "opencode.jsonc"):
    merge(load(os.path.join(global_dir, name)), f"global:{name}")

dirs = []
probe = target
while True:
    dirs.append(probe)
    parent = os.path.dirname(probe)
    if parent == probe:
        break
    probe = parent
dirs.reverse()

for d in dirs:
    for name in ("opencode.json", "opencode.jsonc"):
        merge(load(os.path.join(d, name)), f"project:{d}/{name}")
for d in dirs:
    for name in ("opencode.json", "opencode.jsonc"):
        merge(load(os.path.join(d, ".opencode", name)), f"project:{d}/.opencode/{name}")

for name in ("opencode.json", "opencode.jsonc"):
    merge(load(os.path.join("/etc/opencode", name)), f"system:{name}")

if not servers:
    print("(no mcp.servers block found in any configuration file)")
    sys.exit(0)

env_pattern = re.compile(r"^\{env:([A-Za-z_][A-Za-z0-9_]*)\}$")
problems = 0

for name in order:
    spec, source = servers.get(name, ({}, "?"))
    if not isinstance(spec, dict):
        print(f"x  {name}: server entry is not an object")
        problems += 1
        continue

    kind = spec.get("type")
    target_desc = ""
    if kind == "local":
        cmd = spec.get("command") or []
        if not cmd:
            print(f"x  {name}: local server has no command")
            problems += 1
            continue
        exe = cmd[0]
        target_desc = " ".join(cmd)
        if os.path.isabs(exe):
            if os.path.exists(exe):
                print(f"ok {name}: executable found at {exe}")
            else:
                print(f"x  {name}: executable not found: {exe}")
                problems += 1
        elif shutil.which(exe):
            print(f"ok {name}: '{exe}' resolves on PATH")
        elif exe in ("npx", "bunx", "uvx", "pnpx", "npx.cmd"):
            print(f"ok {name}: launcher '{exe}' resolves at launch (pre-install to avoid startup timeouts)")
        else:
            print(f"x  {name}: '{exe}' is not on PATH")
            problems += 1
    elif kind == "remote":
        url = spec.get("url") or ""
        target_desc = url
        if not url.startswith(("http://", "https://")):
            print(f"x  {name}: remote server needs an absolute http(s) url, got '{url}'")
            problems += 1
        else:
            oauth = spec.get("oauth")
            note = "OAuth enabled" if oauth is None else (
                "OAuth disabled" if oauth is False else "OAuth configured")
            print(f"ok {name}: {url} ({note})")
        for header, value in (spec.get("headers") or {}).items():
            match = env_pattern.match(str(value))
            if match:
                var = match.group(1)
                if os.environ.get(var):
                    print(f"ok {name}: header {header} reads from ${var} (set)")
                else:
                    print(f"x  {name}: header {header} reads from ${var} which is NOT set")
                    problems += 1
            else:
                print(f"x  {name}: header {header} holds a literal value; use {{env:NAME}}")
                problems += 1
    else:
        print(f"x  {name}: missing or invalid type '{kind}' (expected 'local' or 'remote')")
        problems += 1
        continue

    for key, value in (spec.get("environment") or {}).items():
        match = env_pattern.match(str(value))
        if match:
            var = match.group(1)
            if not os.environ.get(var):
                print(f"x  {name}: environment {key} reads from ${var} which is NOT set")
                problems += 1

    if spec.get("disabled") is True:
        print(f"!  {name}: configured but disabled")

    print(f"   source: {source}")
    print(f"   target: {target_desc}")

sys.exit(1 if problems else 0)
PY
  AUDIT_STATUS=$?
else
  warn "python3 not available, skipping the configuration audit."
  AUDIT_STATUS=0
fi

echo
if [ "$FAILED" -gt 0 ]; then
  bad "$FAILED server(s) failed. See the error text above and references/troubleshooting.md."
  exit 1
fi
if [ "$PENDING" -gt 0 ]; then
  warn "$PENDING server(s) still pending. Raise mcp.timeout.startup or pre-install the package."
fi
if [ "$AUDIT_STATUS" -ne 0 ]; then
  bad "Configuration audit found problems."
  exit 1
fi
ok "All reachable servers are connected and the configuration audit passed."

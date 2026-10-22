#!/usr/bin/env bash
# ==========================================
#  openmcp-ai :: MCP servers, config and skills
# ==========================================
#  Configures OpenCode with:
#    - the filesystem MCP server
#    - the playwright MCP server (headless chromium)
#    - the global config (opencode.json / cli.json)
#    - the bundled skills (code-review, mcp-free)
#
#  Usage:
#    mcp-setup.sh              install or update
#    mcp-setup.sh --uninstall  remove the MCP config and skills
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${OPENMCP_REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# shellcheck source=lib/ui.sh
. "$SCRIPT_DIR/lib/ui.sh"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
SKILLS_DIR="$CONFIG_DIR/skills"
PLAYWRIGHT_PKG="@playwright/mcp"

UNINSTALL=0
DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall) UNINSTALL=1 ;;
    --dry-run)   DRY_RUN=1 ;;
    -y|--yes)    export OPENMCP_ASSUME_YES=1 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

have() { command -v "$1" >/dev/null 2>&1; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "${DIM}[dry-run]${NC} $*"
    return 0
  fi
  "$@"
}

# ==========================================
#  Uninstall
# ==========================================
if [ "$UNINSTALL" -eq 1 ]; then
  # No step header here - the caller prints its own.
  for cfg in "$CONFIG_DIR/opencode.json" "$CONFIG_DIR/opencode.jsonc"; do
    [ -f "$cfg" ] || continue
    if [ "$DRY_RUN" -eq 1 ]; then
      echo -e "${DIM}[dry-run]${NC} ลบบล็อก \"mcp\" ออกจาก $cfg"
      continue
    fi
    cp "$cfg" "$cfg.bak"
    if python3 - "$cfg" <<'PY'
import json, os, sys

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as fh:
        cfg = json.load(fh)
except Exception as exc:              # JSONC or a broken file
    print(f"parse error: {exc}", file=sys.stderr)
    sys.exit(1)

if not isinstance(cfg, dict) or "mcp" not in cfg:
    sys.exit(3)

cfg.pop("mcp", None)
tmp = path + ".tmp"
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(cfg, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
os.replace(tmp, path)
PY
    then
      ok "ลบบล็อก mcp ออกจาก $cfg (สำรองไว้ที่ $cfg.bak)"
    else
      status=$?
      if [ "$status" -eq 3 ]; then
        info "ไม่พบบล็อก mcp ใน $cfg - ไม่ต้องแก้"
      else
        warn "แก้ $cfg อัตโนมัติไม่ได้ (JSONC?) - ลบบล็อก \"mcp\" เอง (สำรองไว้ที่ $cfg.bak)"
      fi
    fi
  done

  for skill in code-review mcp-free; do
    if [ -d "$SKILLS_DIR/$skill" ]; then
      if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "${DIM}[dry-run]${NC} ลบ skill '$skill'"
      else
        rm -rf "${SKILLS_DIR:?}/$skill"
        ok "ลบ skill '$skill'"
      fi
    fi
  done
  exit 0
fi

banner "openmcp-ai :: MCP servers + skills"

if [ "$DRY_RUN" -eq 1 ]; then
  echo -e "${DIM}[dry-run]${NC} mkdir -p $CONFIG_DIR $SKILLS_DIR"
else
  mkdir -p "$CONFIG_DIR" "$SKILLS_DIR"
fi

# ==========================================
#  Step 1 - global config
# ==========================================
step "[1/4] ตั้งค่า ~/.config/opencode"

CONFIG_FILE="$CONFIG_DIR/opencode.json"

if [ -f "$CONFIG_FILE" ] && [ "$DRY_RUN" -eq 0 ]; then
  if ! python3 -c "import json,sys;json.load(open(sys.argv[1]))" "$CONFIG_FILE" 2>/dev/null; then
    warn "opencode.json เป็น JSONC หรือเสีย - สำรองแล้วเขียนใหม่"
    cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
  fi
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo -e "${DIM}[dry-run]${NC} อัปเดต $CONFIG_FILE จาก assets/opencode.json"
elif [ -f "$REPO_ROOT/assets/opencode.json" ]; then
  python3 - "$CONFIG_FILE" "$REPO_ROOT/assets/opencode.json" <<'PY'
import json, os, sys

target, template = sys.argv[1], sys.argv[2]

def load(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return {}

cfg = load(target)
tpl = load(template)

home = os.path.expanduser("~")

def expand(value):
    """Replace the {HOME} placeholder so the template stays portable."""
    if isinstance(value, str):
        return value.replace("{HOME}", home)
    if isinstance(value, list):
        return [expand(item) for item in value]
    if isinstance(value, dict):
        return {key: expand(item) for key, item in value.items()}
    return value

tpl = expand(tpl)

# merge shallowly, one level deep for "mcp"
for key, value in tpl.items():
    if key == "mcp":
        block = cfg.setdefault("mcp", {})
        for sub, subvalue in value.items():
            if sub == "servers":
                servers = block.setdefault("servers", {})
                for name, spec in subvalue.items():
                    servers.setdefault(name, spec)
            else:
                block.setdefault(sub, subvalue)
    else:
        cfg.setdefault(key, value)

tmp = target + ".tmp"
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(cfg, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
os.replace(tmp, target)
PY
  ok "อัปเดต opencode.json"
else
  warn "ไม่พบ assets/opencode.json - ข้ามการตั้งค่า"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo -e "${DIM}[dry-run]${NC} สร้าง $CONFIG_DIR/cli.json"
elif [ -f "$REPO_ROOT/assets/cli.json" ] && [ ! -f "$CONFIG_DIR/cli.json" ]; then
  cp "$REPO_ROOT/assets/cli.json" "$CONFIG_DIR/cli.json"
  ok "สร้าง cli.json"
elif [ -f "$CONFIG_DIR/cli.json" ]; then
  info "cli.json มีอยู่แล้ว - ไม่แตะ"
fi

# ==========================================
#  Step 2 - skills
# ==========================================
step "[2/4] ติดตั้ง skills"

if [ -d "$REPO_ROOT/assets/skills" ]; then
  for skill_dir in "$REPO_ROOT"/assets/skills/*/; do
    [ -d "$skill_dir" ] || continue
    name="$(basename "$skill_dir")"
    if [ "$DRY_RUN" -eq 1 ]; then
      echo -e "${DIM}[dry-run]${NC} ติดตั้ง skill '$name' -> $SKILLS_DIR/$name"
      continue
    fi
    mkdir -p "$SKILLS_DIR/$name"
    cp -r "$skill_dir". "$SKILLS_DIR/$name/"
    chmod +x "$SKILLS_DIR/$name"/scripts/*.sh 2>/dev/null || true
    ok "ติดตั้ง skill '$name'"
  done
else
  warn "ไม่พบ assets/skills"
fi

# ==========================================
#  Step 3 - playwright browser
# ==========================================
step "[3/4] เตรียมเบราว์เซอร์สำหรับ playwright MCP"

if ! have npx; then
  warn "ไม่พบ npx - ข้ามการติดตั้งเบราว์เซอร์"
else
  # warm the npx cache so the MCP server does not resolve the package at launch
  log "อุ่นแคช npx ..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "${DIM}[dry-run]${NC} npx -y $PLAYWRIGHT_PKG --help"
  else
    npx -y "$PLAYWRIGHT_PKG" --help >/dev/null 2>&1 || true
  fi

  CLI_JS=""
  for candidate in "$HOME"/.npm/_npx/*/node_modules/playwright-core/cli.js; do
    [ -f "$candidate" ] || continue
    # prefer the copy that ships alongside the installed @playwright/mcp
    if [ -d "$(dirname "$candidate")/../@playwright/mcp" ]; then
      CLI_JS="$candidate"
      break
    fi
    [ -z "$CLI_JS" ] && CLI_JS="$candidate"
  done

  if [ -z "$CLI_JS" ]; then
    warn "หา playwright-core CLI ไม่พบ - รันคำสั่งติดตั้งเอง:"
    info "npx -y $PLAYWRIGHT_PKG install-browser"
  else
    info "ใช้ $CLI_JS"
    if [ "$DRY_RUN" -eq 1 ]; then
      echo -e "${DIM}[dry-run]${NC} node $CLI_JS install chromium"
      echo -e "${DIM}[dry-run]${NC} node $CLI_JS install-deps chromium"
    else
      log "ติดตั้ง chromium ..."
      node "$CLI_JS" install chromium >/dev/null 2>&1 \
        && ok "ติดตั้ง chromium แล้ว" \
        || warn "ติดตั้ง chromium ไม่สำเร็จ"

      log "ติดตั้ง OS libraries ที่จำเป็น ..."
      node "$CLI_JS" install-deps chromium >/dev/null 2>&1 \
        && ok "ติดตั้ง OS libraries แล้ว" \
        || warn "ติดตั้ง OS libraries ไม่สำเร็จ (ต้องรันใน container ที่มี root)"
    fi
  fi
fi

# ==========================================
#  Step 4 - verify
# ==========================================
step "[4/4] ตรวจสอบการเชื่อมต่อ"

if have opencode; then
  sleep 2
  mcp_list | sed 's/^/  /'
  echo
else
  warn "ยังไม่ได้ติดตั้ง opencode - ข้ามการตรวจสอบ"
fi

if [ -x "$SKILLS_DIR/mcp-free/scripts/check-mcp.sh" ]; then
  info "ตรวจสอบเพิ่มเติม: bash $SKILLS_DIR/mcp-free/scripts/check-mcp.sh $HOME"
fi

echo
ok "ตั้งค่า MCP เรียบร้อย"
echo -e "${DIM}   ดูคำสั่ง MCP ทั้งหมด: ${NC}${BLUE}opencode mcp list${NC}"
echo

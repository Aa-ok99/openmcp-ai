#!/usr/bin/env bash
# ==========================================
#  openmcp-ai :: inner installer (runs inside the Ubuntu container)
# ==========================================
#  Installs Node, Bun, OpenCode, Claude Code, MCP servers and skills, then
#  wires up the aliases and the cheat sheet.
#
#  Usage:
#    ubuntu-setup.sh                install or update
#    ubuntu-setup.sh --dry-run      show the plan only
#    ubuntu-setup.sh --skip-mcp     skip MCP servers and skills
#    ubuntu-setup.sh --uninstall    remove what openmcp-ai installed
#    ubuntu-setup.sh --purge        also remove OpenCode, Claude Code and Bun
#    ubuntu-setup.sh --verify-only  print the current state and exit
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${OPENMCP_REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# shellcheck source=lib/ui.sh
. "$SCRIPT_DIR/lib/ui.sh"

DRY_RUN=0
SKIP_MCP=0
UNINSTALL=0
VERIFY_ONLY=0
PURGE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)     DRY_RUN=1 ;;
    --skip-mcp)    SKIP_MCP=1 ;;
    --uninstall)   UNINSTALL=1 ;;
    --purge)       PURGE=1 ;;
    --verify-only) VERIFY_ONLY=1 ;;
    -y|--yes)      export OPENMCP_ASSUME_YES=1 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

export DEBIAN_FRONTEND=noninteractive

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "${DIM}[dry-run]${NC} $*"
    return 0
  fi
  "$@"
}

# Runs a command and swallows failures - used for optional components.
run_soft() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "${DIM}[dry-run]${NC} $*"
    return 0
  fi
  "$@" || return 1
}

have() { command -v "$1" >/dev/null 2>&1; }

# Writes a file from stdin. In dry-run mode nothing touches the disk.
write_file() {
  local path="$1"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "${DIM}[dry-run]${NC} เขียน $path"
    cat >/dev/null
    return 0
  fi
  cat > "$path"
}

# Appends to a file from stdin. In dry-run mode nothing touches the disk.
append_file() {
  local path="$1"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "${DIM}[dry-run]${NC} เพิ่มข้อความลง $path"
    cat >/dev/null
    return 0
  fi
  cat >> "$path"
}

# ==========================================
#  Guard: this script must run inside Ubuntu
# ==========================================
if [ -f /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  if [ "${ID:-}" != "ubuntu" ]; then
    warn "คาดว่าเป็น Ubuntu แต่พบ '${ID:-unknown}' - จะทำงานต่อ"
  fi
fi

if [ "$DRY_RUN" -eq 0 ] && [ "$VERIFY_ONLY" -eq 0 ] && [ "$(id -u)" != "0" ]; then
  err "ต้องรันด้วยสิทธิ์ root ภายใน container (ยกเว้น --dry-run / --verify-only)"
  exit 1
fi

# ==========================================
#  Verify only
# ==========================================
if [ "$VERIFY_ONLY" -eq 1 ]; then
  banner "openmcp-ai :: ตรวจสอบสถานะ"
  summary_row "node"    "$(node -v 2>/dev/null || echo 'ไม่ได้ติดตั้ง')"
  summary_row "npm"     "$(npm -v 2>/dev/null || echo 'ไม่ได้ติดตั้ง')"
  summary_row "bun"     "$(bun -v 2>/dev/null || echo 'ไม่ได้ติดตั้ง')"
  summary_row "opencode" "$(opencode --version 2>/dev/null || echo 'ไม่ได้ติดตั้ง')"
  summary_row "claude"  "$(claude --version 2>/dev/null || echo 'ไม่ได้ติดตั้ง')"
  summary_row "npm prefix" "$(npm config get prefix 2>/dev/null || echo '?')"
  echo
  if [ "$SKIP_MCP" -eq 0 ]; then
    summary_row "MCP" "$(mcp_list | tr '\n' ' ' || echo '?')"
    echo
  fi
  summary_row "aliases" "$([ -f "$HOME/.opencode_aliases" ] && echo 'พร้อม' || echo 'ยังไม่ได้ตั้ง')"
  summary_row "cheatsheet" "$([ -f "$HOME/OPCODE-CHEATSHEET.txt" ] && echo 'พร้อม' || echo 'ยังไม่ได้ตั้ง')"
  echo
  exit 0
fi

# ==========================================
#  Uninstall
# ==========================================
if [ "$UNINSTALL" -eq 1 ]; then
  banner "openmcp-ai :: ถอนการติดตั้ง"

  step "[1/5] ถอน MCP servers และ skills"
  if [ -f "$REPO_ROOT/scripts/mcp-setup.sh" ]; then
    un_args=("--uninstall")
    [ "$DRY_RUN" -eq 1 ] && un_args+=("--dry-run")
    run bash "$REPO_ROOT/scripts/mcp-setup.sh" "${un_args[@]}"
  fi

  step "[2/5] ถอน alias และ cheat sheet"
  run rm -f "$HOME/.opencode_aliases" "$HOME/OPCODE-CHEATSHEET.txt"
  if [ -f "$HOME/.bashrc" ]; then
    # Two-line marker block: the comment and the `source` line.
    run sed -i '/^# openmcp-ai \/ Ubuntu aliases$/,+1d' "$HOME/.bashrc"
  fi
  ok "ลบ alias และ cheat sheet แล้ว"

  if [ "$PURGE" -eq 1 ]; then
    step "[3/5] ถอนแพ็กเกจ npm global และ Bun (--purge)"
    run npm uninstall -g @opencode/cli 2>/dev/null || true
    run npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true
    ok "ถอน OpenCode และ Claude Code แล้ว"
    run rm -rf "$HOME/.bun"
    ok "ลบ Bun แล้ว"
  else
    step "[3/5] ข้ามการถอนแพ็กเกจ npm global"
    info "OpenCode / Claude Code / Bun ยังอยู่ - ใช้ --purge ถ้าต้องการถอนด้วย"
  fi

  step "[4/5] ตรวจสอบผล"
  if [ "$DRY_RUN" -eq 0 ]; then
    if [ -f "$HOME/.opencode_aliases" ]; then
      warn "alias ยังอยู่"
    else
      ok "alias ถูกถอนแล้ว"
    fi
  fi

  step "[5/5] สรุป"
  ok "ถอนการติดตั้งของ openmcp-ai เสร็จแล้ว"
  echo -e "  ${DIM}แพ็กเกจระบบของ Ubuntu ไม่ได้ถูกแตะ - ถ้าต้องการ${NC}"
  echo -e "  ${BLUE}apt remove nodejs${NC}"
  echo
  exit 0
fi

banner "openmcp-ai :: ติดตั้งภายใน Ubuntu"

# ==========================================
#  Step 1 - system packages
# ==========================================
step "[1/6] อัปเดตและติดตั้งแพ็กเกจระบบ"

run apt-get update -qq
run apt-get upgrade -y -qq
run apt-get install -y -qq \
  curl ca-certificates git build-essential unzip jq xz-utils python3 python3-venv
ok "แพ็กเกจระบบพร้อม"

# ==========================================
#  Step 2 - Node.js + npm
# ==========================================
step "[2/6] ตรวจสอบ Node.js และ npm"

# Claude Code requires Node >= 22. Ubuntu 26.04 ships Node 22 through the
# `nodejs` package. There is no `nodejs-lts` package on Ubuntu - apt would
# fail with "Unable to locate package" and abort the whole install.
MIN_NODE_MAJOR=22

node_major() {
  node -v 2>/dev/null | sed -E 's/^v([0-9]+)\..*/\1/' | grep -E '^[0-9]+$' || echo 0
}

if have node && have npm; then
  ok "Node.js มีอยู่แล้ว: $(node -v)  npm: $(npm -v)"
else
  warn "ไม่พบ Node.js - ติดตั้ง nodejs + npm ผ่าน apt"
  run apt-get install -y -qq nodejs npm
  if [ "$DRY_RUN" -eq 1 ]; then
    info "[dry-run] ข้ามการตรวจสอบ Node.js หลังติดตั้ง"
  elif have node; then
    ok "ติดตั้ง Node.js แล้ว: $(node -v)"
  else
    err "ติดตั้ง Node.js ไม่สำเร็จ"
    exit 1
  fi
fi

# A distro whose Node is older than v22 breaks Claude Code. Try NodeSource,
# then carry on: OpenCode ships its own binary and does not need a new Node.
if [ "$DRY_RUN" -eq 0 ] && have node && [ "$(node_major)" -lt "$MIN_NODE_MAJOR" ]; then
  warn "Node $(node -v) เก่ากว่า v${MIN_NODE_MAJOR} - Claude Code ต้องใช้ v${MIN_NODE_MAJOR} ขึ้นไป"
  log "ติดตั้ง Node.js ${MIN_NODE_MAJOR}.x จาก NodeSource ..."
  if run_soft bash -c "curl -fsSL https://deb.nodesource.com/setup_${MIN_NODE_MAJOR}.x | bash -" \
     && run_soft apt-get install -y -qq nodejs; then
    ok "อัปเกรด Node.js แล้ว: $(node -v)"
  else
    warn "อัปเกรด Node.js ไม่สำเร็จ - OpenCode ยังใช้ได้ แต่ Claude Code จะรันไม่ได้"
  fi
fi

# npm global ไปที่ /usr/local เพื่อให้อยู่ใน PATH ของทุก user
if [ "$DRY_RUN" -eq 1 ]; then
  info "[dry-run] npm prefix -> /usr/local"
else
  if [ "$(npm config get prefix 2>/dev/null)" != "/usr/local" ]; then
    log "ตั้ง npm prefix เป็น /usr/local ..."
    run npm config set prefix /usr/local
  fi
  ok "npm prefix: $(npm config get prefix)"
fi

# ==========================================
#  Step 3 - Bun (ทางเลือก - proot บางครั้งรันไม่ได้)
# ==========================================
step "[3/6] ติดตั้ง Bun (ทางเลือก)"

if have bun; then
  ok "Bun มีอยู่แล้ว: $(bun -v 2>/dev/null || echo '?')"
else
  info "กำลังติดตั้ง Bun จาก bun.sh ..."
  if [ "$DRY_RUN" -eq 0 ]; then
    curl -fsSL https://bun.sh/install | bash >/dev/null 2>&1 || true
  else
    echo -e "${DIM}[dry-run]${NC} curl -fsSL https://bun.sh/install | bash"
  fi
  export PATH="$HOME/.bun/bin:$PATH"
  if [ "$DRY_RUN" -eq 1 ]; then
    info "[dry-run] จะข้าม Bun ถ้าติดตั้งแล้วยังรันไม่ได้ใน proot"
  elif have bun && bun -v >/dev/null 2>&1; then
    ok "ติดตั้ง Bun แล้ว: $(bun -v)"
  else
    warn "Bun ใช้งานไม่ได้ใน proot - ข้ามไปก่อน (ไม่กระทบ OpenCode)"
  fi
fi

# ==========================================
#  Step 4 - OpenCode + Claude Code
# ==========================================
step "[4/6] ติดตั้ง OpenCode และ Claude Code"

# ชื่อแพ็กเกจปัจจุบันคือ @opencode/cli - opencode-ai เป็นแพ็กเกจเก่า (v1.x)
OPENCODE_PKG="@opencode/cli"
CLAUDE_PKG="@anthropic-ai/claude-code"

if have opencode; then
  ok "OpenCode มีอยู่แล้ว: $(opencode --version 2>/dev/null || echo '?')"
  if confirm "อัปเดต OpenCode เป็นเวอร์ชันล่าสุด?"; then
    run npm install -g "$OPENCODE_PKG@latest"
    if [ "$DRY_RUN" -eq 0 ]; then
      ok "อัปเดต OpenCode แล้ว: $(opencode --version 2>/dev/null || echo '?')"
    fi
  fi
else
  run npm install -g "$OPENCODE_PKG@latest"
  if [ "$DRY_RUN" -eq 1 ]; then
    info "[dry-run] ข้ามการตรวจสอบ OpenCode หลังติดตั้ง"
  elif have opencode; then
    ok "ติดตั้ง OpenCode แล้ว: $(opencode --version 2>/dev/null || echo '?')"
  else
    err "ติดตั้ง OpenCode ไม่สำเร็จ"
    exit 1
  fi
fi

if have claude; then
  ok "Claude Code มีอยู่แล้ว: $(claude --version 2>/dev/null || echo '?')"
  if confirm "อัปเดต Claude Code เป็นเวอร์ชันล่าสุด?"; then
    run npm install -g "$CLAUDE_PKG@latest"
    if [ "$DRY_RUN" -eq 0 ]; then
      ok "อัปเดต Claude Code แล้ว: $(claude --version 2>/dev/null || echo '?')"
    fi
  fi
else
  run npm install -g "$CLAUDE_PKG@latest"
  if [ "$DRY_RUN" -eq 1 ]; then
    info "[dry-run] ข้ามการตรวจสอบ Claude Code หลังติดตั้ง"
  elif have claude; then
    ok "ติดตั้ง Claude Code แล้ว: $(claude --version 2>/dev/null || echo '?')"
  else
    warn "ติดตั้ง Claude Code ไม่สำเร็จ - ข้ามไปก่อน"
  fi
fi

# ==========================================
#  Step 5 - MCP servers and skills
# ==========================================
step "[5/6] ติดตั้ง MCP servers และ skills"

if [ "$SKIP_MCP" -eq 1 ]; then
  warn "ข้ามการติดตั้ง MCP (--skip-mcp)"
else
  mcp_args=()
  # `run` skips execution in dry-run, so this only matters when the caller
  # runs mcp-setup.sh directly - still, keep the plan honest about the flag.
  [ "$DRY_RUN" -eq 1 ] && mcp_args+=("--dry-run")
  run bash "$REPO_ROOT/scripts/mcp-setup.sh" "${mcp_args[@]}"
fi

# ==========================================
#  Step 6 - aliases and cheat sheet
# ==========================================
step "[6/6] สร้าง alias และ cheat sheet"

write_file "$HOME/.opencode_aliases" <<'EOF'
# ==========================================
# Aliases สำหรับ openmcp-ai (ภายใน Ubuntu)
# ==========================================

# --- OpenCode ---
alias oc='opencode'
alias oc-h='opencode --help'
alias oc-v='opencode --version'
alias oc-mcp='opencode mcp list'
alias oc-mcp-check="$HOME/.config/opencode/skills/mcp-free/scripts/check-mcp.sh $HOME"

# --- Claude Code ---
alias cc='claude'
alias cc-v='claude --version'

# --- Node / npm ---
alias node-version='node -v && npm -v'
alias npm-ls='npm ls -g --depth=0'
alias npm-root='npm root -g'

# --- อัปเดตเครื่องมือ ---
alias update-opencode='npm install -g @opencode/cli@latest'
alias reinstall-opencode='npm uninstall -g @opencode/cli && npm install -g @opencode/cli@latest'
alias update-claude='npm install -g @anthropic-ai/claude-code@latest'
alias update-all='npm install -g @opencode/cli@latest @anthropic-ai/claude-code@latest'

# --- ระบบ ---
alias u-root='cd /root && ls -la'
alias show-aliases="grep '^alias' ~/.opencode_aliases"
EOF

if ! grep -q ".opencode_aliases" "$HOME/.bashrc" 2>/dev/null; then
  append_file "$HOME/.bashrc" <<'EOF'

# openmcp-ai / Ubuntu aliases
source ~/.opencode_aliases
EOF
  ok "เพิ่ม alias เข้า .bashrc แล้ว"
else
  info "alias มีอยู่แล้วใน .bashrc"
fi

write_file "$HOME/OPCODE-CHEATSHEET.txt" <<'EOF'
╔══════════════════════════════════════════════════════════════╗
║      📘 openmcp-ai - คู่มือคำสั่งลัดสำหรับ Ubuntu        ║
╚══════════════════════════════════════════════════════════════╝

🔹 OpenCode
──────────────────────────────────────────────────────────────
  opencode          เปิด OpenCode AI
  oc                alias ย่อของ opencode
  oc-v              เช็คเวอร์ชัน
  oc-h              ดูคำสั่งทั้งหมด
  oc-mcp            ดูสถานะ MCP servers
  oc-mcp-check      ตรวจสอบ MCP + config ทั้งหมด

🔹 Claude Code
──────────────────────────────────────────────────────────────
  claude            เปิด Claude Code
  cc                alias ย่อของ claude
  cc-v              เช็คเวอร์ชัน

🔹 Node / npm
──────────────────────────────────────────────────────────────
  node-version      เช็ค Node.js + npm
  npm-ls            รายการแพ็กเกจ global
  npm-root          โฟลเดอร์แพ็กเกจ global

🔹 อัปเดต
──────────────────────────────────────────────────────────────
  update-opencode   อัปเดต OpenCode
  reinstall-opencode ถอนแล้วติดตั้งใหม่
  update-claude     อัปเดต Claude Code
  update-all        อัปเดตทั้งสองตัว

🔹 ระบบ
──────────────────────────────────────────────────────────────
  u-root            cd เข้า /root
  show-aliases      แสดง alias ทั้งหมด

🔹 MCP servers ที่ติดตั้ง
──────────────────────────────────────────────────────────────
  filesystem        อ่าน/เขียนไฟล์ในไดเรกทอรีที่อนุญาต
  playwright        ควบคุมเบราว์เซอร์ (headless chromium)

╔══════════════════════════════════════════════════════════════╗
║  💡 ดูไฟล์นี้เมื่อลืม:  cat ~/OPCODE-CHEATSHEET.txt          ║
╚══════════════════════════════════════════════════════════════╝
EOF

ok "สร้าง alias และ cheat sheet แล้ว"

# ---------- Finish ----------
echo
printf "%b\n" "$(grad " ╔══════════════════════════════════════╗")"
printf "%b\n" "${BOLD}${GREEN} 🎉 ติดตั้งภายใน container เรียบร้อย${RESET}"
printf "%b\n" "$(grad " ╚══════════════════════════════════════╝")"
echo
echo -e "${CYAN}📋 สรุป:${NC}"
summary_row "opencode" "$(opencode --version 2>/dev/null || echo '?')"
summary_row "claude" "$(claude --version 2>/dev/null || echo '?')"
summary_row "node" "$(node -v 2>/dev/null || echo '?')"
summary_row "bun" "$(bun -v 2>/dev/null || echo 'ไม่ได้ติดตั้ง')"
echo
echo -e "${YELLOW}💡 โหลด alias ทันที:${NC} ${BLUE}source ~/.bashrc${NC}"
echo

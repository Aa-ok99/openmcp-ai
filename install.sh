#!/usr/bin/env bash
# ==========================================
#  openmcp-ai :: outer installer (runs on Termux)
# ==========================================
#  Prepares the host: proot-distro + an Ubuntu container, then hands over to
#  scripts/ubuntu-setup.sh which runs inside the container.
#
#  Usage:
#    install.sh                 install or update everything
#    install.sh --dry-run       show the plan without touching the system
#    install.sh --skip-mcp      skip MCP servers and skills
#    install.sh --uninstall     remove what openmcp-ai installed
#    install.sh --purge         also remove OpenCode, Claude Code and Bun
#
set -euo pipefail

REPO_URL="https://github.com/Aa-ok99/openmcp-ai.git"
REPO_BRANCH="main"
REPO_DIR="${OPENMCP_DIR:-}"
DISTRO="${OPENMCP_DISTRO:-ubuntu}"
DRY_RUN=0
SKIP_MCP=0
UNINSTALL=0

# ---------- Arguments ----------
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)      DRY_RUN=1 ;;
    --skip-mcp)     SKIP_MCP=1 ;;
    --uninstall)    UNINSTALL=1 ;;
    --purge)        PURGE=1 ;;
    --distro)       DISTRO="${2:-}"; shift ;;
    --repo-dir)     REPO_DIR="${2:-}"; shift ;;
    -y|--yes)       export OPENMCP_ASSUME_YES=1 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      echo "unknown option: $1" >&2
      exit 2 ;;
  esac
  shift
done

# ---------- Locate the Termux side ----------
# proot-distro only works on the Termux side, never inside a proot session.
# Inside a container the Termux prefix is still visible, so check for the
# proot session itself before trusting the prefix.
self_root="$(readlink -f /proc/self/root 2>/dev/null || echo "")"
if [ -n "$self_root" ] && printf '%s' "$self_root" | grep -q "proot-distro/containers"; then
  echo "คุณอยู่ภายใน container อยู่แล้ว - ให้รันสคริปต์ชั้นในแทน:" >&2
  echo "    bash ${REPO_DIR:-~/.openmcp}/scripts/ubuntu-setup.sh" >&2
  exit 1
fi

if [ -n "${PREFIX:-}" ] && [ -d "$PREFIX" ]; then
  TERMUX_PREFIX="$PREFIX"
elif [ -d /data/data/com.termux/files/usr ]; then
  TERMUX_PREFIX=/data/data/com.termux/files/usr
else
  echo "This installer must run on Termux (proot-distro is not available here)." >&2
  echo "If you are already inside a proot container, run scripts/ubuntu-setup.sh directly:" >&2
  echo "    bash ~/.openmcp/scripts/ubuntu-setup.sh" >&2
  exit 1
fi

if [ -n "${TERMUX_HOME:-}" ] && [ -d "${TERMUX_HOME:-}" ]; then
  : # explicit override wins
elif [ -n "${HOME:-}" ] && [ -d "${HOME:-}" ] && printf '%s' "$HOME" | grep -q "com.termux/files/home"; then
  TERMUX_HOME="$HOME"
else
  TERMUX_HOME=/data/data/com.termux/files/home
fi
CONTAINERS_DIR="$TERMUX_PREFIX/var/lib/proot-distro/containers"
ROOTFS="$CONTAINERS_DIR/$DISTRO/rootfs"
[ -n "$REPO_DIR" ] || REPO_DIR="$TERMUX_HOME/.openmcp"

# The Termux home is bind-mounted into the container at the same path, so the
# repository is reachable from both sides without copying.
REPO_ROOT_IN_CONTAINER="$REPO_DIR"

# ---------- Minimal UI fallback ----------
# The full UI lives in scripts/lib/ui.sh, which is only available once the
# repository has been fetched. These stubs keep the script usable until then
# and are replaced by the real ones as soon as ui.sh is sourced.
DIM=""
NC=""
banner() { printf '\n=== openmcp-ai ===\n'; }
log()  { echo "▸ $*"; }
ok()   { echo "✓ $*"; }
warn() { echo "! $*"; }
err()  { echo "✗ $*" >&2; }
step() { echo; echo ">>> $*"; }
info() { echo "   $*"; }

# ---------- run wrapper (honours --dry-run) ----------
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "${DIM}[dry-run]${NC} $*"
    return 0
  fi
  "$@"
}

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
#  Step 0 - fetch the repository
# ==========================================
step "[0/6] ดึงโค้ด openmcp-ai"

if [ -d "$REPO_DIR/.git" ]; then
  log "อัปเดต repo ที่ $REPO_DIR ..."
  run git -C "$REPO_DIR" pull --ff-only origin "$REPO_BRANCH"
else
  log "โคลน repo ลง $REPO_DIR ..."
  run git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$REPO_DIR"
fi

if [ ! -f "$REPO_DIR/scripts/lib/ui.sh" ]; then
  err "โค้ง repo ไม่สมบูรณ์ (ไม่พบ scripts/lib/ui.sh)"
  exit 1
fi

# shellcheck source=scripts/lib/ui.sh
. "$REPO_DIR/scripts/lib/ui.sh"

# The real UI is available now - redraw the banner with it.
banner "openmcp-ai  •  OpenCode + MCP"

# ==========================================
#  Step 1 - proot-distro
# ==========================================
step "[1/6] ติดตั้ง proot-distro"

if [ -x "$TERMUX_PREFIX/bin/proot-distro" ]; then
  ok "proot-distro พร้อมใช้งาน"
else
  log "pkg install proot-distro ..."
  run pkg install proot-distro -y
fi

# ==========================================
#  Step 2 - Ubuntu container
# ==========================================
step "[2/6] เตรียม container: $DISTRO"

if [ -d "$ROOTFS" ]; then
  ok "container '$DISTRO' มีอยู่แล้ว"
else
  warn "ไม่พบ container '$DISTRO' - กำลังดาวน์โหลด (ใช้เวลา 2-5 นาที)"
  run proot-distro install "$DISTRO"
fi

# ==========================================
#  Step 3 - hand over to the inner script
# ==========================================
step "[3/6] ติดตั้งเครื่องมือภายใน container"

if [ "$UNINSTALL" -eq 1 ]; then
  log "ถอนการติดตั้งภายใน container ..."
  inner_uninstall=("--uninstall")
  [ "$PURGE" -eq 1 ] && inner_uninstall+=("--purge")
  run proot-distro login "$DISTRO" -- bash "$REPO_ROOT_IN_CONTAINER/scripts/ubuntu-setup.sh" "${inner_uninstall[@]}"
else
  inner_args=()
  [ "$DRY_RUN" -eq 1 ] && inner_args+=("--dry-run")
  [ "$SKIP_MCP" -eq 1 ] && inner_args+=("--skip-mcp")
  run proot-distro login "$DISTRO" -- bash "$REPO_ROOT_IN_CONTAINER/scripts/ubuntu-setup.sh" "${inner_args[@]}"
fi

# ==========================================
#  Step 4 - Termux side aliases
# ==========================================
step "[4/6] ตั้ง alias ฝั่ง Termux"

if [ "$UNINSTALL" -eq 1 ]; then
  run sed -i '/openmcp-ai \/ Termux aliases/,+4d' "$TERMUX_HOME/.bashrc"
  ok "ถอด alias ฝั่ง Termux แล้ว"
else
  write_file "$TERMUX_HOME/.openmcp_aliases" <<EOF
# ==========================================
# Aliases สำหรับ openmcp-ai (ฝั่ง Termux)
# ==========================================

# เข้า container
alias u="proot-distro login $DISTRO"
alias u-root="proot-distro login $DISTRO -- bash -lc 'cd /root && exec bash -l'"

# ดูไฟล์ฝั่ง Termux native จากใน container
alias c="ls -la /data/data/com.termux/files/home"

# จัดการ container
alias u-list="proot-distro list"
alias u-install="proot-distro install $DISTRO"
alias u-remove="proot-distro remove $DISTRO"

# อัปเดต openmcp-ai
alias openmcp-update="git -C $REPO_DIR pull --ff-only origin $REPO_BRANCH"
alias openmcp-log="tail -f $TERMUX_HOME/.openmcp/install.log"
EOF
  chmod +x "$TERMUX_HOME/.openmcp_aliases" 2>/dev/null || true

  if ! grep -q ".openmcp_aliases" "$TERMUX_HOME/.bashrc" 2>/dev/null; then
    append_file "$TERMUX_HOME/.bashrc" <<'EOF'

# openmcp-ai / Termux aliases
source ~/.openmcp_aliases
EOF
    ok "เพิ่ม alias เข้า .bashrc แล้ว"
  else
    info "alias มีอยู่แล้วใน .bashrc"
  fi

  # ลิงก์ไปยัง rootfs ของ container เพื่อแวะไปดูไฟล์ฝั่ง Termux ได้ง่าย
  if [ -d "$ROOTFS/root" ]; then
    run ln -sfn "$ROOTFS/root" "$TERMUX_HOME/u_root"
    ok "ลิงก์ u_root -> $ROOTFS/root"
  fi
fi

# ==========================================
#  Step 5 - verify
# ==========================================
step "[5/6] ตรวจสอบผลลัพธ์"

if [ "$UNINSTALL" -eq 1 ]; then
  ok "ถอนการติดตั้งเสร็จแล้ว"
else
  run proot-distro login "$DISTRO" -- bash "$REPO_ROOT_IN_CONTAINER/scripts/ubuntu-setup.sh" --verify-only
fi

# ==========================================
#  Step 6 - summary
# ==========================================
step "[6/6] เสร็จสิ้น"

echo -e "${CYAN}📋 สิ่งที่พร้อมใช้งาน:${NC}"
summary_row "เข้า container" "u          (proot-distro login $DISTRO)"
summary_row "ดูไฟล์ Termux" "c"
summary_row "รายการ container" "u-list"
summary_row "อัปเดต openmcp-ai" "openmcp-update"

echo
echo -e "${YELLOW}💡 เปิดเทอร์มินัลใหม่เพื่อโหลด alias:${NC}"
echo -e "  ${BLUE}exec bash -l${NC}"
echo -e "  ${BLUE}u${NC}   ${DIM}แล้วรัน${NC} ${BLUE}opencode${NC}"
echo

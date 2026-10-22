#!/usr/bin/env bash
# ==========================================
#  openmcp-ai :: shared terminal UI helpers
# ==========================================
#  Sourced by install.sh and every script under scripts/.
#  Animations degrade to plain text when stdout is not a TTY.

# ---------- Colors ----------
if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  RESET="\033[0m"
  BOLD="\033[1m"
  DIM="\033[2m"
  RED="\033[0;31m"
  GREEN="\033[0;32m"
  YELLOW="\033[1;33m"
  BLUE="\033[0;34m"
  MAGENTA="\033[0;35m"
  CYAN="\033[0;36m"
  WHITE="\033[0;37m"
else
  RESET=""; BOLD=""; DIM=""
  RED=""; GREEN=""; YELLOW=""; BLUE=""; MAGENTA=""; CYAN=""; WHITE=""
fi

NC="$RESET"

# ---------- Animation toggle ----------
# Interactive terminal -> animate. Piped, CI, or --no-animation -> plain.
if [ -t 1 ] && [ "${OPENMCP_NO_ANIM:-}" = "" ]; then
  ANIMATE=1
else
  ANIMATE=0
fi

# ---------- Helpers ----------
clear_line() { printf "\r\033[K"; }

have() { command -v "$1" >/dev/null 2>&1; }

# Gradient text, one colour per character.
grad() {
  local s="$1"
  local colors=("$CYAN" "$BLUE" "$MAGENTA" "$YELLOW" "$GREEN")
  local out="" i=0
  local len=${#s}
  local j
  for ((j = 0; j < len; j++)); do
    local ch="${s:j:1}"
    out+="${colors[$((i % ${#colors[@]}))]}${ch}${RESET}"
    i=$((i + 1))
  done
  echo -e "$out"
}

log()  { echo -e "${BOLD}${CYAN}➜${RESET} $*"; }
ok()   { echo -e "${BOLD}${GREEN}✓${RESET} $*"; }
warn() { echo -e "${BOLD}${YELLOW}!${RESET} $*"; }
err()  { echo -e "${BOLD}${RED}✗${RESET} $*" >&2; }
step() { echo -e "\n${YELLOW}>>> $*${NC}"; }
info() { echo -e "${DIM}   $*${NC}"; }

# Framed banner. The title is plain text; padding is computed from the real
# display width so Thai text (double width) lines up correctly.
BANNER_WIDTH=42

display_width() {
  local s="$1" w=0 i ch code
  local LC_ALL=C.UTF-8
  for ((i = 0; i < ${#s}; i++)); do
    ch="${s:i:1}"
    printf -v code "%d" "'$ch" 2>/dev/null || code=0
    if (( code >= 0x0E00 && code <= 0x0E7F )); then
      w=$((w + 2))
    elif (( code >= 0x1F300 && code <= 0x1FAFF )); then
      w=$((w + 2))
    else
      w=$((w + 1))
    fi
  done
  printf '%d' "$w"
}

banner() {
  local title="$1"
  local width="$BANNER_WIDTH"
  local pad=$(( width - $(display_width "$title") ))
  [ "$pad" -lt 0 ] && pad=0
  echo
  printf "%b\n" "$(grad " ╔══════════════════════════════════════════╗")"
  printf "%b\n" "$(grad " ║${title}$(printf '%*s' "$pad" '')║")"
  printf "%b\n" "$(grad " ╚══════════════════════════════════════════╝")"
  echo
}

# `opencode mcp list` with a retry. The first read after the working directory
# changes can race the config watcher and report nothing at all.
mcp_list() {
  local out="" attempt
  for attempt in 1 2 3; do
    out="$(opencode mcp list 2>/dev/null || true)"
    if [ -n "$out" ] && ! printf '%s' "$out" | grep -q "No MCP servers configured"; then
      printf '%s\n' "$out"
      return 0
    fi
    [ "$attempt" -lt 3 ] && sleep 2
  done
  printf '%s\n' "$out"
  return 1
}

# Run a command with a spinner while it works.
spinner_run() {
  local msg="$1"; shift
  if [ "$ANIMATE" -eq 0 ]; then
    log "$msg"
    "$@"
    return $?
  fi
  echo -en "${BOLD}${BLUE}•${RESET} ${msg} "
  "$@" >/dev/null 2>&1 &
  local pid=$!
  local spin='|/-\'
  local i=0
  while kill -0 "$pid" >/dev/null 2>&1; do
    i=$(( (i + 1) % 4 ))
    echo -ne "${spin:$i:1}"
    sleep 0.1
    echo -ne "\b"
  done
  wait "$pid"
  local status=$?
  echo -e "${DIM}done${NC}"
  return $status
}

# Run a command with a progress bar while it works.
bar_run() {
  local msg="$1"; shift
  if [ "$ANIMATE" -eq 0 ]; then
    log "$msg"
    "$@"
    return $?
  fi
  "$@" >/dev/null 2>&1 &
  local pid=$!

  local width=28
  local blocks='▢▣▤▥▦▧▨▩█'
  local i=0

  while kill -0 "$pid" >/dev/null 2>&1; do
    clear_line
    local filled=$(( i % (width + 1) ))
    local empty=$(( width - filled ))

    local c
    case $((i % 5)) in
      0) c="$CYAN" ;;
      1) c="$BLUE" ;;
      2) c="$MAGENTA" ;;
      3) c="$YELLOW" ;;
      4) c="$GREEN" ;;
    esac

    local barstr=""
    local k
    for ((k = 0; k < filled; k++)); do barstr+="${c}█${RESET}"; done
    for ((k = 0; k < empty; k++)); do barstr+="${DIM}░${NC}"; done

    printf "%b %b%b%b %b[%s]%b %s\n" \
      "${BOLD}${CYAN}•${NC}" "${BOLD}" "${WHITE}" "${NC}" \
      "${DIM}" "$barstr" "${NC}" "$msg"

    sleep 0.08
    i=$((i + 1))
  done

  clear_line
  wait "$pid"
  local status=$?
  echo -e "${BOLD}${GREEN}✓${NC} ${msg} ${DIM}done${NC}"
  return $status
}

# Print a summary table of installed components.
summary_row() {
  printf "  ${GREEN}%-22s${NC} %s\n" "$1" "$2"
}

# Confirm an action unless --yes was passed.
confirm() {
  local prompt="$1"
  if [ "${OPENMCP_ASSUME_YES:-0}" = "1" ]; then
    return 0
  fi
  if [ ! -t 0 ]; then
    return 0
  fi
  local reply
  read -r -p "${BOLD}${YELLOW}${prompt} [y/N] ${NC}" reply </dev/tty || return 1
  case "$reply" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

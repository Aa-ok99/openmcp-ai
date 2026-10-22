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
# display width so Thai text lines up correctly.
BANNER_WIDTH=42

# Approximate terminal column width. Thai base characters occupy one column
# and Thai combining marks (vowel signs, tone marks) occupy none - treating
# every Thai codepoint as double width made the banner overrun its border.
display_width() {
  local s="$1" w=0 i ch code
  local LC_ALL=C.UTF-8
  for ((i = 0; i < ${#s}; i++)); do
    ch="${s:i:1}"
    printf -v code "%d" "'$ch" 2>/dev/null || code=0
    # Thai zero-width marks: MAI HAN-AKAT, vowel signs above/below, tone
    # marks. U+0E32 (SARA AA) and U+0E33 (SARA AM) are spacing - width 1.
    if (( code == 0x0E31 || (code >= 0x0E34 && code <= 0x0E3A) || (code >= 0x0E47 && code <= 0x0E4E) )); then
      continue
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
  local tw pad border
  tw="$(display_width "$title")"
  # Grow the box rather than letting a long title break the right edge.
  [ $((tw + 2)) -gt "$width" ] && width=$((tw + 2))
  pad=$((width - tw))
  printf -v border '%*s' "$width" ''
  border="${border// /═}"
  echo
  printf "%b\n" "$(grad " ╔${border}╗")"
  printf "%b\n" "$(grad " ║${title}$(printf '%*s' "$pad" '')║")"
  printf "%b\n" "$(grad " ╚${border}╝")"
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

# Print a summary table of installed components. Padding is computed from the
# display width, not the byte length, so Thai labels line up with ASCII ones.
summary_row() {
  local label="$1" value="$2" pad
  pad=$(( 22 - $(display_width "$label") ))
  [ "$pad" -lt 1 ] && pad=1
  printf "  ${GREEN}%s${NC}%*s %s\n" "$label" "$pad" "" "$value"
}

# Confirm an action unless --yes was passed.
confirm() {
  local prompt="$1"
  # A dry run never changes anything, so there is nothing to confirm.
  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    return 0
  fi
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

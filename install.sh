#!/usr/bin/env bash
# ============================================================================
#  EvilClaude — universal installer
#  Linux • macOS • Termux (Android) • WSL
#  Windows users: run install.ps1 in PowerShell instead.
# ============================================================================
set -euo pipefail

# ---- CONFIG ----------------------------------------------------------------
REMOTE_CLI_URL="${EVILCLAUDE_REMOTE_URL:-https://evilclaude.swampmine.in/cli.js}"
FALLBACK_CLI_URL="https://raw.githubusercontent.com/swampmine/evilclaude-cli/main/cli.js"


INSTALL_DIR="${EVILCLAUDE_INSTALL_DIR:-$HOME/.local/bin}"
BIN_NAME="evilclaude"
LOCAL_CLI="${EVILCLAUDE_LOCAL_PATH:-}"

# ---- COLORS ----------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  R=$'\033[0m'; B=$'\033[1m'; D=$'\033[2m'
  RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'
  BLU=$'\033[34m'; MAG=$'\033[35m'; CYN=$'\033[36m'
else
  R=''; B=''; D=''; RED=''; GRN=''; YLW=''; BLU=''; MAG=''; CYN=''
fi

# ---- ANIMATED BANNER -------------------------------------------------------
banner() {
  clear 2>/dev/null || true
  local lines=(
"${RED}    ███████╗██╗   ██╗██╗██╗      ${MAG} ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗${R}"
"${RED}    ██╔════╝██║   ██║██║██║      ${MAG}██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝${R}"
"${RED}    █████╗  ██║   ██║██║██║      ${MAG}██║     ██║     ███████║██║   ██║██║  ██║█████╗  ${R}"
"${RED}    ██╔══╝  ╚██╗ ██╔╝██║██║      ${MAG}██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝  ${R}"
"${RED}    ███████╗ ╚████╔╝ ██║███████╗ ${MAG}╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗${R}"
"${RED}    ╚══════╝  ╚═══╝  ╚═╝╚══════╝ ${MAG} ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝${R}"
  )
  for l in "${lines[@]}"; do
    printf '%s\n' "$l"
    sleep 0.04
  done
  printf '\n%s\n\n' "${D}              the unleashed Claude Code  ·  routed through SwampMine${R}"
  sleep 0.15
}

# ---- UI HELPERS ------------------------------------------------------------
step()  { printf '%s▸%s %s\n' "${CYN}${B}" "${R}" "$*"; }
ok()    { printf '%s✓%s %s\n' "${GRN}${B}" "${R}" "$*"; }
warn()  { printf '%s!%s %s\n' "${YLW}${B}" "${R}" "$*"; }
die()   { printf '%s✗%s %s\n' "${RED}${B}" "${R}" "$*" >&2; exit 1; }

spinner() {
  local pid=$1 msg=$2
  local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r%s%s%s %s ' "${MAG}" "${frames:i++%${#frames}:1}" "${R}" "$msg"
    sleep 0.08
  done
  printf '\r%s✓%s %s\n' "${GRN}${B}" "${R}" "$msg"
}

progress_bar() {
  # progress_bar <current> <total> <label>
  local cur=$1 tot=$2 label=$3
  local width=32
  local filled=$(( cur * width / tot ))
  local empty=$(( width - filled ))
  local bar=''
  bar+=$(printf '█%.0s' $(seq 1 $filled 2>/dev/null) 2>/dev/null || true)
  bar+=$(printf '░%.0s' $(seq 1 $empty   2>/dev/null) 2>/dev/null || true)
  printf '\r  %s[%s%s%s]%s %3d%% %s' "${D}" "${GRN}" "$bar" "${D}" "${R}" $(( cur * 100 / tot )) "$label"
}

# ---- OS DETECTION ----------------------------------------------------------
detect_os() {
  case "$(uname -s 2>/dev/null)" in
    Linux*)
      if [ -n "${PREFIX:-}" ] && [[ "${PREFIX}" == *com.termux* ]]; then
        echo "termux"
      elif grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
      else
        echo "linux"
      fi
      ;;
    Darwin*)  echo "macos"  ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

# ---- BUN INSTALL -----------------------------------------------------------
ensure_bun() {
  if command -v bun >/dev/null 2>&1; then
    ok "bun $(bun --version) detected"
    return
  fi
  step "bun not found — installing"
  case "$OS" in
    termux)
      command -v pkg >/dev/null 2>&1 || die "termux pkg not found"
      ( pkg install -y nodejs >/dev/null 2>&1 ) &
      spinner $! "installing node via termux pkg (bun has no termux build)"
      command -v node >/dev/null || die "node install failed"
      warn "On Termux we use Node instead of Bun. cli.js requires Node ≥18."
      ;;
    *)
      ( curl -fsSL https://bun.sh/install | bash >/dev/null 2>&1 ) &
      spinner $! "downloading and installing bun"
      export PATH="$HOME/.bun/bin:$PATH"
      command -v bun >/dev/null 2>&1 || die "bun install failed — install manually from https://bun.sh"
      ok "bun $(bun --version) installed"
      ;;
  esac
}

# ---- LOCAL OR REMOTE -------------------------------------------------------
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

resolve_cli() {
  if [ -n "$LOCAL_CLI" ] && [ -f "$LOCAL_CLI" ]; then
    ok "using local cli.js: $LOCAL_CLI"
    SRC_CLI="$LOCAL_CLI"; SRC_KIND="local"; return
  fi
  for c in "$SCRIPT_DIR/cli.js" "$PWD/cli.js" "$PWD/public/cli.js" "$SCRIPT_DIR/../public/cli.js"; do
    if [ -f "$c" ]; then
      ok "found local cli.js: $c"
      SRC_CLI="$c"; SRC_KIND="local"; return
    fi
  done
  warn "no local cli.js — will download from GitHub"
  SRC_CLI="$REMOTE_CLI_URL"; SRC_KIND="remote"
}

download_remote() {
  local out=$1
  step "downloading cli.js"
  local target_url="$REMOTE_CLI_URL"
  if ! curl -fsSL -o "$out" "$target_url" 2>/dev/null; then
    warn "primary URL failed, trying GitHub mirror: $FALLBACK_CLI_URL"
    target_url="$FALLBACK_CLI_URL"
    curl -fsSL -o "$out" "$target_url" || die "download failed from all sources"
  fi
  [ -s "$out" ] || die "downloaded file is empty"
  if head -c 200 "$out" | grep -qi '<html\|<!DOCTYPE'; then
    if [ "$target_url" != "$FALLBACK_CLI_URL" ]; then
      warn "gateway returned HTML, falling back to GitHub mirror"
      curl -fsSL -o "$out" "$FALLBACK_CLI_URL" || die "failed downloading from GitHub mirror"
    fi
  fi
  if head -c 200 "$out" | grep -qi '<html\|<!DOCTYPE'; then
    rm -f "$out"; die "remote returned HTML"
  fi
  ok "cli.js downloaded successfully"
}

# ---- INSTALL ---------------------------------------------------------------
do_install() {
  step "install dir: $INSTALL_DIR"
  mkdir -p "$INSTALL_DIR" || die "cannot create $INSTALL_DIR"
  local target="$INSTALL_DIR/$BIN_NAME"

  if [ "$SRC_KIND" = "local" ]; then
    step "copying cli.js → $target"
    if head -1 "$SRC_CLI" | grep -q '^#!'; then
      cp "$SRC_CLI" "$target"
    else
      { echo '#!/usr/bin/env bun'; cat "$SRC_CLI"; } > "$target"
    fi
  else
    download_remote "$target.tmp"
    if head -1 "$target.tmp" | grep -q '^#!'; then
      mv "$target.tmp" "$target"
    else
      { echo '#!/usr/bin/env bun'; cat "$target.tmp"; } > "$target"
      rm -f "$target.tmp"
    fi
  fi
  chmod +x "$target"
  local sz=$(( $(wc -c <"$target") / 1024 / 1024 ))
  ok "installed $BIN_NAME (${sz}MB) → $target"
}

# ---- PATH CHECK ------------------------------------------------------------
check_path() {
  case ":$PATH:" in
    *":$INSTALL_DIR:"*)
      ok "$INSTALL_DIR is on your PATH"
      ;;
    *)
      warn "$INSTALL_DIR is NOT on your PATH"
      local rc="$HOME/.bashrc"
      [ -n "${ZSH_VERSION:-}" ] && rc="$HOME/.zshrc"
      [ "$OS" = "termux" ] && rc="$HOME/.bashrc"
      printf '   %sAdd this line to %s:%s\n' "${D}" "$rc" "${R}"
      printf '   %sexport PATH="%s:$PATH"%s\n' "${YLW}" "$INSTALL_DIR" "${R}"
      ;;
  esac
}

# ---- DONE BANNER -----------------------------------------------------------
done_banner() {
  printf '\n'
  printf '%s┌─────────────────────────────────────────────────────────────┐%s\n' "${MAG}" "${R}"
  printf '%s│%s   %s🔥 EvilClaude v1.0 is ready.%s                               %s│%s\n' "${MAG}" "${R}" "${B}${RED}" "${R}" "${MAG}" "${R}"
  printf '%s├─────────────────────────────────────────────────────────────┤%s\n' "${MAG}" "${R}"
  printf '%s│%s   1. Log in or create account via Web UI:                   %s│%s\n' "${MAG}" "${R}" "${MAG}" "${R}"
  printf '%s│%s      %shttps://evilclaude.swampmine.in/login%s               %s│%s\n' "${MAG}" "${R}" "${CYN}" "${R}" "${MAG}" "${R}"
  printf '%s│%s                                                             %s│%s\n' "${MAG}" "${R}" "${MAG}" "${R}"
  printf '%s│%s   2. Set your SWAMPMINE_API_KEY:                            %s│%s\n' "${MAG}" "${R}" "${MAG}" "${R}"
  printf '%s│%s      %sexport SWAMPMINE_API_KEY="ec_..."%s                    %s│%s\n' "${MAG}" "${R}" "${YLW}" "${R}" "${MAG}" "${R}"
  printf '%s│%s                                                             %s│%s\n' "${MAG}" "${R}" "${MAG}" "${R}"
  printf '%s│%s   3. Launch:                                                %s│%s\n' "${MAG}" "${R}" "${MAG}" "${R}"
  printf '%s│%s      %sevilclaude%s                                           %s│%s\n' "${MAG}" "${R}" "${GRN}" "${R}" "${MAG}" "${R}"
  printf '%s└─────────────────────────────────────────────────────────────┘%s\n\n' "${MAG}" "${R}"
}

# ---- MAIN ------------------------------------------------------------------
banner
OS=$(detect_os)
step "detected OS: ${B}${OS}${R}"
case "$OS" in
  windows) die "Windows shell detected — please run install.ps1 in PowerShell instead." ;;
  unknown) warn "unknown OS — proceeding anyway" ;;
esac

ensure_bun
resolve_cli
do_install
check_path
done_banner

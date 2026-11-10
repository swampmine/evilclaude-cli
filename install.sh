#!/usr/bin/env bash
# ============================================================================
#  EvilClaude Universal CLI Installer
#  Linux • macOS • Termux • WSL
# ============================================================================
set -euo pipefail

# Configuration
GATEWAY_URL="${EVILCLAUDE_GATEWAY_URL:-https://evilclaude.swampmine.in}"
VERSION="${EVILCLAUDE_VERSION:-1.0.27}"
INSTALL_DIR="${EVILCLAUDE_INSTALL_DIR:-$HOME/.local/bin}"
CONFIG_DIR="${EVILCLAUDE_CONFIG_DIR:-$HOME/.evilclaude}"
BIN_NAME="evilclaude"
REMOTE_CLI_URL="${EVILCLAUDE_REMOTE_URL:-${GATEWAY_URL}/cli.js}"
FALLBACK_CLI_URL="https://raw.githubusercontent.com/swampmine/evilclaude-cli/main/cli.js"

# Terminal Formatting
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RESET=$'\033[0m'
  RED=$'\033[38;2;255;24;56m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  CYAN=$'\033[36m'
  MAGENTA=$'\033[35m'
  WHITE=$'\033[37m'
else
  BOLD='' DIM='' RESET='' RED='' GREEN='' YELLOW='' CYAN='' MAGENTA='' WHITE=''
fi

info()    { printf '%sinfo:%s %s\n' "${DIM}" "${RESET}" "$*"; }
success() { printf '%s✓%s %s\n' "${GREEN}${BOLD}" "${RESET}" "$*"; }
warn()    { printf '%swarn:%s %s\n' "${YELLOW}${BOLD}" "${RESET}" "$*"; }
error()   { printf '%serror:%s %s\n' "${RED}${BOLD}" "${RESET}" "$*" >&2; exit 1; }

# 6-dot braille spinner frames (2 up, 2 middle, 2 down rotating loop)
DOT_FRAMES=('⠋' '⠙' '⠸' '⠴' '⠦' '⠇')

spin_step() {
  local msg="$1"
  local cycles="${2:-8}"
  local delay="${3:-0.07}"
  if [ -t 1 ]; then
    for ((i=0; i<cycles; i++)); do
      local frame="${DOT_FRAMES[$((i % ${#DOT_FRAMES[@]}))]}"
      printf '\r%s%s%s %s' "${CYAN}${BOLD}" "$frame" "${RESET}" "$msg"
      sleep "$delay"
    done
  fi
}

# 1. OS & Architecture Detection with 6-dot rotating loop & version {}
detect_environment() {
  spin_step "Detecting operating system..." 8 0.06

  local os arch
  os="$(uname -s 2>/dev/null || echo unknown)"
  arch="$(uname -m 2>/dev/null || echo unknown)"

  case "$os" in
    Linux*)
      if [ -n "${PREFIX:-}" ] && [[ "${PREFIX}" == *com.termux* ]]; then
        OS_NAME="Termux"
        OS_TYPE="termux"
      elif grep -qi microsoft /proc/version 2>/dev/null; then
        OS_NAME="WSL"
        OS_TYPE="wsl"
      else
        OS_NAME="Linux"
        OS_TYPE="linux"
      fi
      ;;
    Darwin*)
      OS_NAME="macOS"
      OS_TYPE="macos"
      ;;
    MINGW*|MSYS*|CYGWIN*)
      error "Windows detected. Run the PowerShell installer instead: irm https://evilclaude.swampmine.in/install.ps1 | iex"
      ;;
    *)
      OS_NAME="$os"
      OS_TYPE="linux"
      ;;
  esac

  case "$arch" in
    x86_64|amd64) ARCH_NAME="x86_64"; ARCH_TYPE="x64" ;;
    aarch64|arm64) ARCH_NAME="arm64";  ARCH_TYPE="arm64" ;;
    *)            ARCH_NAME="$arch";   ARCH_TYPE="$arch" ;;
  esac

  # Fetch latest version dynamically if available, otherwise use default
  local live_ver
  live_ver=$(curl -fsSL -m 2 "${GATEWAY_URL}/version" 2>/dev/null || echo "$VERSION")
  live_ver="${live_ver//[$'\t\r\n ']/}"
  [ -n "$live_ver" ] && VERSION="$live_ver"

  printf '\r%s✓%s Detected OS: %s%s (%s)%s · Current Version: %s{%s}%s\n' \
    "${GREEN}${BOLD}" "${RESET}" "${BOLD}" "$OS_NAME" "$ARCH_NAME" "${RESET}" "${MAGENTA}${BOLD}" "v${VERSION}" "${RESET}"
}

# Runtime check (Node.js >= 18 or Bun)
ensure_runtime() {
  if command -v node >/dev/null 2>&1; then
    local node_v
    node_v=$(node -v 2>/dev/null | sed 's/^v//' || true)
    local major_v
    major_v=$(echo "$node_v" | cut -d. -f1)
    if [ -n "$major_v" ] && [ "$major_v" -ge 18 ] 2>/dev/null; then
      RUNTIME="node"
      return
    fi
  fi

  if command -v bun >/dev/null 2>&1; then
    RUNTIME="bun"
    return
  fi

  spin_step "Preparing runtime..." 6 0.06
  if [ "$OS_TYPE" = "termux" ]; then
    if command -v pkg >/dev/null 2>&1; then
      pkg install -y nodejs >/dev/null 2>&1 || true
      if command -v node >/dev/null 2>&1; then
        RUNTIME="node"
        return
      fi
    fi
    error "Node.js >= 18 is required. Run 'pkg install nodejs' and try again."
  fi

  if curl -fsSL https://bun.sh/install | bash >/dev/null 2>&1; then
    export PATH="$HOME/.bun/bin:$PATH"
    if command -v bun >/dev/null 2>&1; then
      RUNTIME="bun"
      return
    fi
  fi

  error "Node.js (>= 18) or Bun is required to run EvilClaude CLI."
}

# Progress bar renderer
render_bar() {
  local cur=$1 tot=$2
  local pct=0
  if [ "$tot" -gt 0 ]; then
    pct=$(( cur * 100 / tot ))
  fi
  [ "$pct" -gt 100 ] && pct=100

  local width=28
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local bar=""
  for ((b=0; b<filled; b++)); do bar+="█"; done
  for ((b=0; b<empty; b++)); do bar+="░"; done

  local cur_mb tot_mb
  cur_mb=$(awk -v c="$cur" 'BEGIN { printf "%.1f", c/1048576 }' 2>/dev/null || echo "$(( cur / 1048576 ))")
  tot_mb=$(awk -v t="$tot" 'BEGIN { printf "%.1f", t/1048576 }' 2>/dev/null || echo "$(( tot / 1048576 ))")

  if [ -t 1 ]; then
    printf '\r%sDownloading%s [%s%s%s] %s%3d%%%s (%sMB/%sMB)' \
      "${CYAN}" "${RESET}" "${GREEN}" "$bar" "${RESET}" "${BOLD}" "$pct" "${RESET}" "$cur_mb" "$tot_mb"
  fi
}

# 2. Download with % progress bar
download_cli() {
  local target_path="$1"
  local tmp_file="${target_path}.tmp.$$"
  local downloaded=0
  local total_size=21036000

  # Check local file in repository
  local script_dir=""
  if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
  fi

  for candidate in "${script_dir}/cli.js" "${script_dir}/../public/cli.js" "$PWD/cli.js" "$PWD/public/cli.js"; do
    if [ -n "$candidate" ] && [ -f "$candidate" ] && [ -s "$candidate" ]; then
      local sz
      sz=$(wc -c < "$candidate" 2>/dev/null || echo "$total_size")
      for p in 20 45 75 95 100; do
        render_bar $(( sz * p / 100 )) "$sz"
        sleep 0.05
      done
      cp "$candidate" "$tmp_file"
      downloaded=1
      printf '\n'
      break
    fi
  done

  # Remote download via gateway
  if [ "$downloaded" -eq 0 ]; then
    curl -fsSL -o "$tmp_file" "$REMOTE_CLI_URL" >/dev/null 2>&1 &
    local curl_pid=$!

    while kill -0 "$curl_pid" 2>/dev/null; do
      local cur_size=0
      if [ -f "$tmp_file" ]; then
        cur_size=$(wc -c < "$tmp_file" 2>/dev/null || echo 0)
      fi
      render_bar "$cur_size" "$total_size"
      sleep 0.1
    done

    wait "$curl_pid" 2>/dev/null || true

    if [ -s "$tmp_file" ] && ! head -c 200 "$tmp_file" | grep -qi '<html\|<!DOCTYPE'; then
      downloaded=1
      render_bar "$total_size" "$total_size"
      printf '\n'
    fi
  fi

  # Fallback to GitHub mirror
  if [ "$downloaded" -eq 0 ]; then
    rm -f "$tmp_file"
    curl -fsSL -o "$tmp_file" "$FALLBACK_CLI_URL" >/dev/null 2>&1 &
    local fb_pid=$!

    while kill -0 "$fb_pid" 2>/dev/null; do
      local cur_size=0
      if [ -f "$tmp_file" ]; then
        cur_size=$(wc -c < "$tmp_file" 2>/dev/null || echo 0)
      fi
      render_bar "$cur_size" "$total_size"
      sleep 0.1
    done

    wait "$fb_pid" 2>/dev/null || true

    if [ -s "$tmp_file" ] && ! head -c 200 "$tmp_file" | grep -qi '<html\|<!DOCTYPE'; then
      downloaded=1
      render_bar "$total_size" "$total_size"
      printf '\n'
    fi
  fi

  if [ "$downloaded" -eq 0 ] || [ ! -s "$tmp_file" ]; then
    rm -f "$tmp_file"
    error "Download failed. Please check your internet connection."
  fi

  local final_size
  final_size=$(wc -c < "$tmp_file" 2>/dev/null || echo "$total_size")
  local final_mb
  final_mb=$(awk -v s="$final_size" 'BEGIN { printf "%.1f", s/1048576 }' 2>/dev/null || echo "21.0")
  success "Downloaded EvilClaude v${VERSION} (${final_mb} MB)"

  # Ensure proper shebang
  if head -1 "$tmp_file" | grep -q '^#!'; then
    cp "$tmp_file" "$target_path"
  else
    {
      echo "#!/usr/bin/env $RUNTIME"
      cat "$tmp_file"
    } > "$target_path"
  fi
  rm -f "$tmp_file"
  chmod +x "$target_path"
}

# 3. Doing setup with 6-dot braille spinner
do_setup() {
  local target_bin="$1"

  # Spinner during setup
  spin_step "Doing setup..." 10 0.07

  # 3a. Configure PATH
  case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *)
      local shell_rcs=()
      [ -f "$HOME/.bashrc" ] && shell_rcs+=("$HOME/.bashrc")
      [ -f "$HOME/.bash_profile" ] && shell_rcs+=("$HOME/.bash_profile")
      [ -f "$HOME/.zshrc" ] && shell_rcs+=("$HOME/.zshrc")
      [ -f "$HOME/.profile" ] && shell_rcs+=("$HOME/.profile")

      for rc in "${shell_rcs[@]}"; do
        if ! grep -q "PATH=.*$INSTALL_DIR" "$rc" 2>/dev/null; then
          printf '\n# EvilClaude CLI\nexport PATH="%s:$PATH"\n' "$INSTALL_DIR" >> "$rc"
        fi
      done

      if [ -d "$HOME/.config/fish" ]; then
        mkdir -p "$HOME/.config/fish/conf.d"
        echo "set -gx PATH $INSTALL_DIR \$PATH" > "$HOME/.config/fish/conf.d/evilclaude.fish"
      fi
      export PATH="$INSTALL_DIR:$PATH"
      ;;
  esac

  # 3b. Setup authorization credentials
  local key_file="$CONFIG_DIR/api_key"
  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR" 2>/dev/null || true

  if [ ! -f "$key_file" ] || [ ! -s "$key_file" ]; then
    local provision_resp
    provision_resp=$(curl -fsSL -m 4 -X POST "${GATEWAY_URL}/api/v1/terminal/provision" \
      -H "Content-Type: application/json" \
      -d "{\"platform\":\"${OS_TYPE}\",\"label\":\"$(hostname 2>/dev/null || echo cli)\"}" 2>/dev/null || echo "")

    local minted_key
    minted_key=$(echo "$provision_resp" | grep -o '"api_key":"[^"]*"' | cut -d'"' -f4 || true)

    if [ -n "$minted_key" ]; then
      printf '%s\n' "$minted_key" > "$key_file"
      chmod 600 "$key_file" 2>/dev/null || true
    else
      printf 'ec_offline_%s\n' "$(hostname 2>/dev/null || echo guest)" > "$key_file"
      chmod 600 "$key_file" 2>/dev/null || true
    fi
  fi

  printf '\r%s✓%s Doing setup... complete              \n' "${GREEN}${BOLD}" "${RESET}"
}

# 4. Done
show_done() {
  success "Done"
}

# 5. Colorful "You can run EvilClaude" banner
show_colorful_finish() {
  printf '\n'
  printf '%s┌─────────────────────────────────────────────────────────────┐%s\n' "${MAGENTA}" "${RESET}"
  printf '%s│%s   %s🔥 EvilClaude is ready!%s                                   %s│%s\n' "${MAGENTA}" "${RESET}" "${BOLD}${RED}" "${RESET}" "${MAGENTA}" "${RESET}"
  printf '%s│%s                                                             %s│%s\n' "${MAGENTA}" "${RESET}" "${MAGENTA}" "${RESET}"
  printf '%s│%s   You can run %sEvilClaude%s with:                                %s│%s\n' "${MAGENTA}" "${RESET}" "${BOLD}${MAGENTA}" "${RESET}" "${MAGENTA}" "${RESET}"
  printf '%s│%s     %s%sevilclaude%s                                           %s│%s\n' "${MAGENTA}" "${RESET}" "${CYAN}${BOLD}" "" "${RESET}" "${MAGENTA}" "${RESET}"
  printf '%s└─────────────────────────────────────────────────────────────┘%s\n\n' "${MAGENTA}" "${RESET}"
}

main() {
  detect_environment
  ensure_runtime

  mkdir -p "$INSTALL_DIR"
  local target_bin="$INSTALL_DIR/$BIN_NAME"

  download_cli "$target_bin"
  do_setup "$target_bin"
  show_done
  show_colorful_finish
}

main "$@"

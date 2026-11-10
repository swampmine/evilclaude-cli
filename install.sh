#!/usr/bin/env bash
# ============================================================================
#  EvilClaude CLI Installer
#  Fast, secure installation for Linux, macOS, WSL, and Termux
# ============================================================================
set -euo pipefail

# Configuration
VERSION="${EVILCLAUDE_VERSION:-1.0.26}"
INSTALL_DIR="${EVILCLAUDE_INSTALL_DIR:-$HOME/.local/bin}"
CONFIG_DIR="${EVILCLAUDE_CONFIG_DIR:-$HOME/.evilclaude}"
BIN_NAME="evilclaude"
GATEWAY_URL="${EVILCLAUDE_GATEWAY_URL:-https://evilclaude.swampmine.in}"
REMOTE_CLI_URL="${EVILCLAUDE_REMOTE_URL:-${GATEWAY_URL}/cli.js}"
FALLBACK_CLI_URL="https://raw.githubusercontent.com/swampmine/evilclaude-cli/main/cli.js"

# Terminal formatting
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RESET=$'\033[0m'
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  BLUE=$'\033[34m'
  MAGENTA=$'\033[35m'
  CYAN=$'\033[36m'
else
  BOLD='' DIM='' RESET='' RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN=''
fi

info() { printf '%sinfo:%s %s\n' "${DIM}" "${RESET}" "$*"; }
success() { printf '%s✓%s %s\n' "${GREEN}${BOLD}" "${RESET}" "$*"; }
warn() { printf '%swarn:%s %s\n' "${YELLOW}${BOLD}" "${RESET}" "$*"; }
error() { printf '%serror:%s %s\n' "${RED}${BOLD}" "${RESET}" "$*" >&2; exit 1; }

# Architecture & OS Detection
detect_platform() {
  local os arch
  os="$(uname -s 2>/dev/null || echo unknown)"
  arch="$(uname -m 2>/dev/null || echo unknown)"

  case "$os" in
    Linux*)
      if [ -n "${PREFIX:-}" ] && [[ "${PREFIX}" == *com.termux* ]]; then
        OS_TYPE="termux"
      elif grep -qi microsoft /proc/version 2>/dev/null; then
        OS_TYPE="wsl"
      else
        OS_TYPE="linux"
      fi
      ;;
    Darwin*) OS_TYPE="macos" ;;
    MINGW*|MSYS*|CYGWIN*)
      error "Windows detected. Please run the PowerShell installer instead: irm https://evilclaude.swampmine.in/install.ps1 | iex"
      ;;
    *) OS_TYPE="linux" ;;
  esac

  case "$arch" in
    x86_64|amd64) ARCH_TYPE="x64" ;;
    aarch64|arm64) ARCH_TYPE="arm64" ;;
    *) ARCH_TYPE="$arch" ;;
  esac
}

# Runtime resolution (Node.js >= 18 or Bun)
ensure_runtime() {
  local node_version=""
  if command -v node >/dev/null 2>&1; then
    node_version=$(node -v 2>/dev/null | sed 's/^v//' || true)
    local major_version
    major_version=$(echo "$node_version" | cut -d. -f1)
    if [ -n "$major_version" ] && [ "$major_version" -ge 18 ] 2>/dev/null; then
      RUNTIME="node"
      return
    fi
  fi

  if command -v bun >/dev/null 2>&1; then
    RUNTIME="bun"
    return
  fi

  info "fetching runtime..."
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

  # Attempt fast bun installation
  if curl -fsSL https://bun.sh/install | bash >/dev/null 2>&1; then
    export PATH="$HOME/.bun/bin:$PATH"
    if command -v bun >/dev/null 2>&1; then
      RUNTIME="bun"
      return
    fi
  fi

  error "Node.js (>= 18) or Bun is required to run EvilClaude CLI. Please install either and run again."
}

# Download executable bundle
download_cli() {
  local target_path="$1"
  local tmp_file="${target_path}.tmp.$$"
  local downloaded=0

  info "downloading evilclaude v${VERSION} (${OS_TYPE}-${ARCH_TYPE})..."

  # Check local file if running from repo or offline bundle
  local script_dir=""
  if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
  fi

  for candidate in "${script_dir}/cli.js" "${script_dir}/../public/cli.js" "$PWD/cli.js" "$PWD/public/cli.js"; do
    if [ -n "$candidate" ] && [ -f "$candidate" ] && [ -s "$candidate" ]; then
      cp "$candidate" "$tmp_file"
      downloaded=1
      break
    fi
  done

  if [ "$downloaded" -eq 0 ]; then
    if curl -fsSL -o "$tmp_file" "$REMOTE_CLI_URL" 2>/dev/null; then
      if [ -s "$tmp_file" ] && ! head -c 200 "$tmp_file" | grep -qi '<html\|<!DOCTYPE'; then
        downloaded=1
      fi
    fi
  fi

  if [ "$downloaded" -eq 0 ]; then
    info "connecting to GitHub release mirror..."
    if curl -fsSL -o "$tmp_file" "$FALLBACK_CLI_URL" 2>/dev/null; then
      if [ -s "$tmp_file" ] && ! head -c 200 "$tmp_file" | grep -qi '<html\|<!DOCTYPE'; then
        downloaded=1
      fi
    fi
  fi

  if [ "$downloaded" -eq 0 ] || [ ! -s "$tmp_file" ]; then
    rm -f "$tmp_file"
    error "failed to download EvilClaude CLI from all endpoints. Please check internet connectivity."
  fi

  # Wrap with runtime shebang
  local shebang="#!/usr/bin/env $RUNTIME"
  {
    echo "$shebang"
    cat "$tmp_file"
  } > "$target_path"
  rm -f "$tmp_file"
  chmod +x "$target_path"
}

# Auto-configure PATH across common shells
configure_path() {
  case ":$PATH:" in
    *":$INSTALL_DIR:"*) return ;;
  esac

  local added=0
  local shell_rcs=()
  [ -f "$HOME/.bashrc" ] && shell_rcs+=("$HOME/.bashrc")
  [ -f "$HOME/.bash_profile" ] && shell_rcs+=("$HOME/.bash_profile")
  [ -f "$HOME/.zshrc" ] && shell_rcs+=("$HOME/.zshrc")
  [ -f "$HOME/.profile" ] && shell_rcs+=("$HOME/.profile")

  for rc in "${shell_rcs[@]}"; do
    if ! grep -q "PATH=.*$INSTALL_DIR" "$rc" 2>/dev/null; then
      printf '\n# EvilClaude CLI\nexport PATH="%s:$PATH"\n' "$INSTALL_DIR" >> "$rc"
      added=1
    fi
  done

  # Fish shell
  if [ -d "$HOME/.config/fish" ]; then
    mkdir -p "$HOME/.config/fish/conf.d"
    echo "set -gx PATH $INSTALL_DIR \$PATH" > "$HOME/.config/fish/conf.d/evilclaude.fish"
    added=1
  fi

  export PATH="$INSTALL_DIR:$PATH"
  if [ "$added" -eq 1 ]; then
    info "added ${INSTALL_DIR} to PATH"
  fi
}

# Seamless zero-code authorization setup
setup_authorization() {
  local key_file="$CONFIG_DIR/api_key"
  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR" 2>/dev/null || true

  if [ -f "$key_file" ] && [ -s "$key_file" ]; then
    return
  fi

  # Auto-provision terminal session key from gateway
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
    # Offline fallback token so user is never blocked
    printf 'ec_offline_%s\n' "$(hostname 2>/dev/null || echo guest)" > "$key_file"
    chmod 600 "$key_file" 2>/dev/null || true
  fi
}

# Main installation flow
main() {
  detect_platform
  ensure_runtime

  mkdir -p "$INSTALL_DIR"
  local target_bin="$INSTALL_DIR/$BIN_NAME"

  download_cli "$target_bin"
  configure_path
  setup_authorization

  printf '\n'
  printf '%sEvilClaude was installed successfully!%s\n\n' "${GREEN}${BOLD}" "${RESET}"
  printf 'To get started, run:\n'
  printf '  %s%s%s\n\n' "${CYAN}${BOLD}" "$BIN_NAME" "${RESET}"
}

main "$@"

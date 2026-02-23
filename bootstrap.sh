#!/usr/bin/env bash
set -euo pipefail

# Apple Silicon bootstrap for Overleaf Community Edition (local usage).
# Usage:
#   ./bootstrap.sh [target_dir]
#
# Example:
#   ./bootstrap.sh ~/Projetos/Overleaf

TARGET_DIR="${1:-$HOME/Projetos/Overleaf}"
TOOLKIT_REPO="https://github.com/overleaf/toolkit.git"

log() {
  printf "[bootstrap] %s\n" "$*"
}

fail() {
  printf "[bootstrap][erro] %s\n" "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "comando ausente: $1"
}

ensure_kv() {
  local file="$1"
  local key="$2"
  local value="$3"

  if grep -qE "^${key}=" "$file"; then
    sed -E -i.bak "s|^${key}=.*$|${key}=${value}|" "$file"
    rm -f "${file}.bak"
  else
    printf "%s=%s\n" "$key" "$value" >> "$file"
  fi
}

ensure_sharelatex_platform_amd64() {
  local file="$1"
  if grep -qE '^[[:space:]]*platform:[[:space:]]*linux/amd64[[:space:]]*$' "$file"; then
    return 0
  fi

  awk '
    BEGIN { in_sharelatex = 0; inserted = 0 }
    /^[[:space:]]*sharelatex:[[:space:]]*$/ { in_sharelatex = 1; print; next }
    in_sharelatex == 1 && /^[[:space:]]*image:[[:space:]]*"\$\{IMAGE\}"[[:space:]]*$/ {
      print
      print "        platform: linux/amd64"
      inserted = 1
      next
    }
    in_sharelatex == 1 && /^[[:space:]]*[a-zA-Z0-9_-]+:[[:space:]]*$/ && $0 !~ /^[[:space:]]*sharelatex:[[:space:]]*$/ {
      in_sharelatex = 0
    }
    { print }
    END {
      if (inserted == 0) {
        exit 2
      }
    }
  ' "$file" > "${file}.tmp" || fail "nao foi possivel aplicar platform linux/amd64 em ${file}"

  mv "${file}.tmp" "$file"
}

ensure_macos_compatible_shared_functions() {
  local file="$1"
  local marker="# macOS compatibility override for read_variable/read_configuration"
  if grep -qF "$marker" "$file"; then
    return 0
  fi

  cat >> "$file" <<'EOF'

# macOS compatibility override for read_variable/read_configuration
function read_variable() {
  local name=$1
  local value
  value=$(grep -E "^$name=" "$TOOLKIT_ROOT/config/variables.env" | head -n 1)
  value=${value#*=}
  value=${value%\"}
  value=${value#\"}
  value=${value%\'}
  value=${value#\'}
  printf '%s\n' "$value"
}

function read_configuration() {
  local name=$1
  local value
  value=$(grep -E "^$name=" "$TOOLKIT_ROOT/config/overleaf.rc" | head -n 1)
  value=${value#*=}
  value=${value%\"}
  value=${value#\"}
  value=${value%\'}
  value=${value#\'}
  printf '%s\n' "$value"
}
EOF
}

main() {
  require_cmd git
  require_cmd docker

  if [[ ! -d "$TARGET_DIR/.git" ]]; then
    log "clonando toolkit em: $TARGET_DIR"
    git clone "$TOOLKIT_REPO" "$TARGET_DIR"
  else
    log "toolkit ja existe em: $TARGET_DIR"
  fi

  cd "$TARGET_DIR"

  if [[ ! -f "config/overleaf.rc" ]]; then
    log "inicializando configuracao local (bin/init)"
    bin/init
  else
    log "configuracao local ja existe"
  fi

  ensure_kv "config/overleaf.rc" "MONGO_VERSION" "8.0.0"
  ensure_kv "config/overleaf.rc" "SIBLING_CONTAINERS_ENABLED" "false"
  ensure_sharelatex_platform_amd64 "lib/docker-compose.base.yml"
  ensure_macos_compatible_shared_functions "lib/shared-functions.sh"

  log "subindo stack em background (bin/up -d)"
  bin/up -d

  log "status atual"
  bin/docker-compose ps

  cat <<'EOF'

Pronto.
Acesse:
  http://localhost/launchpad
  http://localhost/login

Comandos uteis:
  bin/start
  bin/stop
  bin/logs -f web
EOF
}

main "$@"

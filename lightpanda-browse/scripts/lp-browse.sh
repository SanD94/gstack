#!/usr/bin/env bash
# lp-browse.sh — Lightpanda browser CLI wrapper
# Provides a simplified command interface for AI agent browsing tasks
#
# Usage: lp-browse.sh <command> [args...]

set -euo pipefail

# Find lightpanda binary
LP=""
[ -x "$HOME/.local/bin/lightpanda" ] && LP="$HOME/.local/bin/lightpanda"
[ -z "$LP" ] && LP=$(command -v lightpanda 2>/dev/null || true)

if [ -z "$LP" ]; then
  echo "ERROR: lightpanda not found. Run the setup script first:"
  echo "  bash ~/.claude/skills/lightpanda-browse/scripts/setup.sh"
  exit 1
fi

STATE_DIR="${LIGHTPANDA_STATE_DIR:-$HOME/.lightpanda-browse}"
mkdir -p "$STATE_DIR"
PID_FILE="$STATE_DIR/server.pid"
PORT_FILE="$STATE_DIR/server.port"
DEFAULT_PORT=9222

CMD="${1:-help}"
shift || true

# ── Helper functions ──────────────────────────────────────────

is_server_running() {
  if [ -f "$PID_FILE" ]; then
    local pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    # Stale PID file
    rm -f "$PID_FILE" "$PORT_FILE"
  fi
  return 1
}

get_port() {
  if [ -f "$PORT_FILE" ]; then
    cat "$PORT_FILE"
  else
    echo "$DEFAULT_PORT"
  fi
}

start_server() {
  if is_server_running; then
    echo "Server already running (PID $(cat "$PID_FILE")) on port $(get_port)"
    return 0
  fi

  local port="${1:-$DEFAULT_PORT}"
  echo "[lightpanda] Starting CDP server on port $port..."

  $LP serve --host 127.0.0.1 --port "$port" --timeout 1800 \
    --log_level warn --log_format pretty &>/dev/null &
  local pid=$!
  echo "$pid" > "$PID_FILE"
  echo "$port" > "$PORT_FILE"

  # Wait for server to be ready
  local retries=0
  while [ $retries -lt 30 ]; do
    if curl -sf "http://127.0.0.1:$port/json/version" &>/dev/null; then
      echo "[lightpanda] Server ready (PID $pid, port $port)"
      return 0
    fi
    sleep 0.2
    retries=$((retries + 1))
  done

  echo "ERROR: Server failed to start within 6s"
  kill "$pid" 2>/dev/null || true
  rm -f "$PID_FILE" "$PORT_FILE"
  return 1
}

stop_server() {
  if [ -f "$PID_FILE" ]; then
    local pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      echo "[lightpanda] Server stopped (PID $pid)"
    fi
    rm -f "$PID_FILE" "$PORT_FILE"
  else
    echo "[lightpanda] No server running"
  fi
}

ensure_server() {
  if ! is_server_running; then
    start_server "$DEFAULT_PORT" >&2
  fi
}

# ── Commands ──────────────────────────────────────────────────

case "$CMD" in
  # ── One-shot fetch commands (no server needed) ──
  fetch)
    # fetch <url> [--format html|markdown|semantic_tree]
    local_url="${1:?URL required}"
    shift
    format="markdown"
    strip=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --format) format="$2"; shift 2 ;;
        --strip)  strip="$2"; shift 2 ;;
        *)        shift ;;
      esac
    done
    extra_args=()
    [ -n "$format" ] && extra_args+=(--dump "$format")
    [ -n "$strip" ] && extra_args+=(--strip_mode "$strip")
    $LP fetch "${extra_args[@]}" "$local_url"
    ;;

  html)
    # html <url> — get rendered HTML
    url="${1:?URL required}"
    $LP fetch --dump html "$url"
    ;;

  markdown|md)
    # markdown <url> — get page as markdown
    url="${1:?URL required}"
    $LP fetch --dump markdown "$url"
    ;;

  text)
    # text <url> — get page text (strip JS/CSS)
    url="${1:?URL required}"
    $LP fetch --dump html --strip_mode full "$url"
    ;;

  semantic|tree)
    # semantic <url> — get AI-optimized semantic tree
    url="${1:?URL required}"
    $LP fetch --dump semantic_tree "$url"
    ;;

  links)
    # links <url> — extract links
    url="${1:?URL required}"
    $LP fetch --dump html "$url" 2>/dev/null | grep -oP 'href="[^"]*"' | sed 's/href="//;s/"$//' | sort -u
    ;;

  # ── CDP server management ──
  serve|start)
    port="${1:-$DEFAULT_PORT}"
    start_server "$port"
    ;;

  stop)
    stop_server
    ;;

  restart)
    stop_server
    sleep 0.5
    start_server "${1:-$DEFAULT_PORT}"
    ;;

  status)
    if is_server_running; then
      local_port=$(get_port)
      echo "Server running (PID $(cat "$PID_FILE"), port $local_port)"
      curl -sf "http://127.0.0.1:$local_port/json/version" 2>/dev/null || echo "(CDP endpoint not responding)"
    else
      echo "Server not running"
    fi
    ;;

  # ── CDP interactive commands (server required) ──
  goto)
    ensure_server
    url="${1:?URL required}"
    port=$(get_port)
    # Use node/bun inline to send CDP command
    node -e "
      const ws = require('ws');
      const c = new ws('ws://127.0.0.1:$port');
      c.on('open', () => {
        c.send(JSON.stringify({id:1,method:'Target.createTarget',params:{url:'$url'}}));
      });
      c.on('message', d => { console.log(d.toString()); c.close(); });
      c.on('error', e => { console.error(e.message); process.exit(1); });
    " 2>/dev/null || echo "Use 'fetch' for one-shot page loads (no CDP server needed)"
    ;;

  js|eval)
    ensure_server
    expr="$*"
    port=$(get_port)
    node -e "
      const ws = require('ws');
      const c = new ws('ws://127.0.0.1:$port');
      c.on('open', () => {
        c.send(JSON.stringify({id:1,method:'Runtime.evaluate',params:{expression:'$expr'}}));
      });
      c.on('message', d => { console.log(d.toString()); c.close(); });
      c.on('error', e => { console.error(e.message); process.exit(1); });
    " 2>/dev/null || echo "ERROR: CDP command failed"
    ;;

  version)
    $LP version 2>/dev/null || echo "lightpanda (version unknown)"
    ;;

  help|--help|-h)
    cat <<'EOF'
lightpanda-browse — Lightweight headless browser for AI agents

Powered by Lightpanda (https://github.com/lightpanda-io/browser)
~9× less memory, ~11× faster than headless Chromium.

Usage: lp-browse <command> [args...]

One-Shot (no server):
  fetch <url> [--format html|markdown|semantic_tree] [--strip js|css|full]
  html <url>             Rendered HTML after JS execution
  markdown <url>         Page content as Markdown (default)
  text <url>             Page text (JS/CSS stripped)
  semantic <url>         AI-optimized semantic tree
  links <url>            Extract all links

CDP Server:
  serve [port]           Start CDP server (default: 9222)
  stop                   Stop CDP server
  restart [port]         Restart CDP server
  status                 Server health check

Interactive (requires server):
  goto <url>             Navigate to URL via CDP
  js <expr>              Evaluate JavaScript via CDP

Meta:
  version                Show Lightpanda version
  help                   This help text
EOF
    ;;

  *)
    echo "Unknown command: $CMD"
    echo "Run 'lp-browse help' for usage."
    exit 1
    ;;
esac

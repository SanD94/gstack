---
name: lightpanda-browse
description: |
  Lightweight headless browser using Lightpanda (~9× less memory, ~11× faster than Chromium).
  Fetch pages as markdown/HTML/semantic tree, extract links, run JavaScript — no Chromium needed.
  Use for scraping, page content extraction, quick page checks, or when low resource usage matters.
  Alternative to browse skill using Lightpanda instead of Playwright+Chromium.
allowed-tools:
  - Bash
  - Read
---

# lightpanda-browse: Lightweight Headless Browser

Uses [Lightpanda](https://github.com/lightpanda-io/browser) — a from-scratch headless browser
written in Zig with V8 for JS. ~9× less memory and ~11× faster than headless Chromium.

## SETUP (run this check BEFORE any command)

```bash
LP=""
[ -x "$HOME/.local/bin/lightpanda" ] && LP="$HOME/.local/bin/lightpanda"
[ -z "$LP" ] && LP=$(command -v lightpanda 2>/dev/null || true)
if [ -n "$LP" ]; then
  echo "READY: $LP"
else
  echo "NEEDS_SETUP"
fi
```

If `NEEDS_SETUP`:
1. Tell the user: "Lightpanda browser needs a one-time download (~20MB). OK to proceed?"
2. Then STOP and wait for confirmation.
3. Run: `bash ~/.claude/skills/lightpanda-browse/scripts/setup.sh`
4. After setup, re-check with the above snippet.

Once ready, set the variable for all subsequent commands:
```bash
LP="$HOME/.local/bin/lightpanda"
```

## When to Use This vs `browse`

| Use lightpanda-browse | Use browse |
|---|---|
| Page content extraction (markdown, HTML) | Complex UI interaction (click, fill, hover) |
| Quick page checks / scraping | Screenshot/PDF capture |
| Low-memory environments | Snapshot with @ref element selection |
| AI-agent content ingestion | Cookie import from real browsers |
| Semantic tree for LLM context | Multi-tab workflows |
| One-shot page loads | Diff before/after actions |

## Core Patterns

### 1. Get page as Markdown (best for AI context)
```bash
$LP fetch --dump markdown https://example.com
```

### 2. Get rendered HTML (after JS execution)
```bash
$LP fetch --dump html https://example.com
```

### 3. Get AI-optimized semantic tree
```bash
$LP fetch --dump semantic_tree https://example.com
```

### 4. Strip JS/CSS noise from output
```bash
$LP fetch --dump html --strip_mode js,css https://example.com
# Full strip (JS + CSS + UI chrome):
$LP fetch --dump html --strip_mode full https://example.com
```

### 5. Get page text only (semantic tree as text)
```bash
$LP fetch --dump semantic_tree_text https://example.com
```

### 6. Include iframe content
```bash
$LP fetch --dump markdown --with_frames https://example.com
```

### 7. Respect robots.txt
```bash
$LP fetch --obey_robots --dump markdown https://example.com
```

### 8. Use HTTP proxy
```bash
$LP fetch --http_proxy http://proxy:8080 --dump markdown https://example.com
```

## CDP Server Mode (for interactive/multi-step workflows)

Start a persistent CDP WebSocket server compatible with Puppeteer/Playwright:

```bash
# Start server
$LP serve --host 127.0.0.1 --port 9222 --timeout 1800 &
LP_PID=$!

# Verify it's running
curl -sf http://127.0.0.1:9222/json/version

# Stop when done
kill $LP_PID
```

### Connect with Puppeteer (Node.js)
```javascript
import puppeteer from 'puppeteer-core';
const browser = await puppeteer.connect({ browserWSEndpoint: 'ws://127.0.0.1:9222' });
const context = await browser.createBrowserContext();
const page = await context.newPage();
await page.goto('https://example.com', { waitUntil: 'networkidle0' });
const content = await page.evaluate(() => document.body.innerText);
console.log(content);
await browser.disconnect();
```

### Connect with Playwright
```javascript
import { chromium } from 'playwright';
const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
const page = await browser.contexts()[0].newPage();
await page.goto('https://example.com');
console.log(await page.title());
await browser.close();
```

## MCP Mode (direct AI agent integration)

Lightpanda can run as an MCP server over stdio, exposing browser tools directly:

```bash
$LP mcp
```

MCP tools available: `goto`, `markdown`, `links`, `evaluate`, `semantic_tree`,
`interactiveElements`, `structuredData`.

## Full CLI Reference

### fetch mode (one-shot)
```
$LP fetch [options] <url>

--dump <format>         html | markdown | wpt | semantic_tree | semantic_tree_text
--strip_mode <modes>    js | ui | css | full (comma-separated)
--with_frames           Include iframe content
--obey_robots           Respect robots.txt
--http_proxy <url>      HTTP proxy
--http_timeout <ms>     Request timeout (default: 5000)
--user_agent_suffix <s> Append to User-Agent
--log_level <level>     debug | info | warn | error | fatal
--log_format <fmt>      logfmt | pretty
```

### serve mode (CDP server)
```
$LP serve [options]

--host <addr>                    Bind address (default: 127.0.0.1)
--port <port>                    Bind port (default: 9222)
--timeout <secs>                 Inactivity timeout (default: 10)
--cdp_max_connections <n>        Max concurrent clients (default: 16)
```

### mcp mode (MCP stdio server)
```
$LP mcp
```

### Common options (all modes)
```
--obey_robots                    Respect robots.txt
--http_proxy <url>               HTTP proxy
--http_max_concurrent <n>        Max concurrent HTTP requests (default: 10)
--http_timeout <ms>              Request timeout (default: 5000)
--log_level <level>              Log level
--log_format <fmt>               Log format
--insecure_disable_tls_host_verification   Skip TLS verification
```

## Limitations vs Chromium/Playwright

- **No screenshots/PDF** — headless-only, no rendering engine
- **No visual diffing** — use `browse` skill for that
- **Partial Web API coverage** — growing but not full Chromium compat
- **No cookie import from real browsers** — use `browse` for that
- **CDP subset** — most common domains covered, but not 100% of Chrome CDP
- **Beta status** — may have edge cases with complex JS-heavy SPAs

## Quick Decision Guide

Ask yourself: "Do I need to **see** the page or **interact** with UI elements?"
- **No** → use `lightpanda-browse` (faster, lighter)
- **Yes** → use `browse` (full Chromium)

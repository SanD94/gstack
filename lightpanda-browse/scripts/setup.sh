#!/usr/bin/env bash
# Lightpanda browser setup script
# Downloads the nightly binary for the current platform

set -euo pipefail

INSTALL_DIR="${LIGHTPANDA_HOME:-$HOME/.local/bin}"
BINARY_PATH="$INSTALL_DIR/lightpanda"

mkdir -p "$INSTALL_DIR"

ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

case "$OS-$ARCH" in
  linux-x86_64)   ASSET="lightpanda-x86_64-linux" ;;
  linux-aarch64)   ASSET="lightpanda-aarch64-linux" ;;
  darwin-arm64)    ASSET="lightpanda-aarch64-macos" ;;
  darwin-x86_64)   ASSET="lightpanda-x86_64-macos" ;;
  *)
    echo "ERROR: Unsupported platform $OS-$ARCH"
    exit 1
    ;;
esac

DOWNLOAD_URL="https://github.com/lightpanda-io/browser/releases/download/nightly/$ASSET"

echo "[lightpanda] Downloading $ASSET..."
if command -v curl &>/dev/null; then
  curl -fSL -o "$BINARY_PATH" "$DOWNLOAD_URL"
elif command -v wget &>/dev/null; then
  wget -q -O "$BINARY_PATH" "$DOWNLOAD_URL"
else
  echo "ERROR: curl or wget required"
  exit 1
fi

chmod a+x "$BINARY_PATH"

echo "[lightpanda] Installed to $BINARY_PATH"
echo "[lightpanda] Version: $("$BINARY_PATH" version 2>/dev/null || echo 'nightly')"

# Ensure it's on PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
  echo ""
  echo "NOTE: Add $INSTALL_DIR to your PATH if not already:"
  echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
fi

echo "READY"

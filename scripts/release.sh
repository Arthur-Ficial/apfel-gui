#!/usr/bin/env bash
#
# release.sh - Build, package, create GitHub release, update Homebrew formula
#
# Usage:
#   ./scripts/release.sh <version>
#   ./scripts/release.sh 1.0.0
#
# What it does:
#   1. Builds release binary (arm64)
#   2. Packages binary + MCP server into tarball
#   3. Creates GitHub release with the tarball
#   4. Computes sha256 and generates Homebrew formula
#   5. Pushes formula to Arthur-Ficial/homebrew-tap
#

set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 1.0.0"
  exit 1
fi

REPO="Arthur-Ficial/apfel-gui"
BINARY="apfel-gui"
TAP_REPO="Arthur-Ficial/homebrew-tap"
TAP_DIR="/opt/homebrew/Library/Taps/arthur-ficial/homebrew-tap"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== apfel-gui release v${VERSION} ==="

# 1. Build release binary
echo ""
echo "[1/6] Building release binary..."
cd "$PROJECT_DIR"
swift build -c release
BINARY_PATH="$PROJECT_DIR/.build/release/$BINARY"
if [[ ! -f "$BINARY_PATH" ]]; then
  echo "Error: binary not found at $BINARY_PATH"
  exit 1
fi
echo "  Built: $BINARY_PATH"

# 2. Package into tarball
echo ""
echo "[2/6] Packaging tarball..."
STAGING="/tmp/apfel-gui-release-$$"
mkdir -p "$STAGING/$BINARY-${VERSION}"
cp "$BINARY_PATH" "$STAGING/$BINARY-${VERSION}/$BINARY"
mkdir -p "$STAGING/$BINARY-${VERSION}/mcp/debug-tools"
cp "$PROJECT_DIR/mcp/debug-tools/server.py" "$STAGING/$BINARY-${VERSION}/mcp/debug-tools/server.py"

TARBALL="$STAGING/$BINARY-${VERSION}-arm64-macos.tar.gz"
cd "$STAGING"
tar czf "$TARBALL" "$BINARY-${VERSION}"
echo "  Tarball: $TARBALL"

# 3. Compute sha256
echo ""
echo "[3/6] Computing sha256..."
SHA256=$(shasum -a 256 "$TARBALL" | awk '{print $1}')
echo "  SHA256: $SHA256"

# 4. Create GitHub release
echo ""
echo "[4/6] Creating GitHub release v${VERSION}..."
cd "$PROJECT_DIR"
gh release create "v${VERSION}" "$TARBALL" \
  --repo "$REPO" \
  --title "apfel-gui v${VERSION}" \
  --notes "Release v${VERSION}

## Install

\`\`\`bash
brew tap Arthur-Ficial/tap
brew install apfel-gui
\`\`\`

Or build from source:
\`\`\`bash
git clone https://github.com/${REPO}.git
cd apfel-gui
make install
\`\`\`

Requires [apfel](https://github.com/Arthur-Ficial/apfel) v0.8.1+ installed."

echo "  Release created: https://github.com/${REPO}/releases/tag/v${VERSION}"

# 5. Generate Homebrew formula
echo ""
echo "[5/6] Generating Homebrew formula..."
FORMULA_PATH="$TAP_DIR/Formula/apfel-gui.rb"

cat > "$FORMULA_PATH" <<EOF
class ApfelGui < Formula
  desc "Native macOS debug GUI for apfel - Apple Intelligence debugging tool"
  homepage "https://github.com/${REPO}"
  url "https://github.com/${REPO}/releases/download/v${VERSION}/${BINARY}-${VERSION}-arm64-macos.tar.gz"
  sha256 "${SHA256}"
  license "MIT"

  depends_on "arthur-ficial/tap/apfel"

  def install
    odie "apfel-gui requires Apple Silicon." unless Hardware::CPU.arm?

    bin.install "apfel-gui"
    (share/"apfel-gui/mcp/debug-tools").install "mcp/debug-tools/server.py"
  end

  def caveats
    <<~EOS
      apfel-gui requires apfel to be installed:
        brew install arthur-ficial/tap/apfel

      Run with:
        apfel-gui

      The GUI auto-discovers MCP servers and starts apfel in the background.
    EOS
  end

  test do
    assert_predicate bin/"apfel-gui", :executable?
  end
end
EOF

echo "  Formula written: $FORMULA_PATH"

# 6. Push formula to tap
echo ""
echo "[6/6] Pushing formula to homebrew-tap..."
cd "$TAP_DIR"
git add "Formula/apfel-gui.rb"
git commit -m "apfel-gui ${VERSION}"
git push origin main

echo ""
echo "=== Done! ==="
echo ""
echo "Users can now install with:"
echo "  brew tap Arthur-Ficial/tap"
echo "  brew install apfel-gui"
echo ""
echo "Release: https://github.com/${REPO}/releases/tag/v${VERSION}"

# Cleanup
rm -rf "$STAGING"

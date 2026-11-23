#!/usr/bin/env bash
# تسطيب Hawwel على لينكس (للمستخدم الحالي بس، من غير sudo إلا لأدوات النظام)
#   bash install.sh
set -euo pipefail

APP_DIR="$HOME/.local/share/hawwel"
BIN_DIR="$HOME/.local/bin"
SRC="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Hawwel installer"

# 1) أدوات النظام: النسخ واللصق والضغط على الزراير
if [ "${XDG_SESSION_TYPE:-}" = "wayland" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
  TOOLS="wl-clipboard ydotool"
else
  TOOLS="xdotool xclip"
fi
PY_PKGS=""
if command -v apt >/dev/null; then
  PM="sudo apt install -y"; PY_PKGS="python3-venv"
elif command -v dnf >/dev/null; then
  PM="sudo dnf install -y"
elif command -v pacman >/dev/null; then
  PM="sudo pacman -S --needed --noconfirm"
elif command -v zypper >/dev/null; then
  PM="sudo zypper install -y"
else
  PM=""
fi
if [ -n "$PM" ]; then
  echo "==> Installing system tools: $TOOLS $PY_PKGS"
  $PM $TOOLS $PY_PKGS || echo "!! Couldn't install system tools. Install them yourself: $TOOLS"
else
  echo "!! Unknown package manager. Install these yourself: $TOOLS"
fi
if echo "$TOOLS" | grep -q ydotool; then
  echo "==> ydotool needs its background service:"
  systemctl --user enable --now ydotool 2>/dev/null || systemctl --user enable --now ydotoold 2>/dev/null \
    || echo "   Start it yourself: systemctl --user enable --now ydotool"
fi

# 2) البرنامج نفسه في venv خاص بيه
echo "==> Installing Hawwel to $APP_DIR"
mkdir -p "$APP_DIR/src" "$BIN_DIR"
rm -rf "$APP_DIR/src/hawwel"
cp -r "$SRC/hawwel" "$APP_DIR/src/hawwel"
if [ ! -x "$APP_DIR/venv/bin/python" ]; then
  python3 -m venv "$APP_DIR/venv"
fi
"$APP_DIR/venv/bin/pip" install --quiet --upgrade pip
"$APP_DIR/venv/bin/pip" install --quiet -r "$SRC/requirements.txt"

# 3) أمر "hawwel" + أيقونة في قايمة البرامج
cat > "$BIN_DIR/hawwel" <<LAUNCH
#!/usr/bin/env bash
cd "$APP_DIR/src" && exec "$APP_DIR/venv/bin/python" -m hawwel "\$@"
LAUNCH
chmod +x "$BIN_DIR/hawwel"

ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
mkdir -p "$ICON_DIR" "$HOME/.local/share/applications"
cp "$SRC/hawwel/data/logo.png" "$ICON_DIR/hawwel.png"
sed "s|@BIN@|$BIN_DIR/hawwel|" "$SRC/packaging/hawwel.desktop" > "$HOME/.local/share/applications/hawwel.desktop"
command -v update-desktop-database >/dev/null && update-desktop-database "$HOME/.local/share/applications" || true

echo
echo "==> Done. Open Hawwel from your apps menu, or run: hawwel"
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) echo "   (add $BIN_DIR to your PATH to use the 'hawwel' command)";; esac

#!/usr/bin/env bash
# بيشيل Hawwel (الإعدادات والإحصائيات بتفضل في ~/.config/hawwel و ~/.local/state/hawwel)
set -eu
pkill -f "python -m hawwel" 2>/dev/null || true
rm -rf "$HOME/.local/share/hawwel" "$HOME/.local/bin/hawwel" \
       "$HOME/.local/share/applications/hawwel.desktop" \
       "$HOME/.local/share/icons/hicolor/256x256/apps/hawwel.png" \
       "$HOME/.config/autostart/hawwel.desktop"
# الاختصار في GNOME
if command -v gsettings >/dev/null; then
  KEY=org.gnome.settings-daemon.plugins.media-keys
  P=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/hawwel/
  LIST=$(gsettings get $KEY custom-keybindings 2>/dev/null | sed "s|'$P'||; s|, ,|,|; s|\[, |[|; s|, \]|]|")
  gsettings set $KEY custom-keybindings "$LIST" 2>/dev/null || true
fi
echo "Hawwel removed."

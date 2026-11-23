# Hawwel for Linux | حوّل للينكس

Fix text typed with the wrong keyboard layout (Arabic ⇄ English): select it, press your shortcut, done.
Same design and features as the Mac and Windows versions, in Arabic and English.

## Install

1. Download `Hawwel-Linux.tar.gz` from the [Releases page](https://github.com/ashrafabdulmn3m/Hawwel/releases) and extract it.
2. Run:
   ```bash
   bash Hawwel/packaging/install.sh
   ```
   It installs the tools Hawwel needs (it asks for your password for that part only),
   then installs Hawwel for your user in `~/.local/share/hawwel` and adds it to your apps menu.
3. Open **Hawwel** from your apps menu.

To remove it: `bash Hawwel/packaging/uninstall.sh`

## The shortcut

Linux desktops don't let apps grab a global shortcut directly (especially on Wayland), so the shortcut
runs the command `hawwel --convert`, which tells the running app to convert.

- **GNOME / Ubuntu:** Hawwel sets the shortcut for you (default `Ctrl+Alt+K`), and you can change it from the app.
- **KDE, XFCE, Cinnamon and others:** open the **Shortcuts** tab, copy the command, and add it as a custom
  shortcut in your keyboard settings.

## What it needs

| Session | Tools |
|---|---|
| X11 | `xdotool`, `xclip` |
| Wayland | `wl-clipboard`, `ydotool` (its service must be running: `systemctl --user enable --now ydotool`) |

The **Home** tab checks this and gives you the exact install command if something is missing.

On Wayland, apps can't see which window is in front, so "Top apps" in Activity stays empty there.

## Run from source

```bash
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python -m hawwel
```

Tests: `python3 -m unittest discover tests`

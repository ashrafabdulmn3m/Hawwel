"""
الحاجات اللي بتختلف بين X11 وWayland: النسخ واللصق، والضغط على الزراير، واسم البرنامج اللي قدام.

- X11:      xdotool (الزراير واسم النافذة) + xclip (الـ clipboard)
- Wayland:  ydotool (الزراير، ومحتاج خدمة ydotoold شغّالة) + wl-clipboard (wl-copy / wl-paste)

Wayland مش بيسمح للبرامج تعرف البرنامج اللي قدام، فإحصائية "أكتر البرامج" بتشتغل على X11 بس.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import time

# برامج الـ Terminal: النسخ واللصق فيها Ctrl+Shift+C / Ctrl+Shift+V
TERMINALS = {
    "gnome-terminal-server", "gnome-terminal", "kgx", "ptyxis", "konsole", "xterm", "uxterm", "kitty",
    "alacritty", "tilix", "terminator", "xfce4-terminal", "mate-terminal", "lxterminal", "qterminal",
    "wezterm", "wezterm-gui", "foot", "urxvt", "rxvt", "st", "sakura", "guake", "yakuake", "terminology",
    "blackbox", "com.raggesilver.blackbox", "org.gnome.console", "org.gnome.ptyxis",
}

# كود المفاتيح في Linux (input-event-codes.h) لـ ydotool
_KEY = {"ctrl": 29, "shift": 42, "c": 46, "v": 47}


def session_type() -> str:
    """'wayland' أو 'x11'"""
    t = os.environ.get("XDG_SESSION_TYPE", "").lower()
    if t in ("wayland", "x11"):
        return t
    return "wayland" if os.environ.get("WAYLAND_DISPLAY") else "x11"


def desktop() -> str:
    """GNOME / KDE / XFCE / … (من XDG_CURRENT_DESKTOP)"""
    d = os.environ.get("XDG_CURRENT_DESKTOP", "").upper()
    for name in ("GNOME", "KDE", "XFCE", "CINNAMON", "MATE", "LXQT", "BUDGIE", "UNITY", "PANTHEON"):
        if name in d:
            return "GNOME" if name in ("UNITY", "BUDGIE", "PANTHEON") and _has("gsettings") else name
    return d.split(":")[0] if d else ""


def is_gnome_like() -> bool:
    """ديسكتوب بيقبل اختصارات من gsettings (GNOME وUbuntu وأخواتهم)"""
    return desktop() == "GNOME" and _has("gsettings")


def _has(cmd: str) -> bool:
    return shutil.which(cmd) is not None


def required_tools() -> list[str]:
    return ["xdotool", "xclip"] if session_type() == "x11" else ["ydotool", "wl-copy", "wl-paste"]


def missing_tools() -> list[str]:
    return [t for t in required_tools() if not _has(t)]


def ydotoold_running() -> bool:
    """ydotool من غير الخدمة بتاعته مش بيعمل حاجة"""
    if session_type() != "wayland" or not _has("ydotool"):
        return True
    try:
        out = subprocess.run(["pgrep", "-x", "ydotoold"], capture_output=True, timeout=2)
        return out.returncode == 0
    except (OSError, subprocess.SubprocessError):
        return True  # مش قادرين نعرف: ما نزعجش المستخدم


def install_command() -> str:
    """أمر تسطيب الأدوات الناقصة حسب مدير الحزم"""
    pkgs = {"xdotool": "xdotool", "xclip": "xclip", "ydotool": "ydotool",
            "wl-copy": "wl-clipboard", "wl-paste": "wl-clipboard"}
    names = sorted({pkgs[t] for t in missing_tools()}) or sorted({pkgs[t] for t in required_tools()})
    joined = " ".join(names)
    if _has("apt"):
        return f"sudo apt install {joined}"
    if _has("dnf"):
        return f"sudo dnf install {joined}"
    if _has("pacman"):
        return f"sudo pacman -S {joined}"
    if _has("zypper"):
        return f"sudo zypper install {joined}"
    return joined


def _run(args: list[str], input_text: str | None = None, timeout: float = 2.0) -> str | None:
    try:
        r = subprocess.run(args, input=input_text.encode() if input_text is not None else None,
                           capture_output=True, timeout=timeout)
        return r.stdout.decode("utf-8", "replace") if r.returncode == 0 else None
    except (OSError, subprocess.SubprocessError):
        return None


# ---- الـ clipboard ----

def clipboard_get() -> str | None:
    if session_type() == "x11":
        return _run(["xclip", "-o", "-selection", "clipboard"])
    return _run(["wl-paste", "--no-newline"])


def clipboard_set(text: str) -> None:
    if session_type() == "x11":
        # xclip بيفضل شغّال في الخلفية علشان يقدّم النص، فما نستناهوش
        try:
            p = subprocess.Popen(["xclip", "-selection", "clipboard"], stdin=subprocess.PIPE,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            p.communicate(text.encode(), timeout=2)
        except (OSError, subprocess.SubprocessError):
            pass
    else:
        try:
            subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL).communicate(text.encode(), timeout=2)
        except (OSError, subprocess.SubprocessError):
            pass


# ---- الزراير ----

def press_combo(*keys: str) -> None:
    """مثلاً press_combo("ctrl", "c")"""
    if session_type() == "x11":
        _run(["xdotool", "key", "--clearmodifiers", "+".join(keys)])
    else:
        codes = [_KEY[k] for k in keys]
        seq = [f"{c}:1" for c in codes] + [f"{c}:0" for c in reversed(codes)]
        _run(["ydotool", "key", *seq])


def wait_for_release() -> None:
    """نستنى المستخدم يرفع إيده من الاختصار علشان ما يتخلطش مع Ctrl+C اللي هنبعتها"""
    time.sleep(0.12 if session_type() == "x11" else 0.3)


# ---- البرنامج اللي قدام (X11 بس) ----

def active_app() -> tuple[str | None, bool]:
    """(اسم البرنامج للإحصائيات، هل هو Terminal)"""
    if session_type() != "x11" or not _has("xdotool"):
        return None, False
    cls = (_run(["xdotool", "getactivewindow", "getwindowclassname"]) or "").strip()
    if not cls:
        return None, False
    is_term = cls.lower() in TERMINALS
    pretty = cls.split(".")[-1].replace("-", " ").replace("_", " ")
    pretty = pretty[:1].upper() + pretty[1:]
    return pretty, is_term


def active_pid() -> int | None:
    if session_type() != "x11" or not _has("xdotool"):
        return None
    out = _run(["xdotool", "getactivewindow", "getwindowpid"])
    try:
        return int(out.strip()) if out else None
    except ValueError:
        return None


def open_url(url: str) -> None:
    try:
        subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


def play_sound(path: str) -> None:
    """نغمة التحويل (PipeWire / PulseAudio / ALSA، أول واحد موجود)"""
    for player in ("pw-play", "paplay", "aplay"):
        exe = shutil.which(player)
        if exe:
            try:
                subprocess.Popen([exe, path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except OSError:
                continue
            return

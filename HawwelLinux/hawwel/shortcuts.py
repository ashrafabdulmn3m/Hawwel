"""
الاختصار في لينكس بيتعمل من إعدادات الديسكتوب (ده الطريق الوحيد اللي بيشتغل على Wayland كمان):
الاختصار بيشغّل "hawwel --convert"، وده بيبلّغ البرنامج الشغّال يحوّل.

على GNOME / Ubuntu بنظبطه لوحدنا من gsettings. على باقي الديسكتوبات بنوري المستخدم الأمر يضيفه بنفسه.
"""

from __future__ import annotations

import ast
import os
import re
import shutil
import subprocess
import sys

from . import system

_SCHEMA = "org.gnome.settings-daemon.plugins.media-keys"
_PATH = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/hawwel/"
_ITEM = f"{_SCHEMA}.custom-keybinding:{_PATH}"


def command() -> str:
    """الأمر اللي الاختصار بيشغّله"""
    exe = shutil.which("hawwel")
    if exe:
        return f"{exe} --convert"
    # شغّال من الكود نفسه (مش متسطّب)
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return f"sh -c 'cd \"{root}\" && \"{sys.executable}\" -m hawwel --convert'"


def app_command() -> str:
    """أمر فتح البرنامج (للتشغيل مع الجهاز)"""
    exe = shutil.which("hawwel")
    if exe:
        return exe
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return f"sh -c 'cd \"{root}\" && \"{sys.executable}\" -m hawwel'"


# ---- عرض الاختصار ----

_NAMES = {"Primary": "Ctrl", "Control": "Ctrl", "Ctrl": "Ctrl", "Alt": "Alt", "Shift": "Shift",
          "Super": "Super", "Meta": "Super"}


def parts(accel: str) -> list[str]:
    """"<Primary><Alt>k" → ["Ctrl", "Alt", "K"]"""
    mods = [_NAMES.get(m, m) for m in re.findall(r"<(\w+)>", accel)]
    key = re.sub(r"<\w+>", "", accel)
    key = {"space": "Space", "Return": "Enter"}.get(key, key.upper() if len(key) == 1 else key)
    order = ["Ctrl", "Alt", "Shift", "Super"]
    return sorted(set(mods), key=order.index) + ([key] if key else [])


def describe(accel: str) -> str:
    return "+".join(parts(accel))


# ---- GNOME ----

def _gs(*args: str) -> str | None:
    try:
        r = subprocess.run(["gsettings", *args], capture_output=True, timeout=3)
        return r.stdout.decode().strip() if r.returncode == 0 else None
    except (OSError, subprocess.SubprocessError):
        return None


def _gs_list(raw: str | None) -> list[str]:
    if not raw:
        return []
    raw = raw.replace("@as ", "")
    try:
        v = ast.literal_eval(raw)
        return list(v) if isinstance(v, (list, tuple)) else []
    except (ValueError, SyntaxError):
        return []


def apply_gnome(accel: str) -> bool:
    """بيكتب الاختصار في إعدادات GNOME. بيرجع True لو نجح."""
    if not system.is_gnome_like():
        return False
    paths = _gs_list(_gs("get", _SCHEMA, "custom-keybindings"))
    if _PATH not in paths:
        paths.append(_PATH)
        if _gs("set", _SCHEMA, "custom-keybindings", str(paths)) is None:
            return False
    ok = all(_gs("set", _ITEM, k, v) is not None for k, v in
             (("name", "Hawwel"), ("command", command()), ("binding", accel)))
    return ok


def gnome_is_applied(accel: str) -> bool:
    if not system.is_gnome_like():
        return False
    return (_gs("get", _ITEM, "binding") or "").strip("'") == accel and \
        _PATH in _gs_list(_gs("get", _SCHEMA, "custom-keybindings"))


def conflicts(accel: str) -> bool:
    """الاختصار مستخدم في GNOME في حاجة تانية؟"""
    if not system.is_gnome_like():
        return False
    norm = accel.lower().replace("<control>", "<primary>").replace("<ctrl>", "<primary>")
    for schema in ("org.gnome.desktop.wm.keybindings", "org.gnome.shell.keybindings", _SCHEMA,
                   "org.gnome.mutter.keybindings", "org.gnome.mutter.wayland.keybindings"):
        out = _gs("list-recursively", schema) or ""
        for line in out.splitlines():
            if "custom-keybinding" in line:
                continue
            values = line.split(" ", 2)[-1].lower().replace("<control>", "<primary>")
            if f"'{norm}'" in values:
                return True
    # الاختصارات الخاصة التانية (مش بتاعتنا)
    for p in _gs_list(_gs("get", _SCHEMA, "custom-keybindings")):
        if p == _PATH:
            continue
        b = (_gs("get", f"{_SCHEMA}.custom-keybinding:{p}", "binding") or "").strip("'").lower()
        if b.replace("<control>", "<primary>") == norm:
            return True
    return False


def open_keyboard_settings() -> None:
    d = system.desktop()
    candidates = {
        "GNOME": ["gnome-control-center", "keyboard"],
        "KDE": ["systemsettings", "kcm_keys"],
        "XFCE": ["xfce4-keyboard-settings"],
        "CINNAMON": ["cinnamon-settings", "keyboard"],
        "MATE": ["mate-keybinding-properties"],
    }
    cmd = candidates.get(d)
    if cmd and shutil.which(cmd[0]):
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

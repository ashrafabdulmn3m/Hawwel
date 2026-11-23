"""
hawwel               يفتح البرنامج (أو يجيب النافذة لو شغّال)
hawwel --convert     يحوّل الكلام المحدد (ده اللي اختصار الكيبورد بيشغّله)
hawwel --background  يفتح في الـ tray من غير نافذة (التشغيل مع الجهاز)
"""

from __future__ import annotations

import socket
import sys

from . import __version__
from .paths import socket_path


def _send(cmd: str) -> bool:
    """بيبعت أمر للبرنامج الشغّال. False لو مش شغّال."""
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.settimeout(1.0)
            s.connect(socket_path())
            s.sendall(cmd.encode() + b"\n")
        return True
    except OSError:
        return False


def main() -> int:
    args = sys.argv[1:]
    if "--version" in args:
        print(__version__)
        return 0
    convert = "--convert" in args
    background = "--background" in args or convert

    # البرنامج شغّال؟ نبعتله الأمر ونخرج (سريع: من غير ما نحمّل Qt)
    if _send("convert" if convert else "show" if not background else "noop"):
        return 0

    from PySide6.QtWidgets import QApplication
    from .app import HawwelApp

    qapp = QApplication(sys.argv)
    qapp.setQuitOnLastWindowClosed(False)  # قفل النافذة مش بيقفل البرنامج
    app = HawwelApp(qapp, background=background, convert_on_start=convert)
    qapp._hawwel = app  # نفضل ماسكينه
    return qapp.exec()


if __name__ == "__main__":
    sys.exit(main())

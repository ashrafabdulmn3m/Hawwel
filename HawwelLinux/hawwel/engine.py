"""
نفس منطق Engine.swift: ينسخ التحديد → يحوّله → يلصقه → يرجّع الـ clipboard القديم.
لو مفيش كلام محدد: ما بيعملش حاجة وبيقول للمستخدم يحدد الأول.
"""

from __future__ import annotations

import threading
import time
import uuid

from PySide6.QtCore import QObject, Signal

from . import system
from .converter import convert, is_to_arabic

READY, CONVERTED, NO_SELECTION, NO_TOOLS, ERROR = "ready", "converted", "no_selection", "no_tools", "error"


class Engine(QObject):
    # (النتيجة، هل كانت في خانة "جرّب هنا")
    finished = Signal(str, bool)

    def __init__(self, stats):
        super().__init__()
        self.stats = stats
        self.status = READY
        self._busy = False
        self._lock = threading.Lock()

    def run(self, practice: bool = False) -> None:
        with self._lock:
            if self._busy:
                return
            self._busy = True
        threading.Thread(target=self._work, args=(practice,), daemon=True).start()

    def _work(self, practice: bool) -> None:
        result = ERROR
        try:
            result = self._convert_selection(practice)
        except Exception as e:  # noqa: BLE001 — أي مشكلة في أداة خارجية ما توقعش البرنامج
            print("Hawwel: conversion failed:", e)
            result = ERROR
        finally:
            with self._lock:
                self._busy = False
            self.status = result
            self.finished.emit(result, practice)  # بيوصل للـ main thread

    def _convert_selection(self, practice: bool) -> str:
        if system.missing_tools():
            return NO_TOOLS

        system.wait_for_release()
        app, is_terminal = system.active_app()
        copy_keys = ("ctrl", "shift", "c") if is_terminal else ("ctrl", "c")
        paste_keys = ("ctrl", "shift", "v") if is_terminal else ("ctrl", "v")

        saved = system.clipboard_get()
        # علامة مؤقتة في الـ clipboard: لو فضلت زي ما هي بعد Ctrl+C يبقى مفيش كلام محدد
        marker = f"hawwel-{uuid.uuid4().hex}"
        system.clipboard_set(marker)
        time.sleep(0.05)
        system.press_combo(*copy_keys)

        text = None
        for _ in range(12):  # لحد ~0.5 ثانية
            time.sleep(0.04)
            t = system.clipboard_get()
            if t and t != marker:
                text = t
                break

        if not text:
            system.clipboard_set(saved or "")
            return NO_SELECTION

        to_arabic = is_to_arabic(text)
        system.clipboard_set(convert(text))
        time.sleep(0.05)
        system.press_combo(*paste_keys)
        time.sleep(0.35)
        system.clipboard_set(saved or "")

        if not practice:
            self.stats.record(len(text), to_arabic, app)
        return CONVERTED

"""التطبيق: نسخة واحدة بس، الـ tray، والأوامر اللي جاية من "hawwel --convert"."""

from __future__ import annotations

import os
import threading
import time

from PySide6.QtCore import QObject, Qt, QTimer, Signal
from PySide6.QtGui import QFont, QGuiApplication, QIcon
from PySide6.QtNetwork import QLocalServer
from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

from . import i18n, shortcuts, system, theme, ui, updater
from .engine import Engine
from .i18n import T
from .paths import DATA_DIR, socket_path
from .settings import Settings, set_launch_at_login
from .stats import Stats


class HawwelApp(QObject):
    _update_done = Signal(str, object)  # نتيجة فحص التحديث من الـ thread للـ main thread

    def __init__(self, qapp: QApplication, background: bool = False, convert_on_start: bool = False):
        super().__init__()
        self.qapp = qapp
        self.quitting = False
        self.pending_update: tuple[str, str] | None = None
        self._update_cb = None
        self._update_done.connect(self._on_update_done)

        self.settings = Settings.load()
        i18n.set_language(self.settings.language)
        self.stats = Stats()
        self.engine = Engine(self.stats)
        self.engine.finished.connect(self._on_engine_finished)

        qapp.setApplicationName("Hawwel")
        qapp.setDesktopFileName("hawwel")
        qapp.setWindowIcon(QIcon(str(DATA_DIR / "logo.png")))
        f = QFont()
        f.setFamilies(theme.FONT_FAMILIES)
        qapp.setFont(f)

        self._start_server()
        self.window = None
        self.apply_theme()  # الألوان لازم تبقى جاهزة قبل ما النافذة تتبني
        self.window = ui.MainWindow(self)
        self.window.apply_colors()
        self._build_tray()
        hints = QGuiApplication.styleHints()
        if hasattr(hints, "colorSchemeChanged"):
            hints.colorSchemeChanged.connect(lambda *_: self.settings.theme == "system" and self.apply_theme())

        # على GNOME: نظبط الاختصار في إعدادات الديسكتوب لو مش متظبط
        if system.is_gnome_like() and not shortcuts.gnome_is_applied(self.settings.shortcut):
            shortcuts.apply_gnome(self.settings.shortcut)
            self.window.refresh_all()

        first_run = not self.settings.has_launched_before
        self.settings.has_launched_before = True
        self.settings.save()
        if first_run or not background or not self.tray_available():
            self.show_window()

        # التحديثات: بعد 8 ثواني، وبعدين كل 12 ساعة
        self._update_timer = QTimer(self)
        self._update_timer.timeout.connect(lambda: self.settings.auto_check_updates and self.check_updates())
        self._update_timer.start(12 * 3600 * 1000)
        QTimer.singleShot(8000, lambda: self.settings.auto_check_updates and self.check_updates())

        if convert_on_start:
            QTimer.singleShot(300, self.convert)

    # ---------- نسخة واحدة + أوامر من "hawwel --convert" ----------

    def _start_server(self) -> None:
        path = socket_path()
        QLocalServer.removeServer(path)  # socket قديم من مرة قفلت غلط
        self.server = QLocalServer(self)
        self.server.newConnection.connect(self._on_connection)
        if not self.server.listen(path):
            print("Hawwel: couldn't listen on", path, self.server.errorString())

    def _on_connection(self) -> None:
        conn = self.server.nextPendingConnection()
        if conn is None:
            return

        def read():
            cmd = bytes(conn.readAll()).decode(errors="ignore").strip()
            conn.disconnectFromServer()
            if cmd == "convert":
                self.convert()
            elif cmd == "show":
                self.show_window()

        if conn.bytesAvailable():
            read()
        else:
            conn.readyRead.connect(read)

    def convert(self) -> None:
        # لو الاختصار اتداس وإحنا في خانة "جرّب هنا" ما نحسبهاش في الإحصائيات
        self.engine.run(practice=self.window.isVisible() and self.window.try_has_focus())

    def _on_engine_finished(self, result: str, practice: bool) -> None:
        if result == "converted" and self.settings.play_sound:
            system.play_sound(str(DATA_DIR / "convert-sound.wav"))
        if result == "no_tools" and not practice and self.tray.isVisible():
            self.tray.showMessage("Hawwel", T("err.tools"), QSystemTrayIcon.Warning, 6000)
        self.window.on_engine_finished(result, practice)
        if result == "converted" and not practice:
            self.window.refresh_home()

    # ---------- النافذة والـ tray ----------

    def show_window(self) -> None:
        self.window.refresh_all()
        self.window.show()
        self.window.raise_()
        self.window.activateWindow()

    def tray_available(self) -> bool:
        return QSystemTrayIcon.isSystemTrayAvailable()

    def _build_tray(self) -> None:
        self.tray = QSystemTrayIcon(QIcon(str(DATA_DIR / "tray.png")), self)
        self.tray.activated.connect(
            lambda reason: reason == QSystemTrayIcon.Trigger and self.show_window())
        self._build_tray_menu()
        self.tray.setVisible(self.settings.show_tray and self.tray_available())

    def _build_tray_menu(self) -> None:
        menu = QMenu()
        menu.setLayoutDirection(Qt.RightToLeft if i18n.is_arabic() else Qt.LeftToRight)
        menu.addAction(T("menu.convert"), lambda: QTimer.singleShot(350, self.convert))
        menu.addAction(T("menu.open"), self.show_window)
        menu.addAction(T("menu.update"), lambda: (self.show_window(), self.check_updates(user=True)))
        menu.addSeparator()
        menu.addAction(T("menu.quit"), self.quit)
        self._menu = menu  # لازم نفضل ماسكينه
        self.tray.setContextMenu(menu)
        self.tray.setToolTip(T("tray.tooltip"))

    # ---------- الإعدادات (من البانل) ----------

    def shortcut_ok(self) -> bool:
        if system.missing_tools() or not system.ydotoold_running():
            return False
        if system.is_gnome_like():
            return shortcuts.gnome_is_applied(self.settings.shortcut)
        return True  # الديسكتوبات التانية: المستخدم بيظبطه بنفسه

    def set_shortcut(self, accel: str) -> None:
        self.settings.shortcut = accel
        self.settings.save()
        if system.is_gnome_like():
            shortcuts.apply_gnome(accel)
        self.window.refresh_all()

    def set_language(self, lang: str) -> None:
        self.settings.language = lang
        self.settings.save()
        i18n.set_language(lang)
        self.window.build()
        self.window.apply_colors()
        self._build_tray_menu()

    def set_theme(self, mode: str) -> None:
        self.settings.theme = mode
        self.settings.save()
        self.apply_theme()

    def apply_theme(self) -> None:
        mode = self.settings.theme
        dark = mode == "dark"
        if mode == "system":
            hints = QGuiApplication.styleHints()
            dark = hasattr(hints, "colorScheme") and hints.colorScheme() == Qt.ColorScheme.Dark
        colors = theme.colors(dark)
        ui.C.clear()
        ui.C.update(colors)
        self.qapp.setStyleSheet(theme.stylesheet(colors))
        if self.window is not None:
            self.window.apply_colors()

    def set_login(self, on: bool) -> None:
        set_launch_at_login(on, shortcuts.app_command())

    def set_tray(self, on: bool) -> None:
        self.settings.show_tray = on
        self.settings.save()
        self.tray.setVisible(on and self.tray_available())

    def set_sound(self, on: bool) -> None:
        self.settings.play_sound = on
        self.settings.save()
        if on:  # تسمعه أول ما تفعّله
            system.play_sound(str(DATA_DIR / "convert-sound.wav"))

    def set_auto_check(self, on: bool) -> None:
        self.settings.auto_check_updates = on
        self.settings.save()

    def reset_all(self) -> None:
        self.settings.reset_to_defaults()
        if system.is_gnome_like():
            shortcuts.apply_gnome(self.settings.shortcut)
        self.tray.setVisible(self.settings.show_tray and self.tray_available())
        self.apply_theme()
        self.window.build()
        self.window.apply_colors()

    # ---------- التحديثات ----------

    def check_updates(self, user: bool = False, done=None) -> None:
        self._update_cb = done

        def work():
            try:
                res = updater.check()
                self._update_done.emit("found" if res else "none", (res, user))
            except Exception:  # noqa: BLE001 — مفيش نت أو GitHub مش متاح: ما نزعجش المستخدم
                self._update_done.emit("failed", (None, user))

        threading.Thread(target=work, daemon=True).start()

    def _on_update_done(self, result: str, payload) -> None:
        res, user = payload
        if result != "failed":
            self.settings.last_update_check = time.time()
            self.pending_update = res
            # إشعار مرة واحدة بس لكل إصدار
            if res and not user and self.settings.last_notified_update != res[0] and self.tray.isVisible():
                self.settings.last_notified_update = res[0]
                self.tray.showMessage("Hawwel", T("tray.balloon", res[0]), QSystemTrayIcon.Information, 10000)
            self.settings.save()
        self.window.refresh_home()
        self.window.refresh_settings()
        if self._update_cb:
            cb, self._update_cb = self._update_cb, None
            cb(result)

    def quit(self) -> None:
        self.quitting = True
        self.tray.hide()
        self.server.close()
        QLocalServer.removeServer(socket_path())
        self.qapp.quit()

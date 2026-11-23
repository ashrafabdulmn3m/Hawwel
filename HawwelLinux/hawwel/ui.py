"""البانل: سايدبار + محتوى التاب + فوتر (780×560، وبيتكبّر براحتك)."""

from __future__ import annotations

from PySide6.QtCore import QEvent, QObject, QRectF, QSize, Qt, QTimer
from PySide6.QtGui import QColor, QGuiApplication, QKeySequence, QPainter, QPixmap
from PySide6.QtWidgets import (
    QAbstractButton, QApplication, QFrame, QGraphicsOpacityEffect, QGridLayout, QHBoxLayout, QLabel,
    QMessageBox, QPlainTextEdit, QPushButton, QScrollArea, QSizePolicy, QStackedWidget, QVBoxLayout, QWidget,
)

from . import i18n, icons, shortcuts, system, updater
from .i18n import T
from .paths import DATA_DIR

PANEL_W, PANEL_H, MIN_W, MIN_H = 780, 560, 660, 460
TABS = [("home", "home"), ("shortcuts", "keys"), ("activity", "chart"), ("settings", "gear"), ("about", "info")]
LINKS = {
    "website": "https://hawwelapp.vercel.app/",
    "source": "https://github.com/ashrafabdulmn3m/Hawwel",
    "bug": "https://www.youtube.com/@HawwelApp",
    "feature": "https://docs.google.com/forms/d/e/1FAIpQLSea7SjLbKyhVT8Bp3jT2pljAdNw3ymSG9_iVv-fBfg9PpUMkg/viewform",
}
SOCIAL = [
    ("fb", "Facebook", "https://www.facebook.com/ashrafmn3m/"),
    ("ig", "Instagram", "https://www.instagram.com/ashrafabdulmonnem/"),
    ("gh", "GitHub", "https://github.com/ashrafabdulmn3m"),
    ("yt", "YouTube", "https://www.youtube.com/@HawwelApp"),
]

# الألوان الحالية (بتتغيّر مع الثيم) — للحاجات اللي بنرسمها بنفسنا
C: dict[str, str] = {}


# ================= مكوّنات صغيرة =================

def repolish(w: QWidget) -> None:
    w.style().unpolish(w)
    w.style().polish(w)
    w.update()


def lbl(text: str = "", cls: str | None = None, wrap: bool = False) -> QLabel:
    l = QLabel(text)
    if cls:
        l.setProperty("cls", cls)
    l.setWordWrap(wrap)
    l.setTextInteractionFlags(Qt.NoTextInteraction)
    return l


def btn(text: str, cls: str | None = None, slot=None) -> QPushButton:
    b = QPushButton(text)
    if cls:
        b.setProperty("cls", cls)
    b.setCursor(Qt.PointingHandCursor)
    b.setFocusPolicy(Qt.TabFocus)
    if slot:
        b.clicked.connect(slot)
    return b


def card(cls: str = "card", margins=(16, 14, 16, 14), spacing: int = 8) -> tuple[QFrame, QVBoxLayout]:
    f = QFrame()
    f.setProperty("cls", cls)
    lay = QVBoxLayout(f)
    lay.setContentsMargins(*margins)
    lay.setSpacing(spacing)
    return f, lay


def divider() -> QFrame:
    d = QFrame()
    d.setProperty("cls", "divider")
    d.setFixedHeight(1)
    return d


def hrow(*widgets, spacing: int = 8, stretch_at: int | None = None) -> QHBoxLayout:
    """صف أفقي، ولو stretch_at اتحدد بنحط مسافة مرنة قبل العنصر ده"""
    h = QHBoxLayout()
    h.setContentsMargins(0, 0, 0, 0)
    h.setSpacing(spacing)
    for i, w in enumerate(widgets):
        if stretch_at is not None and i == stretch_at:
            h.addStretch(1)
        if isinstance(w, QWidget):
            h.addWidget(w)
        else:
            h.addLayout(w)
    return h


def vbox(*widgets, spacing: int = 1) -> QVBoxLayout:
    v = QVBoxLayout()
    v.setContentsMargins(0, 0, 0, 0)
    v.setSpacing(spacing)
    for w in widgets:
        v.addWidget(w)
    return v


class Pill(QFrame):
    """حالة صغيرة: نقطة + كلمة (ok / warn / info / soon)"""

    def __init__(self, kind: str = "ok", text: str = "", dot: bool = True):
        super().__init__()
        h = QHBoxLayout(self)
        h.setContentsMargins(10, 3, 10, 3)
        h.setSpacing(6)
        self.dot = QLabel("●")
        self.text = QLabel()
        self.dot.setVisible(dot)
        h.addWidget(self.dot)
        h.addWidget(self.text)
        self.setSizePolicy(QSizePolicy.Maximum, QSizePolicy.Fixed)
        self.set(kind, text)

    def set(self, kind: str, text: str) -> None:
        self.setProperty("cls", f"pill-{kind}")
        for w in (self.dot, self.text):
            w.setProperty("pill", kind)
            repolish(w)
        self.dot.setStyleSheet("font-size: 8px;")
        self.text.setText(text)
        repolish(self)


class Keycaps(QWidget):
    """الكيكابس: دايماً LTR في اللغتين"""

    HEIGHT = {"small": 22, "regular": 32, "large": 42}

    def __init__(self, parts: list[str], size: str = "regular"):
        super().__init__()
        self.setLayoutDirection(Qt.LeftToRight)
        self.size = size
        self.lay = QHBoxLayout(self)
        self.lay.setContentsMargins(0, 0, 0, 0)
        self.lay.setSpacing(6)
        self.keys: list[QLabel] = []
        self.set_parts(parts)

    def set_parts(self, parts: list[str]) -> None:
        while self.lay.count():
            w = self.lay.takeAt(0).widget()
            if w:
                w.hide()
                w.setParent(None)
                w.deleteLater()
        self.keys = []
        for i, p in enumerate(parts):
            if i:
                self.lay.addWidget(lbl("+", "plus"))
            k = QLabel(p)
            k.setProperty("cls", "key")
            k.setProperty("keySize", self.size)
            k.setAlignment(Qt.AlignCenter)
            k.setFixedHeight(self.HEIGHT[self.size])
            k.setMinimumWidth({"small": 24, "regular": 34, "large": 44}[self.size])
            self.lay.addWidget(k)
            self.keys.append(k)

    def set_lit(self, lit: bool) -> None:
        for k in self.keys:
            k.setProperty("lit", "true" if lit else "false")
            repolish(k)


class Switch(QAbstractButton):
    """سويتش 38×22 (بيتعكس في العربي)"""

    def __init__(self, checked: bool = False, slot=None):
        super().__init__()
        self.setCheckable(True)
        self.setChecked(checked)
        self.setCursor(Qt.PointingHandCursor)
        self.setFixedSize(38, 22)
        if slot:
            self.toggled.connect(slot)

    def sizeHint(self) -> QSize:
        return QSize(38, 22)

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        on = self.isChecked()
        if not self.isEnabled():
            p.setOpacity(0.5)
        p.setPen(Qt.NoPen)
        p.setBrush(QColor(C["accent"] if on else C["switchOff"]))
        p.drawRoundedRect(QRectF(0, 0, 38, 22), 11, 11)
        rtl = self.layoutDirection() == Qt.RightToLeft
        knob_right = on != rtl
        x = 19 if knob_right else 3
        p.setBrush(QColor(0, 0, 0, 40))
        p.drawEllipse(QRectF(x, 4, 16, 16))
        p.setBrush(QColor("white"))
        p.drawEllipse(QRectF(x, 3, 16, 16))


class Segmented(QFrame):
    """اختيار من كذا حاجة (المظهر / اللغة)"""

    def __init__(self, options: list[tuple[str, str, str | None]], selected: str, on_change):
        super().__init__()
        self.setProperty("cls", "seg")
        h = QHBoxLayout(self)
        h.setContentsMargins(2, 2, 2, 2)
        h.setSpacing(2)
        self.buttons = {}
        for oid, text, icon in options:
            b = btn(text, "segBtn")
            b.setCheckable(True)
            b.setChecked(oid == selected)
            if icon:
                b.setIcon(icons.icon(icon, C["ink"] if oid == selected else C["muted"], 13))
                b.setIconSize(QSize(13, 13))
            b.clicked.connect(lambda _=False, o=oid: self._pick(o, on_change))
            h.addWidget(b)
            self.buttons[oid] = b
        self.setSizePolicy(QSizePolicy.Maximum, QSizePolicy.Fixed)

    def _pick(self, oid: str, on_change) -> None:
        for k, b in self.buttons.items():
            b.setChecked(k == oid)
        on_change(oid)


class BarChart(QWidget):
    """آخر 7 أيام: عمود لكل يوم، والنهارده لونه أغمق"""

    def __init__(self):
        super().__init__()
        self.setMinimumHeight(110)
        self.data: list[tuple[str, int]] = []

    def set_data(self, data: list[tuple[str, int]]) -> None:
        self.data = data
        self.update()

    def paintEvent(self, _):
        if not self.data:
            return
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        w, h = self.width(), self.height()
        n = len(self.data)
        col = w / n
        peak = max(1, max(c for _, c in self.data))
        f = p.font()
        rtl = self.layoutDirection() == Qt.RightToLeft
        for i, (day, count) in enumerate(self.data):
            idx = n - 1 - i if rtl else i
            today = i == n - 1
            x0 = idx * col
            bar_w = min(34, col - 10)
            bh = max(3, count / peak * 62)
            bx = x0 + (col - bar_w) / 2
            by = h - 22 - bh
            p.setPen(Qt.NoPen)
            p.setBrush(QColor(C["accent"] if today else C["accentMid"]))
            p.drawRoundedRect(QRectF(bx, by, bar_w, bh), 5, 5)
            f.setPixelSize(11)
            f.setBold(False)
            p.setFont(f)
            p.setPen(QColor(C["muted"]))
            p.drawText(QRectF(x0, by - 18, col, 16), Qt.AlignCenter, str(count))
            f.setBold(today)
            p.setFont(f)
            p.setPen(QColor(C["ink"] if today else C["muted"]))
            p.drawText(QRectF(x0, h - 18, col, 18), Qt.AlignCenter, day)


class ShareBar(QWidget):
    """شريط نسبة (اتجاه التحويل / أكتر البرامج)"""

    def __init__(self, share: float | None, height: int = 8, two_tone: bool = True):
        super().__init__()
        self.share, self.two_tone = share, two_tone
        self.setFixedHeight(height)

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        w, h = self.width(), self.height()
        r = h / 2
        p.setPen(Qt.NoPen)
        p.setBrush(QColor(C["accentMid"] if (self.two_tone and self.share is not None) else C["field"]))
        p.drawRoundedRect(QRectF(0, 0, w, h), r, r)
        if self.share:
            fw = w * self.share
            x = w - fw if self.layoutDirection() == Qt.RightToLeft else 0
            p.setBrush(QColor(C["accent"]))
            p.drawRoundedRect(QRectF(x, 0, fw, h), r, r)


class StepPill(QFrame):
    def __init__(self, number: int, text: str):
        super().__init__()
        h = QHBoxLayout(self)
        h.setContentsMargins(3, 2, 10, 2)
        h.setSpacing(6)
        self.num = QLabel(str(number))
        self.num.setAlignment(Qt.AlignCenter)
        self.num.setFixedSize(18, 18)
        self.text = QLabel(text)
        h.addWidget(self.num)
        h.addWidget(self.text)
        self.setSizePolicy(QSizePolicy.Maximum, QSizePolicy.Fixed)
        self.set_done(False)

    def set_done(self, done: bool) -> None:
        self.setProperty("cls", "stepDone" if done else "step")
        self.num.setProperty("cls", "stepNumDone" if done else "stepNum")
        self.text.setProperty("cls", "stepTextDone" if done else "stepText")
        for w in (self, self.num, self.text):
            repolish(w)


def logo_box(size: int, radius_cls: str = "logoBox") -> QFrame:
    f = QFrame()
    f.setProperty("cls", radius_cls)
    f.setFixedSize(size, size)
    l = QLabel(f)
    pm = QPixmap(str(DATA_DIR / "logo.png"))
    inner = int(size * 0.86)
    dpr = 2.0
    pm = pm.scaled(int(inner * dpr), int(inner * dpr), Qt.KeepAspectRatio, Qt.SmoothTransformation)
    pm.setDevicePixelRatio(dpr)
    l.setPixmap(pm)
    l.setGeometry((size - inner) // 2, (size - inner) // 2, inner, inner)
    l.setAlignment(Qt.AlignCenter)
    return f


def scroll_page(content: QWidget) -> QScrollArea:
    s = QScrollArea()
    s.setWidgetResizable(True)
    s.setFrameShape(QFrame.NoFrame)
    s.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
    s.setWidget(content)
    return s


# ================= النافذة =================

class MainWindow(QWidget):
    def __init__(self, ctx):
        super().__init__()
        self.ctx = ctx                     # التطبيق نفسه (settings, stats, engine, …)
        self.tab = "home"
        self.recording = False
        self.try_text = T("try.sample").strip("\u200f")
        self.converted = self.no_selection = False
        self.check_message: str | None = None
        self.setWindowTitle("Hawwel - حوّل")
        self.setObjectName("Root")
        self.setMinimumSize(MIN_W, MIN_H)
        self.resize(PANEL_W, PANEL_H)
        self.build()

    # ---------- بناء الواجهة (بيتعاد لما اللغة تتغيّر) ----------

    def build(self) -> None:
        old = self.layout()
        if old is not None:
            QWidget().setLayout(old)  # نشيل القديم
        self.setLayoutDirection(Qt.RightToLeft if i18n.is_arabic() else Qt.LeftToRight)
        # لو المثال لسه زي ما هو، نبدّله بمثال اللغة الحالية
        if self.try_text.strip("\u200f") in ("hgsghl ugd;l", "اثممخ صخقمي"):
            self.try_text = T("try.sample").strip("\u200f")

        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)
        top = QHBoxLayout()
        top.setSpacing(0)
        root.addLayout(top, 1)

        self.side = self._build_sidebar()
        top.addWidget(self.side)
        vline = QFrame()
        vline.setObjectName("VLine")
        vline.setFixedWidth(1)
        top.addWidget(vline)

        main = QWidget()
        main.setObjectName("Main")
        mv = QVBoxLayout(main)
        mv.setContentsMargins(0, 0, 0, 0)
        mv.setSpacing(0)
        head = QVBoxLayout()
        head.setContentsMargins(22, 16, 22, 10)
        head.setSpacing(1)
        self.h1 = lbl("", "h1")
        self.h_sub = lbl("", "sub")
        head.addWidget(self.h1)
        head.addWidget(self.h_sub)
        mv.addLayout(head)
        self.stack = QStackedWidget()
        mv.addWidget(self.stack, 1)
        top.addWidget(main, 1)

        self.pages = {
            "home": self._page_home(),
            "shortcuts": self._page_shortcuts(),
            "activity": self._page_activity(),
            "settings": self._page_settings(),
            "about": self._page_about(),
        }
        for p in self.pages.values():
            self.stack.addWidget(p)

        root.addWidget(self._build_footer())
        self.apply_sidebar()
        self.select_tab(self.tab)
        self.refresh_all()

    # ---------- السايدبار ----------

    def _build_sidebar(self) -> QFrame:
        side = QFrame()
        side.setObjectName("Side")
        v = QVBoxLayout(side)
        v.setSpacing(18)
        self.side_layout = v

        # اللوجو والاسم وزرار الطي
        self.brand = QWidget()
        self.brand_grid = QGridLayout(self.brand)
        self.brand_grid.setContentsMargins(0, 0, 0, 0)
        self.brand_grid.setHorizontalSpacing(10)
        self.brand_grid.setVerticalSpacing(10)
        self.logo = logo_box(40)
        self.brand_text = QWidget()
        bt = QVBoxLayout(self.brand_text)
        bt.setContentsMargins(0, 0, 0, 0)
        bt.setSpacing(0)
        bt.addWidget(lbl(T("app.name"), "brand"))
        ver = lbl(f"v{updater.current()}", "small")
        bt.addWidget(ver)
        self.toggle = btn("", "icon", self.toggle_sidebar)
        self.toggle.setFixedSize(28, 28)
        self.toggle.setIconSize(QSize(18, 18))
        v.addWidget(self.brand)

        # التابات
        self.nav_buttons: dict[str, QPushButton] = {}
        nav = QVBoxLayout()
        nav.setSpacing(2)
        for tid, icon in TABS:
            b = btn(T(f"tab.{tid}"), "nav", lambda _=False, t=tid: self.select_tab(t))
            b.setCheckable(True)
            b.setIconSize(QSize(18, 18))
            b.setProperty("iconName", icon)
            b.setMinimumHeight(36)
            nav.addWidget(b)
            self.nav_buttons[tid] = b
        v.addLayout(nav)
        v.addStretch(1)

        # حالة البرنامج تحت
        self.state = QFrame()
        sh = QHBoxLayout(self.state)
        sh.setContentsMargins(10, 8, 10, 8)
        sh.setSpacing(8)
        self.state_dot = QLabel("●")
        self.state_text = QLabel()
        sh.addWidget(self.state_dot)
        sh.addWidget(self.state_text, 1)
        v.addWidget(self.state)
        return side

    def apply_sidebar(self) -> None:
        c = self.ctx.settings.sidebar_collapsed
        self.side.setFixedWidth(64 if c else 196)
        self.side_layout.setContentsMargins(*((10, 16, 10, 14) if c else (12, 16, 12, 14)))
        g = self.brand_grid
        for w in (self.logo, self.brand_text, self.toggle):
            g.removeWidget(w)
        if c:
            g.addWidget(self.logo, 0, 0, Qt.AlignHCenter)
            g.addWidget(self.toggle, 1, 0, Qt.AlignHCenter)
            self.brand_text.hide()
        else:
            g.addWidget(self.logo, 0, 0)
            g.addWidget(self.brand_text, 0, 1)
            g.addWidget(self.toggle, 0, 2, Qt.AlignVCenter)
            g.setColumnStretch(1, 1)
            self.brand_text.show()
        self.logo.setFixedSize(36, 36) if c else self.logo.setFixedSize(40, 40)
        self.toggle.setToolTip(T("side.expand" if c else "side.collapse"))
        for tid, b in self.nav_buttons.items():
            b.setText("" if c else T(f"tab.{tid}"))
            b.setToolTip(T(f"tab.{tid}") if c else "")
            b.setStyleSheet("text-align: center; padding: 8px 0;" if c else "")
        self.state_text.setVisible(not c)
        self.state.layout().setContentsMargins(*((0, 10, 0, 10) if c else (10, 8, 10, 8)))
        self.state.layout().setAlignment(self.state_dot, Qt.AlignHCenter if c else Qt.AlignLeft)
        self.refresh_icons()

    def toggle_sidebar(self) -> None:
        self.ctx.settings.sidebar_collapsed = not self.ctx.settings.sidebar_collapsed
        self.ctx.settings.save()
        self.apply_sidebar()

    def select_tab(self, tab: str) -> None:
        if self.recording and tab != "shortcuts":
            self.stop_recording()
        self.tab = tab
        for t, b in self.nav_buttons.items():
            b.setChecked(t == tab)
        self.stack.setCurrentWidget(self.pages[tab])
        self.pages[tab].verticalScrollBar().setValue(0)
        self.h1.setText(T(f"tab.{tab}"))
        sub = "" if tab == "about" else T(f"sub.{tab}")
        self.h_sub.setText(sub)
        self.h_sub.setVisible(bool(sub))
        self.refresh_icons()
        if tab == "activity":
            self.refresh_stats()
        if tab == "settings":
            self.refresh_settings()

    def refresh_icons(self) -> None:
        if not C:
            return
        rtl = i18n.is_arabic()
        self.toggle.setIcon(icons.icon("sidebarR" if rtl else "sidebar", C["muted"], 18))
        for tid, b in self.nav_buttons.items():
            color = C["accent"] if b.isChecked() else C["muted"]
            b.setIcon(icons.icon(b.property("iconName"), color, 18))

    # ---------- الفوتر ----------

    def _build_footer(self) -> QFrame:
        foot = QFrame()
        foot.setObjectName("Foot")
        foot.setFixedHeight(44)
        h = QHBoxLayout(foot)
        h.setContentsMargins(16, 0, 16, 0)
        h.setSpacing(4)
        h.addWidget(lbl(T("footer.copyright"), "foot"))
        h.addStretch(1)
        self.social_buttons = []
        for icon, name, url in SOCIAL:
            b = btn("", "social", lambda _=False, u=url: system.open_url(u))
            b.setFixedSize(28, 28)
            b.setIconSize(QSize(16, 16))
            b.setToolTip(name)
            b.setProperty("iconName", icon)
            h.addWidget(b)
            self.social_buttons.append(b)
        return foot

    # ================= الرئيسية =================

    def _page_home(self) -> QScrollArea:
        page = QWidget()
        v = QVBoxLayout(page)
        v.setContentsMargins(22, 4, 22, 18)
        v.setSpacing(12)
        parts = shortcuts.parts(self.ctx.settings.shortcut)

        # حالة البرنامج والاختصار
        hero = QFrame()
        hero.setProperty("cls", "hero")
        hh = QHBoxLayout(hero)
        hh.setContentsMargins(16, 14, 16, 14)
        hh.setSpacing(16)
        self.hero_title = lbl("", "heroTitle", wrap=True)
        self.hero_desc = lbl("", "hint", wrap=True)
        hh.addLayout(vbox(self.hero_title, self.hero_desc, spacing=4), 1)
        self.hero_keys = Keycaps(parts, "large")
        hh.addWidget(self.hero_keys)
        v.addWidget(hero)

        # جرّب هنا
        tc, tl = card(spacing=10)
        reset = btn(T("try.reset"), "ghost", self.reset_try)
        tl.addLayout(hrow(lbl(T("try.title"), "title"), reset, stretch_at=1))
        self.steps = [StepPill(i, T(f"try.step{i}")) for i in (1, 2, 3)]
        sr = hrow(*self.steps, spacing=6)
        sr.addStretch(1)
        tl.addLayout(sr)
        self.try_edit = QPlainTextEdit(self.try_text)
        self.try_edit.setPlaceholderText(T("try.placeholder"))
        self.try_edit.setFixedHeight(70)
        self.try_edit.textChanged.connect(self.on_try_text)
        self.try_edit.selectionChanged.connect(self.refresh_try)
        tl.addWidget(self.try_edit)
        self.try_keys = Keycaps(parts, "small")
        self.try_pill = Pill()
        tl.addLayout(hrow(self.try_keys, self.try_pill, stretch_at=1))
        v.addWidget(tc)

        # النظام + النهارده
        grid = QHBoxLayout()
        grid.setSpacing(12)
        self.sys_card, sl = card()
        self.sys_pill = Pill()
        sl.addLayout(hrow(lbl(T("home.sys.title"), "title"), self.sys_pill, stretch_at=1))
        self.sys_desc = lbl("", "hint", wrap=True)
        sl.addWidget(self.sys_desc)
        self.sys_cmd = lbl("", "code")
        self.sys_cmd.setTextInteractionFlags(Qt.TextSelectableByMouse)
        self.sys_cmd.setLayoutDirection(Qt.LeftToRight)
        sl.addWidget(self.sys_cmd)
        self.sys_copy = btn(T("home.sys.copy"), "primary", self.copy_install)
        sl.addLayout(hrow(self.sys_copy, QWidget(), stretch_at=1))
        sl.addStretch(1)
        grid.addWidget(self.sys_card, 1)

        today, dl = card()
        dl.addLayout(hrow(lbl(T("home.today"), "title"), btn(T("home.toActivity"), "ghost",
                                                              lambda: self.select_tab("activity")), stretch_at=1))
        self.today_vals = [lbl("", "stat") for _ in range(3)]
        stats_row = QHBoxLayout()
        for val, key in zip(self.today_vals, ("home.today.conv", "home.today.chars", "home.today.saved")):
            stats_row.addLayout(vbox(val, lbl(T(key), "hint")), 1)
        dl.addLayout(stats_row)
        dl.addStretch(1)
        grid.addWidget(today, 1)
        v.addLayout(grid)

        # التحديث (بيظهر بس لو فيه إصدار جديد)
        self.update_card, ul = card("cardSoft")
        self.update_title = lbl("", "title", wrap=True)
        self.update_desc = lbl(T("home.update.desc"), "hint", wrap=True)
        ul.addLayout(hrow(vbox(self.update_title, self.update_desc),
                          btn(T("home.update.now"), "primary", self.open_update), stretch_at=1))
        v.addWidget(self.update_card)
        v.addStretch(1)
        return scroll_page(page)

    def refresh_home(self) -> None:
        ok = self.ctx.shortcut_ok()
        self.hero_title.setText(T("home.hero.title" if ok else "home.hero.titleOff"))
        self.hero_desc.setText(T("home.hero.desc" if ok else "home.hero.descOff"))

        missing = system.missing_tools()
        session = "X11" if system.session_type() == "x11" else "Wayland"
        if missing:
            self.sys_pill.set("warn", T("home.sys.off"))
            self.sys_desc.setText(T("home.sys.offDesc", ", ".join(missing)))
            self.sys_cmd.setText(system.install_command())
        elif not system.ydotoold_running():
            self.sys_pill.set("warn", T("home.sys.off"))
            self.sys_desc.setText(T("home.sys.ydotoold"))
            self.sys_cmd.setText("systemctl --user enable --now ydotool")
        else:
            self.sys_pill.set("ok", T("home.sys.ok"))
            self.sys_desc.setText(T("home.sys.okDesc", session))
        bad = bool(missing) or not system.ydotoold_running()
        self.sys_cmd.setVisible(bad)
        self.sys_copy.setVisible(bad)
        self.sys_copy.setText(T("home.sys.copy"))
        self.sys_card.setProperty("cls", "cardWarn" if bad else "card")
        repolish(self.sys_card)

        s = self.ctx.stats
        for w, val in zip(self.today_vals, (i18n.grouped(s.today_count), i18n.compact(s.today_chars),
                                           i18n.time_saved(s.today_chars))):
            w.setText(val)

        upd = self.ctx.pending_update
        self.update_card.setVisible(upd is not None)
        if upd:
            self.update_title.setText(T("home.update.title", upd[0]))

    def copy_install(self) -> None:
        QGuiApplication.clipboard().setText(self.sys_cmd.text())
        self.sys_copy.setText(T("home.sys.copied"))

    def open_update(self) -> None:
        if self.ctx.pending_update:
            system.open_url(self.ctx.pending_update[1])

    # ---- جرّب هنا: اكتب، حدد، اضغط الاختصار ----

    def on_try_text(self) -> None:
        self.try_text = self.try_edit.toPlainText()
        self.converted = False
        self.refresh_try()

    def reset_try(self) -> None:
        self.try_edit.setPlainText(T("try.sample").strip("\u200f"))
        self.converted = self.no_selection = False
        self.try_edit.setFocus()
        self.try_edit.selectAll()
        self.refresh_try()

    def try_has_focus(self) -> bool:
        return self.isActiveWindow() and self.try_edit.hasFocus()

    def refresh_try(self) -> None:
        has_sel = self.try_edit.textCursor().hasSelection()
        if has_sel:
            self.no_selection = False
        step = 3 if self.converted else 2 if has_sel else (1 if self.try_edit.toPlainText() else 0)
        for i, s in enumerate(self.steps, start=1):
            s.set_done(step >= i)
        if self.converted:
            self.try_pill.set("ok", T("try.state.done") + " ✓")
        elif self.no_selection:
            self.try_pill.set("warn", T("try.state.noSel"))
        elif has_sel:
            self.try_pill.set("info", T("try.state.sel"))
        else:
            self.try_pill.set("ok", T("try.state.ready"))

    def on_engine_finished(self, result: str, practice: bool) -> None:
        if result == "no_tools":
            self.refresh_home()
        if not practice:
            return
        self.try_keys.set_lit(True)
        QTimer.singleShot(260, lambda: self.try_keys.set_lit(False))
        if result == "converted":
            self.converted, self.no_selection = True, False
            self.try_edit.setProperty("flash", "true")
            repolish(self.try_edit)
            QTimer.singleShot(600, lambda: (self.try_edit.setProperty("flash", "false"), repolish(self.try_edit)))
        elif result == "no_selection":
            self.no_selection = True
        self.refresh_try()

    # ================= الاختصارات =================

    def _page_shortcuts(self) -> QScrollArea:
        page = QWidget()
        v = QVBoxLayout(page)
        v.setContentsMargins(22, 4, 22, 18)
        v.setSpacing(12)
        parts = shortcuts.parts(self.ctx.settings.shortcut)

        self.sc_idle, il = card()
        self.sc_keys = Keycaps(parts)
        il.addLayout(hrow(vbox(lbl(T("sc.flip.title"), "rowTitle"), lbl(T("sc.flip.desc"), "hint", True)),
                          self.sc_keys, btn(T("sc.change"), None, self.start_recording), stretch_at=1))
        v.addWidget(self.sc_idle)

        self.sc_rec, rl = card("recording")
        self.sc_rec_desc = lbl(T("sc.rec.desc"), "hint", True)
        title = lbl(T("sc.rec.title"), "title")
        self.sc_live = Keycaps(["?"])
        rl.addLayout(hrow(vbox(title, self.sc_rec_desc), self.sc_live,
                          btn(T("common.cancel"), "ghost", self.stop_recording), stretch_at=1))
        self.sc_rec.hide()
        v.addWidget(self.sc_rec)

        self.sc_conflict, cl = card()
        self.sc_conflict_keys = Keycaps([], "small")
        cl.addLayout(hrow(vbox(self.sc_conflict_keys, lbl(T("sc.conflict.desc"), "hint", True), spacing=4),
                          Pill("warn", T("sc.conflict")), stretch_at=1))
        self.sc_conflict.hide()
        v.addWidget(self.sc_conflict)

        # ظبط الاختصار في الديسكتوب
        self.sc_setup, setl = card()
        self.sc_setup_pill = Pill()
        self.sc_setup_text = lbl("", "hint", True)
        self.sc_setup_cmd = lbl(shortcuts.command(), "code")
        self.sc_setup_cmd.setTextInteractionFlags(Qt.TextSelectableByMouse)
        self.sc_setup_cmd.setLayoutDirection(Qt.LeftToRight)
        self.sc_setup_cmd.setWordWrap(True)
        self.sc_copy = btn(T("sc.setup.copy"), "primary", self.copy_command)
        self.sc_open = btn(T("sc.setup.openKb"), None, shortcuts.open_keyboard_settings)
        setl.addLayout(hrow(self.sc_setup_text, self.sc_setup_pill, stretch_at=1))
        setl.addWidget(self.sc_setup_cmd)
        btns = hrow(self.sc_copy, self.sc_open)
        btns.addStretch(1)
        setl.addLayout(btns)
        v.addWidget(self.sc_setup)

        soon, so = card()
        so.addLayout(hrow(vbox(lbl(T("sc.soon.title"), "rowTitle"), lbl(T("sc.soon.desc"), "hint", True)),
                          Pill("soon", T("sc.soon"), dot=False), stretch_at=1))
        eff = QGraphicsOpacityEffect(soon)
        eff.setOpacity(0.6)
        soon.setGraphicsEffect(eff)
        v.addWidget(soon)

        v.addLayout(hrow(lbl(T("sc.foot"), "hint"), btn(T("sc.resetDefault"), "ghost", self.reset_shortcut), stretch_at=1))
        v.addStretch(1)
        return scroll_page(page)

    def refresh_shortcuts(self) -> None:
        accel = self.ctx.settings.shortcut
        for k in (self.hero_keys, self.try_keys, self.sc_keys):
            k.set_parts(shortcuts.parts(accel))
        if system.is_gnome_like():
            ok = shortcuts.gnome_is_applied(accel)
            self.sc_setup_text.setText(T("sc.setup.gnome" if ok else "sc.setup.failed"))
            self.sc_setup_pill.set("ok" if ok else "warn", T("home.sys.ok" if ok else "home.sys.off"))
            self.sc_setup_pill.show()
            for w in (self.sc_setup_cmd, self.sc_copy, self.sc_open):
                w.setVisible(not ok)
        else:
            self.sc_setup_text.setText(T("sc.setup.manual"))
            self.sc_setup_pill.hide()
            for w in (self.sc_setup_cmd, self.sc_copy, self.sc_open):
                w.show()

    def copy_command(self) -> None:
        QGuiApplication.clipboard().setText(shortcuts.command())
        self.sc_copy.setText(T("sc.setup.copied"))

    def start_recording(self) -> None:
        self.recording = True
        self.sc_idle.hide()
        self.sc_conflict.hide()
        self.sc_rec.show()
        self.sc_rec_desc.setText(T("sc.rec.desc"))
        self._show_live(Qt.NoModifier)
        QApplication.instance().installEventFilter(self)

    def stop_recording(self) -> None:
        if not self.recording:
            return
        self.recording = False
        QApplication.instance().removeEventFilter(self)
        self.sc_rec.hide()
        self.sc_conflict.hide()
        self.sc_idle.show()

    def reset_shortcut(self) -> None:
        self.stop_recording()
        self.ctx.set_shortcut("<Primary><Alt>k")

    def _show_live(self, mods) -> None:
        p = []
        if mods & Qt.ControlModifier:
            p.append("Ctrl")
        if mods & Qt.AltModifier:
            p.append("Alt")
        if mods & Qt.ShiftModifier:
            p.append("Shift")
        if mods & Qt.MetaModifier:
            p.append("Super")
        self.sc_live.set_parts(p + ["?"])
        eff = QGraphicsOpacityEffect(self.sc_live)
        eff.setOpacity(1 if p else 0.45)
        self.sc_live.setGraphicsEffect(eff)

    def eventFilter(self, obj: QObject, ev: QEvent) -> bool:
        if not self.recording or ev.type() not in (QEvent.KeyPress, QEvent.KeyRelease, QEvent.ShortcutOverride):
            return False
        if ev.type() == QEvent.ShortcutOverride:
            ev.accept()
            return True
        mods = ev.modifiers()
        key = ev.key()
        if key in (Qt.Key_Control, Qt.Key_Alt, Qt.Key_Shift, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr):
            self._show_live(mods)
            return True
        if ev.type() == QEvent.KeyRelease:
            return True
        if key == Qt.Key_Escape and not mods:
            self.stop_recording()
            return True
        accel = self._to_accel(key, mods)
        if not accel:
            self.sc_rec_desc.setText(T("sc.rec.needMod"))
            return True
        if shortcuts.conflicts(accel):
            self.sc_conflict_keys.set_parts(shortcuts.parts(accel))
            self.sc_conflict.show()
            return True
        self.stop_recording()
        self.ctx.set_shortcut(accel)
        return True

    @staticmethod
    def _to_accel(key: int, mods) -> str | None:
        """مفتاح Qt → صيغة GNOME ("<Primary><Alt>k")"""
        prefix = ""
        if mods & Qt.ControlModifier:
            prefix += "<Primary>"
        if mods & Qt.AltModifier:
            prefix += "<Alt>"
        if mods & Qt.ShiftModifier:
            prefix += "<Shift>"
        if mods & Qt.MetaModifier:
            prefix += "<Super>"
        if not prefix or prefix == "<Shift>":
            return None
        if Qt.Key_A <= key <= Qt.Key_Z or Qt.Key_0 <= key <= Qt.Key_9:
            name = chr(key).lower()
        elif Qt.Key_F1 <= key <= Qt.Key_F12:
            name = f"F{key - Qt.Key_F1 + 1}"
        elif key == Qt.Key_Space:
            name = "space"
        else:
            name = QKeySequence(key).toString().lower()
            if not name:
                return None
        return prefix + name

    # ================= النشاط =================

    def _page_activity(self) -> QScrollArea:
        page = QWidget()
        v = QVBoxLayout(page)
        v.setContentsMargins(22, 4, 22, 18)
        v.setSpacing(12)

        self.stat_grid = QGridLayout()
        self.stat_grid.setSpacing(12)
        self.stat_cards = []
        self.stat_vals = []
        for key in ("act.total", "act.week", "act.chars", "act.time"):
            c, cl = card(spacing=1)
            val = lbl("", "stat")
            cl.addWidget(val)
            cl.addWidget(lbl(T(key), "hint"))
            self.stat_cards.append(c)
            self.stat_vals.append(val)
        self._layout_stats(4)
        v.addLayout(self.stat_grid)

        chart_card, chl = card()
        chl.addWidget(lbl(T("act.last7"), "title"))
        self.chart = BarChart()
        chl.addWidget(self.chart)
        v.addWidget(chart_card)

        row = QHBoxLayout()
        row.setSpacing(12)
        dc, self.dir_layout = card()
        self.dir_layout.addWidget(lbl(T("act.dir"), "title"))
        self.dir_holder = QVBoxLayout()
        self.dir_layout.addLayout(self.dir_holder)
        self.dir_layout.addStretch(1)
        row.addWidget(dc, 1)
        ac, al = card()
        al.addWidget(lbl(T("act.apps"), "title"))
        self.apps_holder = QVBoxLayout()
        self.apps_holder.setSpacing(6)
        al.addLayout(self.apps_holder)
        al.addStretch(1)
        row.addWidget(ac, 1)
        v.addLayout(row)

        self.clear_btn = btn(T("act.clear"), "danger", self.clear_stats)
        foot = lbl(T("act.foot"), "hint", True)
        v.addLayout(hrow(foot, self.clear_btn, stretch_at=1))
        v.addStretch(1)
        return scroll_page(page)

    def _layout_stats(self, cols: int) -> None:
        for c in self.stat_cards:
            self.stat_grid.removeWidget(c)
        for i, c in enumerate(self.stat_cards):
            self.stat_grid.addWidget(c, i // cols, i % cols)

    def resizeEvent(self, ev):
        super().resizeEvent(ev)
        if hasattr(self, "stat_grid"):
            # الأرقام الأربعة: جنب بعض، ولو النافذة ضيقة يبقوا 2×2
            body_w = self.width() - self.side.width() - 45
            cols = 2 if body_w < 520 else 4
            if getattr(self, "_stat_cols", 4) != cols:
                self._stat_cols = cols
                self._layout_stats(cols)

    @staticmethod
    def _clear(layout) -> None:
        while layout.count():
            item = layout.takeAt(0)
            w = item.widget()
            if w:
                w.hide()
                w.setParent(None)
                w.deleteLater()
            elif item.layout():
                MainWindow._clear(item.layout())

    def refresh_stats(self) -> None:
        s = self.ctx.stats
        for w, val in zip(self.stat_vals, (i18n.grouped(s.data.total), i18n.grouped(s.week_count),
                                          i18n.compact(s.data.chars), i18n.time_saved(s.data.chars))):
            w.setText(val)
        self.chart.set_data([(T(f"day.{(d.isoweekday() % 7) + 1}"), n) for d, n in s.last7()])

        self._clear(self.dir_holder)
        share = s.to_arabic_share
        self.dir_holder.addWidget(ShareBar(share))
        to_ar = round((share or 0) * 100)
        for key, value, color in (("act.dir.toArabic", f"{to_ar}%", "accent"),
                                  ("act.dir.toEnglish", f"{100 - to_ar}%", "accentMid")):
            dot = QLabel("●")
            dot.setStyleSheet(f"color: {C.get(color, '#888')}; font-size: 9px;")
            name = QLabel(T(key))
            name.setStyleSheet("font-size: 12px;")
            val = QLabel("–" if share is None else value)
            val.setStyleSheet("font-size: 12px; font-weight: 600;")
            self.dir_holder.addLayout(hrow(dot, name, val, stretch_at=2))

        self._clear(self.apps_holder)
        apps = s.top_apps()
        if not apps:
            self.apps_holder.addWidget(lbl(T("act.apps.empty"), "hint", True))
        for name, share_ in apps:
            n = QLabel(name)
            n.setFixedWidth(80)
            n.setStyleSheet("font-size: 12px;")
            bar = ShareBar(share_, 6, two_tone=False)
            pct = lbl(f"{round(share_ * 100)}%", "hint")
            pct.setFixedWidth(36)
            pct.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
            h = hrow(n, bar, pct, spacing=8)
            h.setStretch(1, 1)
            self.apps_holder.addLayout(h)
        self.clear_btn.setEnabled(s.data.total > 0)

    def clear_stats(self) -> None:
        if self.confirm(T("act.clear.confirm"), T("act.clear.confirmDesc")):
            self.ctx.stats.clear()
            self.refresh_stats()
            self.refresh_home()

    # ================= الإعدادات =================

    def _row(self, title: str, detail: str | None, control: QWidget) -> QWidget:
        w = QWidget()
        h = QHBoxLayout(w)
        h.setContentsMargins(0, 10, 0, 10)
        h.setSpacing(14)
        texts = vbox(lbl(title, "rowTitle", True))
        if detail is not None:
            d = lbl(detail, "hint", True)
            texts.addWidget(d)
            w.detail = d
        h.addLayout(texts, 1)
        h.addWidget(control, 0, Qt.AlignVCenter)
        w.setMinimumHeight(44)
        return w

    def _list_card(self, rows: list[QWidget]) -> QFrame:
        c, l = card(margins=(16, 2, 16, 2), spacing=0)
        for i, r in enumerate(rows):
            if i:
                l.addWidget(divider())
            l.addWidget(r)
        return c

    def _page_settings(self) -> QScrollArea:
        page = QWidget()
        v = QVBoxLayout(page)
        v.setContentsMargins(22, 4, 22, 18)
        v.setSpacing(12)
        st = self.ctx.settings

        def group(key):
            g = lbl(T(key), "group")
            g.setContentsMargins(4, 0, 4, 0)
            v.addWidget(g)

        group("set.general")
        self.sw_login = Switch(False, self.ctx.set_login)
        tray_ok = self.ctx.tray_available()
        self.sw_tray = Switch(st.show_tray, self.ctx.set_tray)
        self.sw_tray.setEnabled(tray_ok)
        self.seg_theme = Segmented([("light", T("set.appearance.light"), "sun"),
                                    ("dark", T("set.appearance.dark"), "moon"),
                                    ("system", T("set.appearance.system"), "monitor")], st.theme, self.ctx.set_theme)
        self.seg_lang = Segmented([("ar", "عربي", None), ("en", "English", None)], i18n.language(), self.ctx.set_language)
        v.addWidget(self._list_card([
            self._row(T("set.login"), None, self.sw_login),
            self._row(T("set.menubar"), T("set.menubar.desc" if tray_ok else "set.menubar.unavailable"), self.sw_tray),
            self._row(T("set.appearance"), None, self.seg_theme),
            self._row(T("set.language"), None, self.seg_lang),
        ]))

        group("set.conversion")
        self.sw_sound = Switch(st.play_sound, self.ctx.set_sound)
        v.addWidget(self._list_card([self._row(T("set.sound"), T("set.sound.desc"), self.sw_sound)]))

        group("set.updates")
        self.check_btn = btn(T("set.check.now"), "primary", self.check_updates)
        self.check_row = self._row(T("set.check"), "", self.check_btn)
        self.sw_auto = Switch(st.auto_check_updates, self.ctx.set_auto_check)
        v.addWidget(self._list_card([self.check_row,
                                     self._row(T("set.autoCheck"), T("set.autoCheck.desc"), self.sw_auto)]))

        v.addLayout(hrow(btn(T("set.resetAll"), "ghost", self.reset_all),
                         btn(T("set.quit"), "danger", self.ctx.quit), stretch_at=1))
        v.addStretch(1)
        return scroll_page(page)

    def refresh_settings(self) -> None:
        from .settings import launch_at_login
        self.sw_login.blockSignals(True)
        self.sw_login.setChecked(launch_at_login())
        self.sw_login.blockSignals(False)
        st = self.ctx.settings
        detail = T("set.check.version", updater.current())
        if st.last_update_check:
            detail += " · " + T("set.check.last", i18n.ago(st.last_update_check))
        self.check_row.detail.setText(self.check_message or detail)

    def check_updates(self) -> None:
        self.check_btn.setEnabled(False)
        self.check_message = T("set.check.checking")
        self.refresh_settings()

        def done(result: str) -> None:
            self.check_message = T({"found": "set.check.found", "none": "set.check.upToDate"}.get(result, "set.check.failed"))
            self.refresh_settings()
            self.check_btn.setEnabled(True)
            self.check_message = None
            self.refresh_home()

        self.ctx.check_updates(user=True, done=done)

    def reset_all(self) -> None:
        if self.confirm(T("set.resetAll.confirm"), T("set.resetAll.confirmDesc")):
            self.ctx.reset_all()

    # ================= عن حوّل =================

    def _page_about(self) -> QScrollArea:
        page = QWidget()
        v = QVBoxLayout(page)
        v.setContentsMargins(22, 4, 22, 18)
        v.setSpacing(12)

        top, tl = card()
        texts = vbox(lbl("Hawwel · حوّل", "heroTitle"), lbl(T("about.version", updater.current()), "hint"),
                     lbl(T("about.desc"), None, True), spacing=2)
        tl.addLayout(hrow(logo_box(72, "logoBoxBig"), texts, spacing=16))
        v.addWidget(top)

        log, ll = card()
        ll.addLayout(hrow(lbl(T("about.newIn", updater.current()), "title"),
                          Pill("info", T("badge.new"), dot=False), stretch_at=1))
        for i in range(1, 6):
            item = lbl("•  " + T(f"about.log.{i}"), "hint", True)
            item.setStyleSheet("font-size: 12px;")
            ll.addWidget(item)
        v.addWidget(log)

        grid = QGridLayout()
        grid.setSpacing(8)
        self.link_buttons = []
        for i, key in enumerate(("website", "source", "bug", "feature")):
            b = btn(T(f"about.link.{key}"), "link", lambda _=False, u=LINKS[key]: system.open_url(u))
            b.setToolTip(LINKS[key])
            b.setLayoutDirection(self.layoutDirection())
            grid.addWidget(b, i // 2, i % 2)
            self.link_buttons.append(b)
        v.addLayout(grid)
        share = lbl(T("about.share"), "hint")
        share.setAlignment(Qt.AlignCenter)
        v.addWidget(share)
        v.addStretch(1)
        return scroll_page(page)

    # ================= عام =================

    def refresh_all(self) -> None:
        ok = self.ctx.shortcut_ok()
        self.state.setProperty("cls", "state-ok" if ok else "state-warn")
        kind = "ok" if ok else "warn"
        for w in (self.state_dot, self.state_text):
            w.setProperty("pill", kind)
            repolish(w)
        self.state_dot.setStyleSheet("font-size: 8px;")
        text = T("side.running", shortcuts.describe(self.ctx.settings.shortcut)) if ok else T("side.needsPermission")
        self.state_text.setText(text)
        self.state.setToolTip(text)
        repolish(self.state)
        self.refresh_shortcuts()
        self.refresh_home()
        self.refresh_try()
        self.refresh_stats()
        self.refresh_settings()

    def apply_colors(self) -> None:
        """بعد تغيير الثيم: الأيقونات والحاجات المرسومة"""
        self.refresh_icons()
        for b in self.social_buttons:
            b.setIcon(icons.icon(b.property("iconName"), C["muted"], 16))
        for b in self.link_buttons:
            b.setIcon(icons.icon("ext", C["muted"], 12))
        for seg in (self.seg_theme,):
            for oid, b in seg.buttons.items():
                name = {"light": "sun", "dark": "moon", "system": "monitor"}[oid]
                b.setIcon(icons.icon(name, C["ink"] if b.isChecked() else C["muted"], 13))
        self.refresh_stats()
        self.update()

    def confirm(self, title: str, body: str) -> bool:
        box = QMessageBox(self)
        box.setWindowTitle(title)
        box.setText(title)
        box.setInformativeText(body)
        box.setIcon(QMessageBox.Warning)
        box.setStandardButtons(QMessageBox.Ok | QMessageBox.Cancel)
        box.setDefaultButton(QMessageBox.Cancel)
        return box.exec() == QMessageBox.Ok

    def closeEvent(self, ev):
        # قفل النافذة = إخفاء: البرنامج يفضل شغّال علشان الاختصار
        self.stop_recording()
        if not self.ctx.quitting:
            ev.ignore()
            self.hide()
        else:
            super().closeEvent(ev)

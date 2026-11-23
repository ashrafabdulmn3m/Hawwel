"""ألوان تصميم Hawwel 2.0 (فاتح/داكن/زي النظام) والـ stylesheet بتاع Qt."""

from __future__ import annotations

PALETTE = {
    #               فاتح        داكن
    "bg":          ("#F3F5F9", "#131829"),
    "side":        ("#E8ECF4", "#0E1222"),
    "card":        ("#FFFFFF", "#1B2237"),
    "line":        ("#DCE2EC", "#29324D"),
    "ink":         ("#141B2D", "#ECEFF7"),
    "muted":       ("#66708A", "#8C95B0"),
    "accent":      ("#2F86E4", "#5B9CF0"),
    "accentHover": ("#2577D2", "#74ACF3"),
    "accentSoft":  ("#E2EDFC", "#1D3150"),
    "accentMid":   ("#B5D2F4", "#2C4A75"),
    "ok":          ("#2E9D57", "#5BC27E"),
    "okSoft":      ("#E0F3E6", "#163222"),
    "warn":        ("#B8770C", "#E3AC40"),
    "warnSoft":    ("#FBF0DC", "#3A2D12"),
    "warnLine":    ("#E9CF9E", "#5A4419"),
    "field":       ("#F6F8FB", "#0D1121"),
    "key":         ("#F4F6FA", "#232B45"),
    "danger":      ("#D9534F", "#F07470"),
    "hover":       ("#E9ECF2", "#222A41"),
    "switchOff":   ("#CDD2DC", "#3A4360"),
    "soonBg":      ("#EAECF0", "#252C40"),
}

FONT_FAMILIES = ["Noto Sans", "Noto Sans Arabic", "Ubuntu", "Cantarell", "Inter", "DejaVu Sans", "sans-serif"]


def colors(dark: bool) -> dict[str, str]:
    return {k: v[1 if dark else 0] for k, v in PALETTE.items()}


def stylesheet(c: dict[str, str]) -> str:
    return f"""
* {{ color: {c['ink']}; font-size: 13px; }}
QWidget#Root, QWidget#Main, QScrollArea, QScrollArea > QWidget > QWidget {{ background: {c['bg']}; border: none; }}
QFrame#Side {{ background: {c['side']}; }}
QFrame#Foot {{ background: {c['side']}; border-top: 1px solid {c['line']}; }}
QFrame#VLine {{ background: {c['line']}; }}

QLabel {{ background: transparent; }}
QLabel[cls="h1"] {{ font-size: 18px; font-weight: 700; }}
QLabel[cls="sub"] {{ font-size: 12px; color: {c['muted']}; }}
QLabel[cls="title"] {{ font-size: 13px; font-weight: 600; }}
QLabel[cls="rowTitle"] {{ font-size: 13px; font-weight: 500; }}
QLabel[cls="heroTitle"] {{ font-size: 15px; font-weight: 600; }}
QLabel[cls="hint"] {{ font-size: 11.5px; color: {c['muted']}; }}
QLabel[cls="group"] {{ font-size: 11px; font-weight: 600; color: {c['muted']}; }}
QLabel[cls="stat"] {{ font-size: 24px; font-weight: 700; }}
QLabel[cls="brand"] {{ font-size: 15px; font-weight: 700; }}
QLabel[cls="small"] {{ font-size: 11px; color: {c['muted']}; }}
QLabel[cls="code"] {{ font-family: monospace; font-size: 12px; background: {c['field']};
                      border: 1px solid {c['line']}; border-radius: 6px; padding: 6px 8px; }}
QLabel[cls="foot"] {{ font-size: 11.5px; color: {c['muted']}; }}

QFrame[cls="card"] {{ background: {c['card']}; border: 1px solid {c['line']}; border-radius: 12px; }}
QFrame[cls="cardWarn"] {{ background: {c['warnSoft']}; border: 1px solid {c['warnLine']}; border-radius: 12px; }}
QFrame[cls="cardSoft"] {{ background: {c['accentSoft']}; border: none; border-radius: 12px; }}
QFrame[cls="hero"] {{ border: 1px solid {c['line']}; border-radius: 12px;
    background: qlineargradient(x1:0, y1:0, x2:0.7, y2:1, stop:0 {c['accentSoft']}, stop:1 {c['card']}); }}
QFrame[cls="recording"] {{ background: {c['accentSoft']}; border: 1.5px dashed {c['accent']}; border-radius: 12px; }}
QFrame[cls="divider"] {{ background: {c['line']}; border: none; }}

QFrame[cls="pill-ok"] {{ background: {c['okSoft']}; border-radius: 10px; }}
QFrame[cls="pill-warn"] {{ background: {c['warnSoft']}; border-radius: 10px; }}
QFrame[cls="pill-info"] {{ background: {c['accentSoft']}; border-radius: 10px; }}
QFrame[cls="pill-soon"] {{ background: {c['soonBg']}; border-radius: 10px; }}
QLabel[pill="ok"] {{ color: {c['ok']}; font-size: 11.5px; font-weight: 600; }}
QLabel[pill="warn"] {{ color: {c['warn']}; font-size: 11.5px; font-weight: 600; }}
QLabel[pill="info"] {{ color: {c['accent']}; font-size: 11.5px; font-weight: 600; }}
QLabel[pill="soon"] {{ color: {c['muted']}; font-size: 11.5px; font-weight: 600; }}
QFrame[cls="state-ok"] {{ background: {c['okSoft']}; border-radius: 8px; }}
QFrame[cls="state-warn"] {{ background: {c['warnSoft']}; border-radius: 8px; }}

QLabel[cls="key"] {{ background: {c['key']}; border: 1px solid {c['line']}; border-bottom: 3px solid {c['line']};
                     border-radius: 7px; font-weight: 600; font-size: 14px; padding: 0 9px; min-width: 16px; }}
QLabel[cls="key"][keySize="large"] {{ font-size: 17px; border-radius: 9px; }}
QLabel[cls="key"][keySize="small"] {{ font-size: 11.5px; border-radius: 5px; border-bottom-width: 2px; padding: 0 6px; min-width: 12px; }}
QLabel[cls="key"][lit="true"] {{ background: {c['accent']}; color: white; border-color: {c['accent']}; }}
QLabel[cls="plus"] {{ color: {c['muted']}; font-size: 12px; }}

QPushButton {{ border: 1px solid {c['line']}; background: {c['card']}; border-radius: 8px;
               padding: 6px 12px; font-size: 12.5px; font-weight: 500; }}
QPushButton:hover {{ background: {c['hover']}; }}
QPushButton:disabled {{ color: {c['muted']}; }}
QPushButton[cls="primary"] {{ background: {c['accent']}; border-color: {c['accent']}; color: white; }}
QPushButton[cls="primary"]:hover {{ background: {c['accentHover']}; }}
QPushButton[cls="ghost"] {{ background: transparent; border-color: transparent; }}
QPushButton[cls="ghost"]:hover {{ background: {c['hover']}; }}
QPushButton[cls="danger"] {{ color: {c['danger']}; }}
QPushButton[cls="icon"], QPushButton[cls="social"] {{ background: transparent; border: none; border-radius: 7px; padding: 0; }}
QPushButton[cls="icon"]:hover, QPushButton[cls="social"]:hover {{ background: {c['hover']}; }}
QPushButton[cls="nav"] {{ background: transparent; border: none; border-radius: 8px; padding: 8px 10px;
                          color: {c['muted']}; font-weight: 500; text-align: left; }}
QPushButton[cls="nav"]:hover {{ background: {c['hover']}; color: {c['ink']}; }}
QPushButton[cls="nav"]:checked {{ background: {c['accentSoft']}; color: {c['accent']}; }}
QPushButton[cls="link"] {{ border-radius: 9px; padding: 9px 12px; text-align: left; }}
QPushButton[cls="link"]:hover {{ border-color: {c['accent']}; color: {c['accent']}; background: {c['card']}; }}

QFrame[cls="seg"] {{ background: {c['field']}; border: 1px solid {c['line']}; border-radius: 8px; }}
QPushButton[cls="segBtn"] {{ background: transparent; border: none; border-radius: 6px; padding: 4px 10px;
                             color: {c['muted']}; font-size: 12px; }}
QPushButton[cls="segBtn"]:hover {{ color: {c['ink']}; }}
QPushButton[cls="segBtn"]:checked {{ background: {c['card']}; color: {c['ink']}; font-weight: 500; }}

QPlainTextEdit {{ background: {c['field']}; border: 1px solid {c['line']}; border-radius: 9px;
                  padding: 4px 6px; font-size: 14px; selection-background-color: {c['accent']}; selection-color: white; }}
QPlainTextEdit:focus {{ border-color: {c['accent']}; }}
QPlainTextEdit[flash="true"] {{ border-color: {c['ok']}; }}

QFrame[cls="step"] {{ background: {c['field']}; border: 1px solid {c['line']}; border-radius: 11px; }}
QFrame[cls="stepDone"] {{ background: {c['okSoft']}; border: 1px solid {c['okSoft']}; border-radius: 11px; }}
QLabel[cls="stepNum"] {{ background: {c['card']}; border: 1px solid {c['line']}; border-radius: 9px;
                         color: {c['muted']}; font-size: 10.5px; font-weight: 600; }}
QLabel[cls="stepNumDone"] {{ background: {c['ok']}; border: 1px solid {c['ok']}; border-radius: 9px;
                             color: white; font-size: 10.5px; font-weight: 600; }}
QLabel[cls="stepText"] {{ color: {c['muted']}; font-size: 11.5px; }}
QLabel[cls="stepTextDone"] {{ color: {c['ok']}; font-size: 11.5px; }}
QFrame[cls="logoBox"] {{ background: white; border: 1px solid {c['line']}; border-radius: 10px; }}
QFrame[cls="logoBoxBig"] {{ background: white; border: 1px solid {c['line']}; border-radius: 16px; }}

QScrollBar:vertical {{ background: transparent; width: 10px; margin: 2px; }}
QScrollBar::handle:vertical {{ background: {c['switchOff']}; border-radius: 3px; min-height: 30px; }}
QScrollBar::add-line, QScrollBar::sub-line, QScrollBar::add-page, QScrollBar::sub-page {{ height: 0; background: none; }}
QToolTip {{ background: {c['card']}; color: {c['ink']}; border: 1px solid {c['line']}; padding: 4px 6px; }}
QMenu {{ background: {c['card']}; border: 1px solid {c['line']}; padding: 4px; }}
QMenu::item {{ padding: 6px 18px; border-radius: 6px; }}
QMenu::item:selected {{ background: {c['accentSoft']}; color: {c['accent']}; }}
"""

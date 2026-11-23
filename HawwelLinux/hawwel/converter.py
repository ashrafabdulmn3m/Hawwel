"""
تحويل الكلام بين كيبورد US والكيبورد العربي (Arabic 101 / كيبورد "ara" في لينكس).

على الماك والويندوز الجدول بيتبني من الكيبورد المتسطّب، لكن في لينكس كل ديسكتوب
بيتعامل مع الكيبوردات بطريقة مختلفة، فالجدول هنا ثابت ومطابق لكيبورد Arabic (101).
"""

from __future__ import annotations

# (إنجليزي, عربي) — من غير Shift
_PLAIN = list(zip(
    "`qwertyuiop[]asdfghjkl;'zxcvnm,./",
    "ذضصثقفغعهخحجدشسيبلاتنمكطئءؤرىةوزظ",
)) + [("b", "لا")]

# (إنجليزي, عربي) — مع Shift
_SHIFT = [
    ("~", "ّ"), ("Q", "َ"), ("W", "ً"), ("E", "ُ"), ("R", "ٌ"), ("T", "لإ"), ("Y", "إ"),
    ("U", "‘"), ("I", "÷"), ("O", "×"), ("P", "؛"), ("{", "<"), ("}", ">"),
    ("A", "ِ"), ("S", "ٍ"), ("D", "]"), ("F", "["), ("G", "لأ"), ("H", "أ"), ("J", "ـ"),
    ("K", "،"), ("L", "/"), ("Z", "~"), ("X", "ْ"), ("C", "}"), ("V", "{"), ("B", "لآ"),
    ("N", "آ"), ("M", "’"), ("?", "؟"),
]

EN_TO_AR: dict[str, str] = {}
AR_TO_EN: dict[str, str] = {}
for en, ar in _PLAIN + _SHIFT:
    EN_TO_AR[en] = ar
    AR_TO_EN.setdefault(ar, en)  # لو حرف عربي جاي من مفتاحين، نفضّل اللي من غير Shift


def is_to_arabic(text: str) -> bool:
    """النص هيتحوّل لعربي؟ (لو أغلب حروفه لاتيني)"""
    latin = sum(1 for c in text if c.isascii() and c.isalpha())
    arabic = sum(1 for c in text if "؀" <= c <= "ۿ")
    return latin > arabic


def _fix_caps(text: str) -> str:
    """لو كل الحروف كبيرة (غالباً Caps Lock كان شغّال)، نصغّرها علشان ما تتحوّلش كأنها Shift."""
    letters = [c for c in text if c.isascii() and c.isalpha()]
    if len(letters) >= 2 and all(c.isupper() for c in letters):
        return "".join(c.lower() if c.isascii() and c.isalpha() else c for c in text)
    return text


def _map(text: str, table: dict[str, str]) -> str:
    out = []
    i = 0
    while i < len(text):
        two = text[i:i + 2]
        if len(two) == 2 and two in table:  # "لا" و"لأ" و"لإ" و"لآ"
            out.append(table[two])
            i += 2
            continue
        out.append(table.get(text[i], text[i]))
        i += 1
    return "".join(out)


def convert(text: str) -> str:
    """يحوّل النص تلقائياً حسب الاتجاه."""
    if is_to_arabic(text):
        return _map(_fix_caps(text), EN_TO_AR)
    return _map(text, AR_TO_EN)

using System.Text;

namespace Hawwel;

/// <summary>
/// بيبني جدول تحويل بين كيبورد US وأي كيبورد عربي مثبّت من تخطيطات ويندوز نفسها
/// (نفس فكرة نسخة الماك اللي بتستخدم UCKeyTranslate)، وبعدين يحوّل النص تلقائياً حسب الاتجاه.
/// </summary>
public sealed class LayoutConverter
{
    private const string UsKlid = "00000409";
    private const string ArabicKlid = "00000401"; // Arabic (101): احتياطي لو مفيش كيبورد عربي مثبّت
    private const uint LangArabic = 0x01;         // اللغة الأساسية: عربي (مصر، السعودية، ...)

    private readonly Dictionary<string, string> _enToAr = new();
    private readonly Dictionary<string, string> _arToEn = new();

    private LayoutConverter() { }

    /// <summary>أول كيبورد عربي مثبّت عند المستخدم (أي نوع: 101 أو 102 أو غيره، ولأي دولة عربية).</summary>
    private static IntPtr FindInstalledArabic()
    {
        foreach (var h in Native.InstalledLayouts())
        {
            uint langId = (uint)((long)h & 0xFFFF);   // الـ LANGID في الجزء الواطي من الـ HKL
            if ((langId & 0x3FF) == LangArabic) return h;
        }
        return IntPtr.Zero;
    }

    /// <summary>بيرجع null لو الكيبوردين مش متاحين.</summary>
    public static LayoutConverter? TryCreate()
    {
        var en = Native.LoadKeyboardLayout(UsKlid, Native.KLF_NOACTIVATE);
        var ar = FindInstalledArabic();
        if (ar == IntPtr.Zero) ar = Native.LoadKeyboardLayout(ArabicKlid, Native.KLF_NOACTIVATE); // احتياطي
        if (en == IntPtr.Zero || ar == IntPtr.Zero) return null;

        var c = new LayoutConverter();
        foreach (uint scan in ScanCodes())
        {
            foreach (bool shift in new[] { false, true })
            {
                var e = CharFor(scan, shift, en);
                var a = CharFor(scan, shift, ar);
                if (e == null || a == null) continue;
                c._enToAr[e] = a;
                c._arToEn[a] = e;
            }
        }
        return c._enToAr.Count > 0 ? c : null;
    }

    /// <summary>الصف الرقمي + الصفوف التلاتة بتوع الحروف (من غير Enter/Tab/Space).</summary>
    private static IEnumerable<uint> ScanCodes()
    {
        for (uint s = 0x02; s <= 0x0D; s++) yield return s; // 1 ... = 
        for (uint s = 0x10; s <= 0x1B; s++) yield return s; // Q ... ]
        for (uint s = 0x1E; s <= 0x29; s++) yield return s; // A ... ` 
        for (uint s = 0x2B; s <= 0x35; s++) yield return s; // \ Z ... /
    }

    private static string? CharFor(uint scan, bool shift, IntPtr hkl)
    {
        uint vk = Native.VkFromScan(scan, hkl);
        if (vk == 0) return null;

        var state = new byte[256];
        if (shift) state[Native.VK_SHIFT] = 0x80;

        var sb = new StringBuilder(8);
        // flags = 4: ما يغيّرش حالة الـ dead keys (Windows 10 1607+)
        int n = Native.ToUnicodeEx(vk, scan, state, sb, sb.Capacity, 4, hkl);
        if (n <= 0) return null; // 0 = مفيش حرف، سالب = dead key
        var s = sb.ToString(0, Math.Min(n, sb.Length));
        return s.All(ch => ch >= 32) ? s : null;
    }

    /// <summary>يحوّل النص تلقائياً: لو أغلبه لاتيني → عربي، وإلا → إنجليزي.</summary>
    public string Convert(string text)
    {
        int latin = text.Count(ch => ch < 128 && char.IsLetter(ch));
        int arabic = text.Count(ch => ch >= 0x0600 && ch <= 0x06FF);
        return Map(text, latin > arabic ? _enToAr : _arToEn);
    }

    private static string Map(string text, Dictionary<string, string> table)
    {
        var sb = new StringBuilder(text.Length);
        int i = 0;
        while (i < text.Length)
        {
            // نجرب حرفين الأول (علشان "لا")
            if (i + 1 < text.Length && table.TryGetValue(text.Substring(i, 2), out var two))
            { sb.Append(two); i += 2; continue; }

            var one = text[i].ToString();
            sb.Append(table.TryGetValue(one, out var m) ? m : one);
            i++;
        }
        return sb.ToString();
    }
}

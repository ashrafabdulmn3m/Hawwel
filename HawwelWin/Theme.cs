using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using Microsoft.Win32;

namespace Hawwel;

/// <summary>الوضع النهاري/الليلي/التلقائي: بنبدّل ألوان الـ resources وقت التشغيل (DynamicResource).</summary>
public static class Theme
{
    public const string Light = "light", Dark = "dark", Auto = "auto";

    private static Settings _settings = null!;
    public static string Mode { get; private set; } = Auto;
    public static bool IsDark { get; private set; }

    // (نهاري, ليلي)
    private static readonly Dictionary<string, (string L, string D)> Palette = new()
    {
        ["Accent"]          = ("#1E88E5", "#3D9CF5"),
        ["AccentHover"]     = ("#1976D2", "#5AAEF7"),
        ["AccentSoft"]      = ("#E3F1FD", "#1A3350"),
        ["AccentSoftHover"] = ("#D1E7FB", "#21406A"),
        ["AccentText"]      = ("#1E88E5", "#5DB1F7"),
        ["Ink"]             = ("#171C2E", "#EDF0F8"),
        ["Muted"]           = ("#5F6B85", "#9AA4BE"),
        ["Bg"]              = ("#F3F5FA", "#0F1422"),
        ["Card"]            = ("#FFFFFF", "#1A2036"),
        ["CardBorder"]      = ("#E8ECF4", "#262E48"),
        ["Divider"]         = ("#ECEFF5", "#262E48"),
        ["Field"]           = ("#FAFBFE", "#0F1422"),
        ["FieldBorder"]     = ("#C9D1E3", "#2F3858"),
        ["Placeholder"]     = ("#8B94AB", "#6F7A96"),
        ["SwitchOff"]       = ("#C7CEDC", "#3A4360"),
        ["OutlineBg"]       = ("#FFFFFF", "#1A2036"),
        ["OutlineBorder"]   = ("#D5DBE8", "#323B5A"),
        ["OutlineHover"]    = ("#F3F5FA", "#232B45"),
        ["ChipBg"]          = ("#F4F7FC", "#232B45"),
        ["ChipBorder"]      = ("#C9D3E6", "#313A58"),
        ["UpdateBg"]        = ("#E8F3FD", "#16294A"),
        ["UpdateBorder"]    = ("#BBDDFB", "#25477A"),
        ["ProgressTrack"]   = ("#CFE3F8", "#25354F"),
        ["SegBg"]           = ("#EAEFF8", "#0F1422"),
        ["Warn"]            = ("#B45309", "#FBBF24"),
        ["PillOkBg"]        = ("#E2F3E7", "#14382A"),
        ["PillOkDot"]       = ("#2EA44F", "#34D26B"),
        ["PillOkText"]      = ("#1B7F3B", "#4ADE80"),
        ["PillWarnBg"]      = ("#FFF3DC", "#3A2C10"),
        ["PillWarnDot"]     = ("#F59E0B", "#FBBF24"),
        ["PillWarnText"]    = ("#9A6200", "#FCD34D"),
        ["PillIdleBg"]      = ("#EAEFF8", "#232B45"),
        ["PillIdleDot"]     = ("#8A94AB", "#8A94AB"),
        ["PillIdleText"]    = ("#3B4660", "#B8C1D9"),
    };

    public static void Init(Settings settings)
    {
        _settings = settings;
        Mode = Normalize(settings.Theme);
        // لما المستخدم يغيّر وضع ويندوز والتطبيق على "تلقائي"
        SystemEvents.UserPreferenceChanged += (_, _) =>
        {
            if (Mode == Auto)
                Application.Current.Dispatcher.BeginInvoke(new Action(Apply));
        };
        Apply();
    }

    public static void Set(string mode)
    {
        Mode = Normalize(mode);
        _settings.Theme = Mode;
        _settings.Save();
        Apply();
    }

    private static string Normalize(string? m) => m is Light or Dark ? m : Auto;

    private static bool SystemUsesDark()
    {
        try
        {
            using var k = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            return k?.GetValue("AppsUseLightTheme") is int v && v == 0;
        }
        catch { return false; }
    }

    private static void Apply()
    {
        IsDark = Mode == Dark || (Mode == Auto && SystemUsesDark());
        var res = Application.Current.Resources;
        foreach (var (key, c) in Palette)
        {
            var color = (Color)ColorConverter.ConvertFromString(IsDark ? c.D : c.L);
            res[key] = new SolidColorBrush(color); // استبدال الـ brush => كل DynamicResource بيتحدّث
        }
        foreach (Window w in Application.Current.Windows) ApplyTitleBar(w);
    }

    /// <summary>شريط عنوان النافذة غامق/فاتح (ويندوز 10 1903+ و 11).</summary>
    public static void ApplyTitleBar(Window w)
    {
        var h = new WindowInteropHelper(w).Handle;
        if (h == IntPtr.Zero) return;
        int on = IsDark ? 1 : 0;
        if (DwmSetWindowAttribute(h, 20, ref on, sizeof(int)) != 0)
            DwmSetWindowAttribute(h, 19, ref on, sizeof(int));
    }

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
}

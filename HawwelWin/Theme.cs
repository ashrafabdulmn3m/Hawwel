using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using Microsoft.Win32;

namespace Hawwel;

/// <summary>المظهر: فاتح / داكن / زي النظام. بنبدّل ألوان الـ resources وقت التشغيل (DynamicResource).</summary>
public static class Theme
{
    public const string Light = "light", Dark = "dark", System = "system";

    private static Settings _settings = null!;
    public static string Mode { get; private set; } = System;
    public static bool IsDark { get; private set; }
    public static event Action? Changed;

    // ألوان تصميم Hawwel 2.0 (فاتح, داكن)
    private static readonly Dictionary<string, (string L, string D)> Palette = new()
    {
        ["Bg"]         = ("#F3F5F9", "#131829"),
        ["Side"]       = ("#E8ECF4", "#0E1222"),
        ["Card"]       = ("#FFFFFF", "#1B2237"),
        ["Line"]       = ("#DCE2EC", "#29324D"),
        ["Ink"]        = ("#141B2D", "#ECEFF7"),
        ["Muted"]      = ("#66708A", "#8C95B0"),
        ["Accent"]     = ("#2F86E4", "#5B9CF0"),
        ["AccentHover"]= ("#2577D2", "#74ACF3"),
        ["AccentSoft"] = ("#E2EDFC", "#1D3150"),
        ["Ok"]         = ("#2E9D57", "#5BC27E"),
        ["OkSoft"]     = ("#E0F3E6", "#163222"),
        ["Warn"]       = ("#B8770C", "#E3AC40"),
        ["WarnSoft"]   = ("#FBF0DC", "#3A2D12"),
        ["WarnLine"]   = ("#E9CF9E", "#5A4419"),
        ["Field"]      = ("#F6F8FB", "#0D1121"),
        ["Key"]        = ("#F4F6FA", "#232B45"),
        ["KeyShadow"]  = ("#D3D8E2", "#141A2C"),
        ["Danger"]     = ("#D9534F", "#F07470"),
        ["Hover"]      = ("#E9ECF2", "#222A41"),
        ["SwitchOff"]  = ("#CDD2DC", "#3A4360"),
        ["SoonBg"]     = ("#EAECF0", "#252C40"),
        ["AccentMid"]  = ("#B5D2F4", "#2C4A75"),   // الأعمدة اللي مش النهارده
    };

    public static void Init(Settings settings)
    {
        _settings = settings;
        Mode = Normalize(settings.Theme);
        // لما المستخدم يغيّر وضع ويندوز والتطبيق على "زي النظام"
        SystemEvents.UserPreferenceChanged += (_, _) =>
        {
            if (Mode == System)
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

    private static string Normalize(string? m) => m is Light or Dark ? m : System;

    private static bool SystemUsesDark()
    {
        try
        {
            using var k = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            return k?.GetValue("AppsUseLightTheme") is int v && v == 0;
        }
        catch { return false; }
    }

    public static void Apply()
    {
        IsDark = Mode == Dark || (Mode == System && SystemUsesDark());
        var res = Application.Current.Resources;
        foreach (var (key, c) in Palette)
        {
            var color = (Color)ColorConverter.ConvertFromString(IsDark ? c.D : c.L);
            var brush = new SolidColorBrush(color);
            brush.Freeze();
            res[key] = brush; // استبدال الـ brush => كل DynamicResource بيتحدّث
        }
        foreach (Window w in Application.Current.Windows) ApplyTitleBar(w);
        Changed?.Invoke();
    }

    /// <summary>شريط عنوان النافذة غامق/فاتح (ويندوز 10 1903+ و 11).</summary>
    public static void ApplyTitleBar(Window w)
    {
        var h = new WindowInteropHelper(w).Handle;
        if (h == IntPtr.Zero) return;
        int on = IsDark ? 1 : 0;
        if (DwmSetWindowAttribute(h, 20, ref on, sizeof(int)) != 0)
            DwmSetWindowAttribute(h, 19, ref on, sizeof(int));
        // لون شريط العنوان نفس لون السايدبار (ويندوز 11، وويندوز 10 بيتجاهله)
        var bg = (Color)ColorConverter.ConvertFromString(IsDark ? Palette["Side"].D : Palette["Side"].L);
        int colorRef = bg.R | (bg.G << 8) | (bg.B << 16);
        DwmSetWindowAttribute(h, 35, ref colorRef, sizeof(int));
    }

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
}

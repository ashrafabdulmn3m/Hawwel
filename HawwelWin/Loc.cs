using System.ComponentModel;
using System.Globalization;
using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Data;
using System.Windows.Markup;

namespace Hawwel;

/// <summary>
/// نصوص الواجهة بالعربي والإنجليزي (Strings.json). لغة الواجهة مستقلة عن لغة ويندوز.
/// في XAML: Text="{h:L tab.home}"، وفي الكود: Loc.T("tab.home").
/// لما اللغة تتغيّر كل النصوص المربوطة بتتحدّث لوحدها.
/// </summary>
public sealed class Loc : INotifyPropertyChanged
{
    public static Loc I { get; } = new();

    private readonly Dictionary<string, Dictionary<string, string>> _strings;
    private string _lang = "ar";

    private Loc()
    {
        using var s = typeof(Loc).Assembly.GetManifestResourceStream("Hawwel.Strings.json");
        _strings = s == null ? new() :
            JsonSerializer.Deserialize<Dictionary<string, Dictionary<string, string>>>(s) ?? new();
    }

    public string Lang
    {
        get => _lang;
        set
        {
            var v = value == "en" ? "en" : "ar";
            if (v == _lang) return;
            _lang = v;
            PropertyChanged?.Invoke(this, new(Binding.IndexerName)); // كل [key]
            PropertyChanged?.Invoke(this, new(nameof(Lang)));
            PropertyChanged?.Invoke(this, new(nameof(FlowDirection)));
            LanguageChanged?.Invoke();
        }
    }

    public bool IsArabic => _lang == "ar";
    public FlowDirection FlowDirection => IsArabic ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;

    /// <summary>علشان الحاجات اللي بتتبني في الكود (الرسم، المنيو) تتبني تاني</summary>
    public event Action? LanguageChanged;
    public event PropertyChangedEventHandler? PropertyChanged;

    public string this[string key] =>
        _strings.TryGetValue(key, out var v) && v.TryGetValue(_lang, out var s) ? s : key;

    public static string T(string key) => I[key];
    public static string F(string key, params object[] args) =>
        string.Format(CultureInfo.InvariantCulture, I[key], args);

    /// <summary>أول مرة: اللي كان بيستخدم Hawwel قبل كده يفضل عربي، والجديد ياخد لغة ويندوز.</summary>
    public static string DefaultLanguage(bool usedBefore) =>
        usedBefore || CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "ar" ? "ar" : "en";
}

/// <summary>{h:L key}: ربط بنص مترجم بيتحدّث مع تغيير اللغة.</summary>
[MarkupExtensionReturnType(typeof(object))]
public sealed class L : MarkupExtension
{
    public L() { }
    public L(string key) { Key = key; }
    public string Key { get; set; } = "";

    public override object ProvideValue(IServiceProvider sp) =>
        new Binding($"[{Key}]") { Source = Loc.I, Mode = BindingMode.OneWay }.ProvideValue(sp);
}

/// <summary>الأرقام دايماً بالأرقام الإنجليزية (1,284) في اللغتين، زي التصميم.</summary>
public static class Num
{
    private static readonly CultureInfo En = CultureInfo.GetCultureInfo("en-US");

    public static string Grouped(int n) => n.ToString("N0", En);

    /// <summary>486 / 1.2K / 52K</summary>
    public static string Compact(int n) => n switch
    {
        < 1000 => n.ToString(En),
        < 10_000 => (Math.Round(n / 100.0) / 10).ToString("0.#", En) + "K",
        < 1_000_000 => (n / 1000).ToString(En) + "K",
        _ => (n / 1_000_000.0).ToString("0.#", En) + "M",
    };

    /// <summary>الوقت اللي اتوفر: الحروف ÷ 200 حرف في الدقيقة</summary>
    public static string TimeSaved(int chars)
    {
        if (chars == 0) return "0";
        double minutes = chars / Stats.CharsPerMinute;
        if (minutes < 1) return Loc.T("time.lessThanMin");
        if (minutes < 60) return Loc.F("time.min", (int)Math.Round(minutes));
        double hours = minutes / 60;
        return Loc.F("time.hour", hours < 10 ? hours.ToString("0.0", En) : Math.Round(hours).ToString(En));
    }

    /// <summary>"من ساعتين" / "2 h ago"</summary>
    public static string Ago(DateTime when)
    {
        var d = DateTime.Now - when;
        if (d.TotalMinutes < 1) return Loc.T("time.ago.now");
        if (d.TotalHours < 1) return Loc.F("time.ago.min", (int)d.TotalMinutes);
        if (d.TotalDays < 1) return Loc.F("time.ago.hour", (int)d.TotalHours);
        return Loc.F("time.ago.day", (int)d.TotalDays);
    }
}

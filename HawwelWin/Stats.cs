using System.IO;
using System.Text.Json;

namespace Hawwel;

/// <summary>
/// إحصائيات التحويل. بتتحفظ على الجهاز بس (%AppData%\Hawwel\stats.json)،
/// وما فيهاش الكلام نفسه: عدد مرات وعدد حروف واتجاه واسم البرنامج بس.
/// </summary>
public sealed class Stats
{
    public sealed class StatsData
    {
        public int Total { get; set; }
        public int Chars { get; set; }
        public int ToArabic { get; set; }
        public int ToEnglish { get; set; }
        public Dictionary<string, int> Days { get; set; } = new();      // "2026-11-22": 12
        public Dictionary<string, int> DayChars { get; set; } = new();
        public Dictionary<string, int> Apps { get; set; } = new();      // "WhatsApp": 31
    }

    /// <summary>تقدير الوقت اللي اتوفر: الحروف ÷ 200 حرف في الدقيقة</summary>
    public const double CharsPerMinute = 200;

    public StatsData Data { get; private set; } = new();
    public event Action? Changed;

    private static string FilePath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Hawwel", "stats.json");

    private static string Key(DateTime d) => d.ToString("yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture);

    public static Stats Load()
    {
        var s = new Stats();
        try
        {
            if (File.Exists(FilePath))
                s.Data = JsonSerializer.Deserialize<StatsData>(File.ReadAllText(FilePath)) ?? new();
        }
        catch { /* ملف تالف: نبدأ من الأول */ }
        return s;
    }

    public void Record(int chars, bool toArabic, string? app)
    {
        var day = Key(DateTime.Now);
        Data.Total++;
        Data.Chars += chars;
        if (toArabic) Data.ToArabic++; else Data.ToEnglish++;
        Data.Days[day] = Data.Days.GetValueOrDefault(day) + 1;
        Data.DayChars[day] = Data.DayChars.GetValueOrDefault(day) + chars;
        if (!string.IsNullOrWhiteSpace(app)) Data.Apps[app] = Data.Apps.GetValueOrDefault(app) + 1;
        Prune();
        Save();
        Changed?.Invoke();
    }

    public void Clear()
    {
        Data = new();
        Save();
        Changed?.Invoke();
    }

    // ---- أرقام جاهزة للعرض ----

    public int TodayCount => Data.Days.GetValueOrDefault(Key(DateTime.Now));
    public int TodayChars => Data.DayChars.GetValueOrDefault(Key(DateTime.Now));

    /// <summary>آخر 7 أيام (الأقدم الأول، والنهارده آخر واحد)</summary>
    public List<(DateTime Date, int Count)> Last7()
    {
        var today = DateTime.Today;
        return Enumerable.Range(0, 7).Reverse()
            .Select(back => { var d = today.AddDays(-back); return (d, Data.Days.GetValueOrDefault(Key(d))); })
            .ToList();
    }

    public int WeekCount => Last7().Sum(x => x.Count);

    /// <summary>النسبة اللي اتحوّلت لعربي (0..1)، أو null لو مفيش تحويلات</summary>
    public double? ToArabicShare
    {
        get
        {
            int all = Data.ToArabic + Data.ToEnglish;
            return all == 0 ? null : (double)Data.ToArabic / all;
        }
    }

    /// <summary>أكتر 3 برامج ونسبة كل واحد</summary>
    public List<(string Name, double Share)> TopApps()
    {
        int all = Data.Apps.Values.Sum();
        if (all == 0) return new();
        return Data.Apps.OrderByDescending(a => a.Value).Take(3)
            .Select(a => (a.Key, (double)a.Value / all)).ToList();
    }

    /// <summary>بنحتفظ بآخر 400 يوم بس علشان الملف ما يكبرش</summary>
    private void Prune()
    {
        if (Data.Days.Count <= 400) return;
        var keep = Data.Days.Keys.OrderBy(k => k).TakeLast(400).ToHashSet();
        Data.Days = Data.Days.Where(k => keep.Contains(k.Key)).ToDictionary(k => k.Key, k => k.Value);
        Data.DayChars = Data.DayChars.Where(k => keep.Contains(k.Key)).ToDictionary(k => k.Key, k => k.Value);
    }

    private void Save()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
            File.WriteAllText(FilePath, JsonSerializer.Serialize(Data));
        }
        catch { }
    }
}

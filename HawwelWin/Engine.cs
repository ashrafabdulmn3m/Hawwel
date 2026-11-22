using System.ComponentModel;
using System.IO;
using System.Runtime.CompilerServices;
using System.Windows;

namespace Hawwel;

public enum EngineStatus { Ready, Converted, NoSelection, NoKeyboard, ConsoleApp, Error }

/// <summary>
/// نفس منطق Engine.swift: ينسخ التحديد → يحوّله → يلصقه → يرجّع الـ clipboard القديم.
/// لو مفيش كلام محدد: ما بيعملش حاجة وبيقول للمستخدم يحدد الأول.
/// </summary>
public sealed class Engine : INotifyPropertyChanged
{
    private EngineStatus _status = EngineStatus.Ready;
    public EngineStatus Status { get => _status; private set { _status = value; OnChanged(); } }
    public string LastError { get; private set; } = "";

    /// <summary>بعد كل ضغطة اختصار (نجح ولا لأ) — كارت "جرّب هنا" بيستخدمه</summary>
    public event Action<bool>? Finished;

    private readonly Stats _stats;
    private readonly Settings _settings;
    private bool _busy;

    public Engine(Stats stats, Settings settings)
    {
        _stats = stats;
        _settings = settings;
    }

    // برامج الـ Console: Ctrl+C فيها معناها "إيقاف البرنامج" مش "نسخ"، فمش هنبعتها.
    private static readonly HashSet<string> ConsoleApps = new(StringComparer.OrdinalIgnoreCase)
        { "cmd", "powershell", "pwsh", "WindowsTerminal", "conhost", "wt", "OpenConsole" };

    // برامج Adobe: نكتب النص بدل اللصق (زي نسخة الماك).
    private static readonly string[] AdobePrefixes =
        { "Adobe", "Photoshop", "Illustrator", "InDesign", "AfterFX", "Premiere", "Animate" };

    public async void Run() => await RunAsync();

    private async Task RunAsync()
    {
        if (_busy) return;
        _busy = true;
        EngineStatus result = EngineStatus.Error;
        try
        {
            // بنبنيه كل مرة (سريع) علشان لو المستخدم ضاف كيبورد والبرنامج شغّال
            var converter = LayoutConverter.TryCreate();
            if (converter == null) { result = EngineStatus.NoKeyboard; return; }

            var app = Native.ForegroundProcessName();
            if (app != null && ConsoleApps.Contains(app)) { result = EngineStatus.ConsoleApp; return; }
            bool practice = string.Equals(app, System.Diagnostics.Process.GetCurrentProcess().ProcessName,
                                          StringComparison.OrdinalIgnoreCase); // كارت "جرّب هنا"

            await WaitForKeysReleased();

            var saved = Snapshot();
            var text = await CopySelection();
            if (text == null)
            {
                Restore(saved);
                result = EngineStatus.NoSelection;
                return;
            }

            bool toArabic = LayoutConverter.IsToArabic(text);
            await Replace(converter.Convert(text), saved, app);
            result = EngineStatus.Converted;

            if (!practice) _stats.Record(text.Length, toArabic, AppDisplayName(app));
            if (_settings.PlaySound) ConvertSound.Play();
            if (_settings.SwitchKeyboard) Native.SwitchLayout(toArabic ? converter.ArabicLayout : converter.EnglishLayout);
        }
        catch (Exception ex)
        {
            LastError = ex.Message;
            result = EngineStatus.Error;
        }
        finally
        {
            _busy = false;
            Status = result;
            Finished?.Invoke(result == EngineStatus.Converted);
        }
    }

    /// <summary>اسم البرنامج زي ما بيظهر للمستخدم (WhatsApp بدل whatsapp.exe)</summary>
    private static string? AppDisplayName(string? process)
    {
        if (string.IsNullOrEmpty(process)) return null;
        try
        {
            var p = System.Diagnostics.Process.GetProcessesByName(process).FirstOrDefault();
            var desc = p?.MainModule?.FileVersionInfo.FileDescription;
            if (!string.IsNullOrWhiteSpace(desc)) return desc;
        }
        catch { }
        return char.ToUpperInvariant(process[0]) + process[1..];
    }

    /// <summary>ننتظر المستخدم يرفع إيده من الاختصار علشان ما يتخلطش مع Ctrl+C اللي هنبعتها.</summary>
    private static async Task WaitForKeysReleased()
    {
        ushort[] keys = { Native.VK_CONTROL, Native.VK_MENU, Native.VK_SHIFT, Native.VK_LWIN, Native.VK_RWIN };
        for (int i = 0; i < 60 && keys.Any(k => Native.IsDown(k)); i++) await Task.Delay(15);
        await Task.Delay(150);
    }

    private static async Task<string?> CopySelection()
    {
        uint before = Native.GetClipboardSequenceNumber();
        Native.Press(Native.VK_C, Native.VK_CONTROL);

        for (int i = 0; i < 20; i++) // لحد ~300ms
        {
            await Task.Delay(15);
            if (Native.GetClipboardSequenceNumber() != before)
            {
                var t = Retry(() => Clipboard.ContainsText() ? Clipboard.GetText() : null);
                return string.IsNullOrEmpty(t) ? null : t;
            }
        }
        return null;
    }

    private async Task Replace(string text, DataObject? saved, string? app)
    {
        bool adobe = app != null && AdobePrefixes.Any(p => app.StartsWith(p, StringComparison.OrdinalIgnoreCase));

        if (adobe)
        {
            Restore(saved);
            await Task.Delay(100);
            Native.TypeText(text);
            return;
        }

        var data = new DataObject();
        data.SetText(text);
        // نخلّي ويندوز ما يحطّش النص المؤقت ده في Clipboard history
        try { data.SetData("ExcludeClipboardContentFromMonitorProcessing", new MemoryStream(new byte[4])); } catch { }
        Retry(() => { Clipboard.SetDataObject(data, true); return true; });

        await Task.Delay(50);
        Native.Press(Native.VK_V, Native.VK_CONTROL);

        await Task.Delay(400);
        Restore(saved);
    }

    // ---- Clipboard snapshot / restore ----

    private static DataObject? Snapshot()
    {
        try
        {
            var src = Retry(() => Clipboard.GetDataObject());
            if (src == null) return null;
            var copy = new DataObject();
            foreach (var f in src.GetFormats(false))
            {
                try
                {
                    var d = src.GetData(f, false);
                    if (d == null) continue;
                    if (d is MemoryStream ms) { var c = new MemoryStream(); ms.Position = 0; ms.CopyTo(c); ms.Position = 0; d = c; }
                    copy.SetData(f, d, false);
                }
                catch { }
            }
            return copy;
        }
        catch { return null; }
    }

    private static void Restore(DataObject? saved)
    {
        try
        {
            if (saved == null || saved.GetFormats(false).Length == 0) Retry(() => { Clipboard.Clear(); return true; });
            else Retry(() => { Clipboard.SetDataObject(saved, true); return true; });
        }
        catch { }
    }

    /// <summary>الـ clipboard ممكن يكون مشغول من برنامج تاني لحظياً.</summary>
    private static T? Retry<T>(Func<T> action)
    {
        for (int i = 0; i < 10; i++)
        {
            try { return action(); }
            catch (System.Runtime.InteropServices.COMException) { Thread.Sleep(20); }
        }
        return default;
    }

    public event PropertyChangedEventHandler? PropertyChanged;
    private void OnChanged([CallerMemberName] string? n = null) => PropertyChanged?.Invoke(this, new(n));
}

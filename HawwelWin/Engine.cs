using System.ComponentModel;
using System.IO;
using System.Runtime.CompilerServices;
using System.Windows;

namespace Hawwel;

/// <summary>
/// نفس منطق Engine.swift: ينسخ التحديد (أو آخر كلمة) → يحوّله → يلصقه → يرجّع الـ clipboard القديم.
/// </summary>
public sealed class Engine : INotifyPropertyChanged
{
    private string _status = "جاهز";
    public string Status { get => _status; set { _status = value; OnChanged(); } }

    private LayoutConverter? _converter;
    private bool _busy;

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
        try
        {
            _converter ??= LayoutConverter.TryCreate();
            if (_converter == null) { Status = "⚠️ مش لاقي كيبورد عربي أو انجليزي، ضيفه من إعدادات اللغة في ويندوز"; return; }

            var app = Native.ForegroundProcessName();
            if (app != null && ConsoleApps.Contains(app))
            {
                Status = "⚠️ مش مدعوم في الـ Terminal (Ctrl+C بيوقف البرنامج)";
                return;
            }

            await WaitForKeysReleased();

            var saved = Snapshot();

            var text = await CopySelection();
            if (text == null)
            {
                // مفيش تحديد: حدد آخر كلمة (Ctrl+Shift+←)
                Native.Press(Native.VK_LEFT, Native.VK_CONTROL, Native.VK_SHIFT);
                await Task.Delay(100);
                text = await CopySelection();
                if (text == null)
                {
                    Status = "مفيش نص محدد";
                    Restore(saved);
                    return;
                }
            }

            await Replace(_converter.Convert(text), saved, app);
        }
        catch (Exception ex)
        {
            Status = "⚠️ حصل خطأ: " + ex.Message;
        }
        finally { _busy = false; }
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
        string preview = text.Length > 30 ? text[..30] : text;

        if (adobe)
        {
            Restore(saved);
            await Task.Delay(100);
            Native.TypeText(text);
            Status = "✅ اتحول: " + preview;
            return;
        }

        var data = new DataObject();
        data.SetText(text);
        // نخلّي ويندوز ما يحطّش النص المؤقت ده في Clipboard history
        try { data.SetData("ExcludeClipboardContentFromMonitorProcessing", new MemoryStream(new byte[4])); } catch { }
        Retry(() => { Clipboard.SetDataObject(data, true); return true; });

        await Task.Delay(50);
        Native.Press(Native.VK_V, Native.VK_CONTROL);
        Status = "✅ اتحول: " + preview;

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

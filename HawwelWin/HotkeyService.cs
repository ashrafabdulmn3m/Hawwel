using System.Windows.Input;
using System.Windows.Interop;

namespace Hawwel;

/// <summary>اختصار عام (RegisterHotKey) على نافذة مخفية مالهاش علاقة بالنافذة الرئيسية.</summary>
public sealed class HotkeyService : IDisposable
{
    private const int HotkeyId = 0x4857; // "HW"
    private readonly HwndSource _source;
    private bool _registered;

    public event Action? Pressed;

    public HotkeyService()
    {
        // message-only window (HWND_MESSAGE = -3)
        var p = new HwndSourceParameters("HawwelHotkey") { ParentWindow = new IntPtr(-3), Width = 0, Height = 0 };
        _source = new HwndSource(p);
        _source.AddHook(WndProc);
    }

    /// <summary>بيسجل الاختصار؛ بيرجع false لو مشغول من برنامج تاني.</summary>
    public bool Register(uint modifiers, uint vk)
    {
        Unregister();
        _registered = Native.RegisterHotKey(_source.Handle, HotkeyId, modifiers | Native.MOD_NOREPEAT, vk);
        return _registered;
    }

    public void Unregister()
    {
        if (_registered) Native.UnregisterHotKey(_source.Handle, HotkeyId);
        _registered = false;
    }

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == Native.WM_HOTKEY && wParam.ToInt32() == HotkeyId)
        {
            Pressed?.Invoke();
            handled = true;
        }
        return IntPtr.Zero;
    }

    public void Dispose()
    {
        Unregister();
        _source.Dispose();
    }

    /// <summary>نص مقروء للاختصار، مثلاً "Ctrl + Alt + K".</summary>
    public static string Describe(uint modifiers, uint vk)
    {
        var parts = new List<string>();
        if ((modifiers & Native.MOD_CONTROL) != 0) parts.Add("Ctrl");
        if ((modifiers & Native.MOD_ALT) != 0) parts.Add("Alt");
        if ((modifiers & Native.MOD_SHIFT) != 0) parts.Add("Shift");
        if ((modifiers & Native.MOD_WIN) != 0) parts.Add("Win");
        var key = KeyInterop.KeyFromVirtualKey((int)vk);
        var name = key.ToString();
        if (name.Length == 2 && name[0] == 'D' && char.IsDigit(name[1])) name = name[1].ToString();
        parts.Add(name);
        return string.Join(" + ", parts);
    }
}

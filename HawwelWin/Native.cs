using System.Runtime.InteropServices;

namespace Hawwel;

/// <summary>استدعاءات Win32 اللي محتاجينها.</summary>
internal static class Native
{
    public const int WM_HOTKEY = 0x0312;
    public const uint MOD_ALT = 0x0001, MOD_CONTROL = 0x0002, MOD_SHIFT = 0x0004, MOD_WIN = 0x0008, MOD_NOREPEAT = 0x4000;

    public const ushort VK_SHIFT = 0x10, VK_CONTROL = 0x11, VK_MENU = 0x12, VK_LWIN = 0x5B, VK_RWIN = 0x5C;
    public const ushort VK_C = 0x43, VK_V = 0x56, VK_LEFT = 0x25, VK_RETURN = 0x0D;

    private const uint INPUT_KEYBOARD = 1;
    private const uint KEYEVENTF_EXTENDEDKEY = 0x0001, KEYEVENTF_KEYUP = 0x0002, KEYEVENTF_UNICODE = 0x0004;
    public const uint KLF_NOACTIVATE = 0x0001;
    private const uint MAPVK_VSC_TO_VK_EX = 3;

    [DllImport("user32.dll")] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] public static extern uint GetClipboardSequenceNumber();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr LoadKeyboardLayout(string klid, uint flags);
    [DllImport("user32.dll")] public static extern uint MapVirtualKeyEx(uint code, uint mapType, IntPtr hkl);
    [DllImport("user32.dll")]
    public static extern int ToUnicodeEx(uint vk, uint scanCode, byte[] keyState,
        [Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder buf,
        int bufSize, uint flags, IntPtr hkl);
    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint n, INPUT[] inputs, int size);

    public static uint VkFromScan(uint scan, IntPtr hkl) => MapVirtualKeyEx(scan, MAPVK_VSC_TO_VK_EX, hkl);

    public static bool IsDown(int vk) => (GetAsyncKeyState(vk) & 0x8000) != 0;

    public static string? ForegroundProcessName()
    {
        try
        {
            GetWindowThreadProcessId(GetForegroundWindow(), out var pid);
            using var p = System.Diagnostics.Process.GetProcessById((int)pid);
            return p.ProcessName;
        }
        catch { return null; }
    }

    // ---- SendInput ----

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT { public ushort wVk, wScan; public uint dwFlags, time; public IntPtr dwExtraInfo; }

    [StructLayout(LayoutKind.Sequential)]
    private struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr dwExtraInfo; }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion
    {
        [FieldOffset(0)] public MOUSEINPUT mi;   // يضمن الحجم الصحيح للـ union على x86 و x64
        [FieldOffset(0)] public KEYBDINPUT ki;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT { public uint type; public InputUnion u; }

    private static INPUT Key(ushort vk, ushort scan, uint flags) => new()
    {
        type = INPUT_KEYBOARD,
        u = new InputUnion { ki = new KEYBDINPUT { wVk = vk, wScan = scan, dwFlags = flags } }
    };

    private static void Send(List<INPUT> list) =>
        SendInput((uint)list.Count, list.ToArray(), Marshal.SizeOf<INPUT>());

    private static uint Ext(ushort vk) => vk == VK_LEFT ? KEYEVENTF_EXTENDEDKEY : 0;

    /// <summary>يضغط مفتاح مع مفاتيح تعديل (Ctrl/Shift/Alt) كلها في دفعة واحدة.</summary>
    public static void Press(ushort key, params ushort[] modifiers)
    {
        var list = new List<INPUT>();
        foreach (var m in modifiers) list.Add(Key(m, 0, 0));
        list.Add(Key(key, 0, Ext(key)));
        list.Add(Key(key, 0, Ext(key) | KEYEVENTF_KEYUP));
        foreach (var m in modifiers.Reverse()) list.Add(Key(m, 0, KEYEVENTF_KEYUP));
        Send(list);
    }

    /// <summary>يكتب النص حرف حرف (Unicode) بدل اللصق — للبرامج اللي مش بتحب Ctrl+V.</summary>
    public static void TypeText(string text)
    {
        var list = new List<INPUT>();
        for (int i = 0; i < text.Length; i++)
        {
            char c = text[i];
            if (c == '\r') { if (i + 1 < text.Length && text[i + 1] == '\n') continue; }
            if (c == '\r' || c == '\n')
            {
                list.Add(Key(VK_RETURN, 0, 0));
                list.Add(Key(VK_RETURN, 0, KEYEVENTF_KEYUP));
                continue;
            }
            list.Add(Key(0, c, KEYEVENTF_UNICODE));
            list.Add(Key(0, c, KEYEVENTF_UNICODE | KEYEVENTF_KEYUP));
        }
        // على دفعات صغيرة زي نسخة الماك (20 حرف)
        for (int i = 0; i < list.Count; i += 40)
            Send(list.GetRange(i, Math.Min(40, list.Count - i)));
    }
}

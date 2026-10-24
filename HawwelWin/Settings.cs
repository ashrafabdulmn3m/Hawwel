using System.IO;
using System.Text.Json;
using Microsoft.Win32;

namespace Hawwel;

/// <summary>الإعدادات في %AppData%\Hawwel\settings.json (بديل UserDefaults/AppStorage).</summary>
public sealed class Settings
{
    // الافتراضي Ctrl+Alt+K (Ctrl+K لوحدها بتتعارض مع "إدراج رابط" في Word والمتصفحات)
    public uint HotkeyModifiers { get; set; } = Native.MOD_CONTROL | Native.MOD_ALT;
    public uint HotkeyVk { get; set; } = 0x4B; // K
    public bool ShowTray { get; set; } = true;
    public bool HasLaunchedBefore { get; set; }

    private static string FilePath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Hawwel", "settings.json");

    public static Settings Load()
    {
        try
        {
            if (File.Exists(FilePath))
                return JsonSerializer.Deserialize<Settings>(File.ReadAllText(FilePath)) ?? new Settings();
        }
        catch { /* ملف تالف: نرجع للافتراضي */ }
        return new Settings();
    }

    public void Save()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
            File.WriteAllText(FilePath, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch { }
    }

    // ---- التشغيل مع بداية ويندوز (بديل SMAppService) ----
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string RunName = "Hawwel";

    public static bool LaunchAtLogin
    {
        get
        {
            using var k = Registry.CurrentUser.OpenSubKey(RunKey);
            return k?.GetValue(RunName) is string;
        }
    }

    public static void SetLaunchAtLogin(bool on)
    {
        using var k = Registry.CurrentUser.CreateSubKey(RunKey);
        if (on) k.SetValue(RunName, $"\"{Environment.ProcessPath}\"");
        else k.DeleteValue(RunName, false);
    }
}

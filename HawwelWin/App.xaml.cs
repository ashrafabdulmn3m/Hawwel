using System.Drawing;
using System.Windows;
using Forms = System.Windows.Forms;

namespace Hawwel;

public partial class App : Application
{
    public static new App Current => (App)Application.Current;

    public Settings Settings { get; private set; } = null!;
    public Engine Engine { get; private set; } = null!;
    public bool Quitting { get; private set; }

    private HotkeyService _hotkey = null!;
    private Forms.NotifyIcon _tray = null!;
    private MainWindow _window = null!;
    private Mutex? _mutex;
    private EventWaitHandle? _showEvent;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // نسخة واحدة بس. لو اتفتح تاني نطلّع النافذة بتاعة الأولى (زي applicationShouldHandleReopen)
        _mutex = new Mutex(true, @"Local\Hawwel.SingleInstance", out bool first);
        _showEvent = new EventWaitHandle(false, EventResetMode.AutoReset, @"Local\Hawwel.Show");
        if (!first)
        {
            _showEvent.Set();
            Shutdown();
            return;
        }
        new Thread(() =>
        {
            while (_showEvent.WaitOne())
            {
                if (Quitting) break;
                Dispatcher.BeginInvoke(new Action(ShowWindow));
            }
        }) { IsBackground = true }.Start();

        Settings = Settings.Load();
        Engine = new Engine();

        _hotkey = new HotkeyService();
        _hotkey.Pressed += Engine.Run;
        if (!_hotkey.Register(Settings.HotkeyModifiers, Settings.HotkeyVk))
            Engine.Status = "⚠️ الاختصار مشغول من برنامج تاني، غيّره من هنا";

        BuildTray();
        _window = new MainWindow();

        bool firstRun = !Settings.HasLaunchedBefore;
        Settings.HasLaunchedBefore = true;
        Settings.Save();

        // مش أول مرة والـ tray شغّال: نفضل مخفيين في الـ tray
        if (firstRun || !Settings.ShowTray) ShowWindow();
    }

    // ---- النافذة ----

    public void ShowWindow()
    {
        _window.RefreshControls();
        if (!_window.IsVisible) _window.Show();
        if (_window.WindowState == WindowState.Minimized) _window.WindowState = WindowState.Normal;
        _window.Activate();
        _window.Topmost = true;  // نجيبها قدّام
        _window.Topmost = false;
        _window.Focus();
    }

    // ---- الاختصار ----

    public bool TrySetHotkey(uint modifiers, uint vk)
    {
        if (_hotkey.Register(modifiers, vk))
        {
            Settings.HotkeyModifiers = modifiers;
            Settings.HotkeyVk = vk;
            Settings.Save();
            return true;
        }
        _hotkey.Register(Settings.HotkeyModifiers, Settings.HotkeyVk); // نرجّع القديم
        return false;
    }

    public void PauseHotkey() => _hotkey.Unregister();
    public void ResumeHotkey() => _hotkey.Register(Settings.HotkeyModifiers, Settings.HotkeyVk);

    // ---- System Tray (بديل MenuBarExtra) ----

    private void BuildTray()
    {
        var menu = new Forms.ContextMenuStrip { RightToLeft = Forms.RightToLeft.Yes };
        menu.Items.Add("حوّل النص المحدد", null, async (_, _) =>
        {
            await Task.Delay(350); // نسيب الفوكس يرجع للبرنامج اللي كنت فيه
            Engine.Run();
        });
        menu.Items.Add("فتح Hawwel", null, (_, _) => ShowWindow());
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add("خروج", null, (_, _) => Quit());

        var iconStream = GetResourceStream(new Uri("pack://application:,,,/Assets/hawwel.ico")).Stream;
        _tray = new Forms.NotifyIcon
        {
            Icon = new Icon(iconStream),
            Text = "Hawwel - حوّل",
            ContextMenuStrip = menu,
            Visible = Settings.ShowTray
        };
        _tray.MouseClick += (_, ev) => { if (ev.Button == Forms.MouseButtons.Left) ShowWindow(); };
    }

    public void SetTrayVisible(bool visible)
    {
        Settings.ShowTray = visible;
        Settings.Save();
        _tray.Visible = visible;
    }

    public void Quit()
    {
        Quitting = true;
        _tray.Visible = false;
        _tray.Dispose();
        _hotkey.Dispose();
        _showEvent?.Set(); // يفكّ الـ thread المستني
        Shutdown();
    }
}

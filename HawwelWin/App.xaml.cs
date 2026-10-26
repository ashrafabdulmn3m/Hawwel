using System.Drawing;
using System.Windows;
using System.Windows.Threading;
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
    private DispatcherTimer? _updateTimer;

    /// <summary>الإصدار الأحدث لو موجود، وإلا null.</summary>
    public UpdateInfo? PendingUpdate { get; private set; }
    public event Action? UpdateChanged;

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

        StartUpdateChecks();
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

    // ---- التحديثات ----

    private async void StartUpdateChecks()
    {
        _updateTimer = new DispatcherTimer { Interval = TimeSpan.FromHours(12) };
        _updateTimer.Tick += async (_, _) => { if (Settings.AutoCheckUpdates) await CheckForUpdateAsync(false); };
        _updateTimer.Start();

        await Task.Delay(TimeSpan.FromSeconds(8)); // نسيب التطبيق يفتح الأول
        if (Settings.AutoCheckUpdates) await CheckForUpdateAsync(false);
    }

    public async Task<UpdateCheckResult> CheckForUpdateAsync(bool userInitiated)
    {
        try
        {
            var info = await Updater.CheckAsync();
            PendingUpdate = info;
            UpdateChanged?.Invoke();
            if (info == null) return UpdateCheckResult.UpToDate;

            // إشعار مرة واحدة بس لكل إصدار (إلا لو المستخدم هو اللي طلب الفحص)
            var v = info.Version.ToString();
            if (!userInitiated && Settings.LastNotifiedUpdate != v)
            {
                Settings.LastNotifiedUpdate = v;
                Settings.Save();
                if (Settings.ShowTray)
                    _tray.ShowBalloonTip(10000, "Hawwel", $"إصدار جديد ({v}) متاح. افتح Hawwel واضغط تحديث.", Forms.ToolTipIcon.Info);
            }
            return UpdateCheckResult.Available;
        }
        catch
        {
            return UpdateCheckResult.Failed; // مفيش نت أو GitHub مش متاح: ما نزعجش المستخدم
        }
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
        _tray.BalloonTipClicked += (_, _) => ShowWindow();
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

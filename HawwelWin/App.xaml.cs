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
    public Stats Stats { get; private set; } = null!;
    /// <summary>الاختصار متسجّل؟ (false لو برنامج تاني واخده)</summary>
    public bool HotkeyOk { get; private set; }
    public event Action? HotkeyChanged;
    /// <summary>الـ installer لو اتنزّل في الخلفية (نزّل وثبّت تلقائياً)</summary>
    public string? DownloadedInstaller { get; private set; }
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
        if (string.IsNullOrEmpty(Settings.Language))
        {
            Settings.Language = Loc.DefaultLanguage(Settings.HasLaunchedBefore);
            Settings.Save();
        }
        Loc.I.Lang = Settings.Language;
        Theme.Init(Settings); // لازم قبل ما النافذة تتعمل
        Stats = Stats.Load();
        Engine = new Engine(Stats, Settings);

        _hotkey = new HotkeyService();
        _hotkey.Pressed += Engine.Run;
        HotkeyOk = _hotkey.Register(Settings.HotkeyModifiers, Settings.HotkeyVk);

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
            Settings.LastUpdateCheck = DateTime.Now;
            Settings.Save();
            if (info?.Version != PendingUpdate?.Version) DownloadedInstaller = null;
            PendingUpdate = info;
            UpdateChanged?.Invoke();
            if (info == null) return UpdateCheckResult.UpToDate;

            // نزّل وثبّت تلقائياً: بننزّله في الخلفية، والمستخدم يختار امتى يعيد التشغيل
            if (Settings.AutoInstallUpdates && DownloadedInstaller == null)
            {
                try
                {
                    DownloadedInstaller = await Updater.DownloadAsync(info);
                    UpdateChanged?.Invoke();
                }
                catch { /* هيتنزّل لما يدوس "حدّث دلوقتي" */ }
            }

            // إشعار مرة واحدة بس لكل إصدار (إلا لو المستخدم هو اللي طلب الفحص)
            var v = info.Version.ToString();
            if (!userInitiated && Settings.LastNotifiedUpdate != v)
            {
                Settings.LastNotifiedUpdate = v;
                Settings.Save();
                if (Settings.ShowTray)
                    _tray.ShowBalloonTip(10000, "Hawwel", Loc.F("tray.balloon", v), Forms.ToolTipIcon.Info);
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
            SetHotkeyOk(true);
            return true;
        }
        SetHotkeyOk(_hotkey.Register(Settings.HotkeyModifiers, Settings.HotkeyVk)); // نرجّع القديم
        return false;
    }

    public void PauseHotkey() => _hotkey.Unregister();
    public void ResumeHotkey() => SetHotkeyOk(_hotkey.Register(Settings.HotkeyModifiers, Settings.HotkeyVk));

    private void SetHotkeyOk(bool ok)
    {
        if (ok == HotkeyOk) return;
        HotkeyOk = ok;
        HotkeyChanged?.Invoke();
    }

    /// <summary>بعد "رجّع كل الإعدادات"</summary>
    public void ApplySettingsAfterReset()
    {
        SetHotkeyOk(_hotkey.Register(Settings.HotkeyModifiers, Settings.HotkeyVk));
        SetTrayVisible(Settings.ShowTray);
    }

    // ---- System Tray (بديل MenuBarExtra) ----

    private void BuildTray()
    {
        var iconStream = GetResourceStream(new Uri("pack://application:,,,/Assets/tray.ico")).Stream;
        // لوجو Hawwel المختصر (ح + P) بالأزرق؛ الملف فيه كذا مقاس، ونختار المقاس اللي الـ tray محتاجه
        _tray = new Forms.NotifyIcon
        {
            Icon = new Icon(iconStream, Forms.SystemInformation.SmallIconSize),
            Visible = Settings.ShowTray
        };
        BuildTrayMenu();
        Loc.I.LanguageChanged += BuildTrayMenu;
        _tray.BalloonTipClicked += (_, _) => ShowWindow();
        _tray.MouseClick += (_, ev) => { if (ev.Button == Forms.MouseButtons.Left) ShowWindow(); };
    }

    /// <summary>منيو الـ tray بلغة الواجهة</summary>
    private void BuildTrayMenu()
    {
        var menu = new Forms.ContextMenuStrip
        {
            RightToLeft = Loc.I.IsArabic ? Forms.RightToLeft.Yes : Forms.RightToLeft.No
        };
        menu.Items.Add(Loc.T("menu.convert"), null, async (_, _) =>
        {
            await Task.Delay(350); // نسيب الفوكس يرجع للبرنامج اللي كنت فيه
            Engine.Run();
        });
        menu.Items.Add(Loc.T("menu.open"), null, (_, _) => ShowWindow());
        menu.Items.Add(Loc.T("menu.update"), null, async (_, _) =>
        {
            ShowWindow();
            await CheckForUpdateAsync(userInitiated: true);
        });
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add(Loc.T("menu.quit"), null, (_, _) => Quit());
        var old = _tray.ContextMenuStrip;
        _tray.ContextMenuStrip = menu;
        old?.Dispose();
        _tray.Text = Loc.T("tray.tooltip");
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

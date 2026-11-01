using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;

namespace Hawwel;

public partial class MainWindow : Window
{
    private bool _recording;

    public MainWindow()
    {
        InitializeComponent();
        LoadLogo();
        SourceInitialized += (_, _) => Theme.ApplyTitleBar(this);
        MaxHeight = SystemParameters.WorkArea.Height - 20; // الشاشات الصغيرة: النافذة تتمرّر بدل ما تتقص
        DataContext = App.Current.Engine;
        RefreshControls();
        ApplyStatus();
        App.Current.UpdateChanged += RefreshUpdateUi;
        App.Current.Engine.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(Engine.Status)) ApplyStatus();
        };
    }

    // ---- شكل "جاهز ●" حسب حالة الـ Engine ----

    private void ApplyStatus()
    {
        var raw = App.Current.Engine.Status ?? "";
        bool warn = raw.StartsWith("\u26A0");
        bool ok = raw.StartsWith("\u2705") || raw.StartsWith("جاهز");
        StatusText.Text = raw.TrimStart('\u26A0', '\u2705', '\uFE0F', ' ');
        StatusPill.ToolTip = StatusText.Text;

        // SetResourceReference: الألوان بتتبدّل لوحدها لما الوضع (نهاري/ليلي) يتغيّر
        var k = warn ? "PillWarn" : ok ? "PillOk" : "PillIdle";
        StatusPill.SetResourceReference(Border.BackgroundProperty, k + "Bg");
        StatusDot.SetResourceReference(System.Windows.Shapes.Shape.FillProperty, k + "Dot");
        StatusText.SetResourceReference(TextBlock.ForegroundProperty, k + "Text");
    }

    // اللوجو: logo.png، ولو مش موجود في الـ Resources نرجع لأيقونة التطبيق بدل ما يبان فاضي
    private void LoadLogo()
    {
        foreach (var name in new[] { "logo.png", "hawwel.ico" })
        {
            try
            {
                var bmp = new System.Windows.Media.Imaging.BitmapImage();
                bmp.BeginInit();
                bmp.UriSource = new Uri($"pack://application:,,,/Assets/{name}");
                bmp.CacheOption = System.Windows.Media.Imaging.BitmapCacheOption.OnLoad;
                bmp.EndInit();
                LogoImage.Source = bmp;
                return;
            }
            catch { }
        }
    }

    private void Theme_Click(object sender, RoutedEventArgs e) =>
        Theme.Set((string)((RadioButton)sender).Tag);

    private void TestBox_TextChanged(object sender, TextChangedEventArgs e) =>
        TestPlaceholder.Visibility = string.IsNullOrEmpty(TestBox.Text) ? Visibility.Visible : Visibility.Collapsed;

    private bool _updating;

    public void RefreshControls()
    {
        var s = App.Current.Settings;
        // "Ctrl + Alt + K" -> ["Ctrl", "+", "Alt", "+", "K"] علشان كل جزء يظهر ككابسة
        var keys = new List<string>();
        foreach (var part in HotkeyService.Describe(s.HotkeyModifiers, s.HotkeyVk).Split(" + "))
        {
            if (keys.Count > 0) keys.Add("+");
            keys.Add(part);
        }
        HotkeyKeys.ItemsSource = keys;
        ThemeLight.IsChecked = Theme.Mode == Theme.Light;
        ThemeDark.IsChecked = Theme.Mode == Theme.Dark;
        ThemeAuto.IsChecked = Theme.Mode == Theme.Auto;
        LaunchCheck.IsChecked = Settings.LaunchAtLogin;
        TrayCheck.IsChecked = s.ShowTray;
        AutoUpdateCheck.IsChecked = s.AutoCheckUpdates;
        VersionText.Text = "v" + Updater.Current;
        RefreshUpdateUi();
    }

    // ---- التحديثات ----

    private void RefreshUpdateUi()
    {
        if (_updating) return; // ما نغيّرش الرسالة وإحنا بننزّل
        var u = App.Current.PendingUpdate;
        if (u == null) { UpdateCard.Visibility = Visibility.Collapsed; return; }
        UpdateTitle.Text = $"إصدار جديد متاح: {u.Version} (إنت على {Updater.Current})";
        UpdateMsg.Text = "هيتنزّل ويتثبّت فوق القديم، ومش محتاج تمسح حاجة. Hawwel هيتقفل ويفتح تاني لوحده.";
        UpdateCard.Visibility = Visibility.Visible;
    }

    private async void Update_Click(object sender, RoutedEventArgs e)
    {
        var info = App.Current.PendingUpdate;
        if (info == null) return;

        _updating = true;
        UpdateBtn.IsEnabled = false;
        UpdateProgress.Value = 0;
        UpdateProgress.Visibility = Visibility.Visible;
        UpdateMsg.Text = "بنزّل التحديث...";
        try
        {
            var progress = new Progress<double>(p => UpdateProgress.Value = p * 100);
            var path = await Updater.DownloadAsync(info, progress);
            UpdateMsg.Text = "بنثبّت التحديث... Hawwel هيتقفل ويفتح تاني.";
            Updater.LaunchInstaller(path);
            App.Current.Quit();
        }
        catch (Exception ex)
        {
            _updating = false;
            UpdateProgress.Visibility = Visibility.Collapsed;
            UpdateBtn.IsEnabled = true;
            UpdateMsg.Text = "⚠️ فشل التحديث: " + ex.Message;
        }
    }

    private async void Check_Click(object sender, RoutedEventArgs e)
    {
        CheckBtn.IsEnabled = false;
        CheckMsg.Text = "بدوّر...";
        var r = await App.Current.CheckForUpdateAsync(userInitiated: true);
        CheckMsg.Text = r switch
        {
            UpdateCheckResult.Available => "فيه إصدار جديد، شوف الكارت اللي فوق.",
            UpdateCheckResult.UpToDate => "إنت على آخر إصدار ✅",
            _ => "⚠️ معرفتش أوصل لـ GitHub، اتأكد من النت وجرّب تاني."
        };
        CheckBtn.IsEnabled = true;
    }

    // ---- تسجيل اختصار جديد ----

    private void Record_Click(object sender, RoutedEventArgs e)
    {
        _recording = true;
        RecordBtn.Content = "اضغط الاختصار…";
        ShowHotkeyMessage("اضغط الاختصار الجديد على الكيبورد، أو Esc للإلغاء.", warning: false);
        App.Current.PauseHotkey(); // علشان الاختصار الحالي ما يشتغلش وإحنا بنسجّل
        Focus();
    }

    private void EndRecording()
    {
        _recording = false;
        RecordBtn.Content = "غيّر الاختصار";
        HotkeyMsg.Visibility = Visibility.Collapsed;
    }

    private void Window_PreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (!_recording) return;
        e.Handled = true;

        var key = e.Key == Key.System ? e.SystemKey : e.Key;
        if (key is Key.LeftCtrl or Key.RightCtrl or Key.LeftAlt or Key.RightAlt or Key.LeftShift
            or Key.RightShift or Key.LWin or Key.RWin or Key.ImeProcessed or Key.DeadCharProcessed)
            return; // لسه بيضغط على مفاتيح التعديل

        if (key == Key.Escape)
        {
            EndRecording();
            App.Current.ResumeHotkey();
            return;
        }

        uint mods = 0;
        var m = Keyboard.Modifiers;
        if (m.HasFlag(ModifierKeys.Control)) mods |= Native.MOD_CONTROL;
        if (m.HasFlag(ModifierKeys.Alt)) mods |= Native.MOD_ALT;
        if (m.HasFlag(ModifierKeys.Shift)) mods |= Native.MOD_SHIFT;
        if (m.HasFlag(ModifierKeys.Windows)) mods |= Native.MOD_WIN;

        if (mods == 0)
        {
            ShowHotkeyMessage("لازم تستخدم Ctrl أو Alt أو Shift مع المفتاح، أو Esc للإلغاء.");
            return;
        }

        uint vk = (uint)KeyInterop.VirtualKeyFromKey(key);
        EndRecording();
        var ok = App.Current.TrySetHotkey(mods, vk);
        if (!ok) ShowHotkeyMessage("الاختصار ده مستخدم في برنامج تاني، جرّب غيره.");
        RefreshControls();
    }

    private void ShowHotkeyMessage(string msg, bool warning = true)
    {
        HotkeyMsg.Text = msg;
        HotkeyMsg.SetResourceReference(TextBlock.ForegroundProperty, warning ? "Warn" : "Muted");
        HotkeyMsg.Visibility = Visibility.Visible;
    }

    // ---- الإعدادات ----

    private void Launch_Click(object sender, RoutedEventArgs e)
    {
        try { Settings.SetLaunchAtLogin(LaunchCheck.IsChecked == true); }
        catch { App.Current.Engine.Status = "تعذّر تغيير إعداد التشغيل مع الجهاز"; }
        LaunchCheck.IsChecked = Settings.LaunchAtLogin;
    }

    private void Tray_Click(object sender, RoutedEventArgs e) =>
        App.Current.SetTrayVisible(TrayCheck.IsChecked == true);

    private void AutoUpdate_Click(object sender, RoutedEventArgs e)
    {
        App.Current.Settings.AutoCheckUpdates = AutoUpdateCheck.IsChecked == true;
        App.Current.Settings.Save();
    }

    private void Quit_Click(object sender, RoutedEventArgs e) => App.Current.Quit();

    // قفل النافذة = إخفاء (زي نسخة الماك): التطبيق يفضل شغال علشان الاختصار.
    protected override void OnClosing(CancelEventArgs e)
    {
        if (!App.Current.Quitting)
        {
            e.Cancel = true;
            if (App.Current.Settings.ShowTray) Hide();
            else WindowState = WindowState.Minimized; // من غير tray نسيبه في الـ taskbar
        }
        base.OnClosing(e);
    }
}

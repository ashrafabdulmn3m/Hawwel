using System.ComponentModel;
using System.Windows;
using System.Windows.Input;

namespace Hawwel;

public partial class MainWindow : Window
{
    private bool _recording;

    public MainWindow()
    {
        InitializeComponent();
        DataContext = App.Current.Engine;
        RefreshControls();
        App.Current.UpdateChanged += RefreshUpdateUi;
    }

    private bool _updating;

    public void RefreshControls()
    {
        var s = App.Current.Settings;
        HotkeyText.Text = HotkeyService.Describe(s.HotkeyModifiers, s.HotkeyVk);
        LaunchCheck.IsChecked = Settings.LaunchAtLogin;
        TrayCheck.IsChecked = s.ShowTray;
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
        HotkeyMsg.Visibility = Visibility.Collapsed;
        RecordBtn.Content = "اضغط الاختصار الجديد… (Esc للإلغاء)";
        App.Current.PauseHotkey(); // علشان الاختصار الحالي ما يشتغلش وإحنا بنسجّل
        Focus();
    }

    private void EndRecording()
    {
        _recording = false;
        RecordBtn.Content = "غيّر الاختصار";
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
            ShowHotkeyMessage("لازم تستخدم Ctrl أو Alt أو Shift مع المفتاح.");
            return;
        }

        uint vk = (uint)KeyInterop.VirtualKeyFromKey(key);
        EndRecording();
        var ok = App.Current.TrySetHotkey(mods, vk);
        if (!ok) ShowHotkeyMessage("الاختصار ده مستخدم في برنامج تاني، جرّب غيره.");
        RefreshControls();
    }

    private void ShowHotkeyMessage(string msg)
    {
        HotkeyMsg.Text = msg;
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

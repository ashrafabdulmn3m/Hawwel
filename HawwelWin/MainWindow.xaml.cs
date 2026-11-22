using System.ComponentModel;
using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;

namespace Hawwel;

public partial class MainWindow : Window
{
    private static App A => App.Current;

    private string _tab = "home";
    private bool _recording;
    private bool _converted, _noSelection;
    private bool _updating;
    private bool _sized;
    private string? _checkMessage;

    /// <summary>الحجم الطبيعي للمحتوى أول ما النافذة تفتح، وأصغر حجم ممكن</summary>
    private const double PanelW = 780, PanelH = 560, MinW = 660, MinH = 460;

    public MainWindow()
    {
        InitializeComponent();
        LoadLogo();
        SourceInitialized += (_, _) => Theme.ApplyTitleBar(this);
        Loaded += (_, _) => FitToContentSize();
        MaxHeight = SystemParameters.WorkArea.Height; // الشاشات الصغيرة: المحتوى بيتمرّر

        A.Engine.Finished += OnEngineFinished;
        A.UpdateChanged += RefreshUpdateUi;
        A.HotkeyChanged += RefreshAll;
        A.Stats.Changed += () => Dispatcher.Invoke(RefreshStats);
        Loc.I.LanguageChanged += OnLanguageChanged;
        Theme.Changed += RefreshTheme;
        SizeChanged += (_, _) => AdaptStatGrid();

        TestBox.Text = Loc.T("try.sample");
        ApplySidebar();
        RefreshTheme();
        RefreshAll();
    }

    /// <summary>النافذة فيها شريط عنوان وحدود، فبنحسبهم علشان المحتوى نفسه يبقى 780×560</summary>
    private void FitToContentSize()
    {
        if (_sized) return;
        _sized = true;
        double dw = ActualWidth - RootGrid.ActualWidth, dh = ActualHeight - RootGrid.ActualHeight;
        if (dw < 0 || dh < 0) return;
        MinWidth = MinW + dw;
        MinHeight = MinH + dh;
        Width = PanelW + dw;
        Height = Math.Min(PanelH + dh, SystemParameters.WorkArea.Height);
        Left = SystemParameters.WorkArea.Left + (SystemParameters.WorkArea.Width - Width) / 2;
        Top = SystemParameters.WorkArea.Top + (SystemParameters.WorkArea.Height - Height) / 2;
    }

    // اللوجو: logo.png، ولو مش موجود نرجع لأيقونة التطبيق
    private void LoadLogo()
    {
        foreach (var name in new[] { "logo.png", "hawwel.ico" })
        {
            try
            {
                var bmp = new BitmapImage();
                bmp.BeginInit();
                bmp.UriSource = new Uri($"pack://application:,,,/Assets/{name}");
                bmp.CacheOption = BitmapCacheOption.OnLoad;
                bmp.EndInit();
                LogoImage.Source = bmp;
                AboutLogo.Source = bmp;
                return;
            }
            catch { }
        }
    }

    // ================= تحديث الواجهة =================

    public void RefreshControls() => RefreshAll();

    private void RefreshAll()
    {
        RefreshHeader();
        var keys = HotkeyParts(A.Settings.HotkeyModifiers, A.Settings.HotkeyVk);
        HeroKeys.ItemsSource = keys;
        TryKeys.ItemsSource = keys;
        ScKeys.ItemsSource = keys;

        // حالة البرنامج (السايدبار + الكارت اللي فوق)
        bool ok = A.HotkeyOk;
        SetPill(StateBadge, StateDot, StateText, ok ? "Ok" : "Warn",
            ok ? Loc.F("side.running", HotkeyService.Describe(A.Settings.HotkeyModifiers, A.Settings.HotkeyVk).Replace(" + ", "+"))
               : Loc.T("side.needsPermission"));
        StateBadge.ToolTip = StateText.Text;
        HeroTitle.Text = Loc.T(ok ? "home.hero.title" : "home.hero.titleOff");
        HeroDesc.Text = Loc.T(ok ? "home.hero.desc" : "home.hero.descOff");

        RefreshKeyboardCard();
        RefreshTry();
        RefreshStats();
        RefreshSettings();
        RefreshUpdateUi();

        SideVersion.Text = "v" + Updater.Current;
        AboutVersion.Text = Loc.F("about.version", Updater.Current);
        NewInTitle.Text = Loc.F("about.newIn", Updater.Current);
        Changelog.Children.Clear();
        for (int i = 1; i <= 5; i++)
        {
            var row = new DockPanel { Margin = new Thickness(0, 0, 0, 4) };
            var dot = new TextBlock { Text = "•", Margin = new Thickness(0, 0, 8, 0) };
            dot.SetResourceReference(TextBlock.ForegroundProperty, "Muted");
            var t = new TextBlock { Text = Loc.T($"about.log.{i}"), TextWrapping = TextWrapping.Wrap, FontSize = 12 };
            t.SetResourceReference(TextBlock.ForegroundProperty, "Muted");
            row.Children.Add(dot);
            row.Children.Add(t);
            Changelog.Children.Add(row);
        }
    }

    private void OnLanguageChanged()
    {
        // لو المثال لسه زي ما هو، نبدّله بمثال اللغة الجديدة
        if (TestBox.Text == SampleFor(Loc.I.IsArabic ? "en" : "ar")) TestBox.Text = Loc.T("try.sample");
        ApplySidebar();
        RefreshAll();
    }

    private static string SampleFor(string lang) => lang == "ar" ? "hgsghl ugd;l" : "اثممخ صخقمي";

    private void RefreshHeader()
    {
        HeaderTitle.Text = Loc.T($"tab.{_tab}");
        var sub = _tab == "about" ? "" : Loc.T($"sub.{_tab}");
        HeaderSub.Text = sub;
        HeaderSub.Visibility = sub == "" ? Visibility.Collapsed : Visibility.Visible;
    }

    private void RefreshTheme()
    {
        // الكارت اللي فوق: تدرّج من الأزرق الفاتح للون الكارت
        if (Application.Current.Resources["AccentSoft"] is SolidColorBrush a &&
            Application.Current.Resources["Card"] is SolidColorBrush c)
        {
            HeroCard.Background = new LinearGradientBrush(a.Color, c.Color, new Point(0, 0), new Point(0.7, 1));
        }
    }

    /// <summary>"Ctrl + Alt + K" → ["Ctrl", "+", "Alt", "+", "K"] علشان كل جزء يظهر ككابسة</summary>
    private static List<string> HotkeyParts(uint mods, uint vk)
    {
        var keys = new List<string>();
        foreach (var part in HotkeyService.Describe(mods, vk).Split(" + "))
        {
            if (keys.Count > 0) keys.Add("+");
            keys.Add(part);
        }
        return keys;
    }

    /// <summary>بيلوّن "بيل" حالة: Ok / Warn / Accent</summary>
    private static void SetPill(Border pill, Ellipse dot, TextBlock text, string kind, string label)
    {
        pill.SetResourceReference(Border.BackgroundProperty, kind + "Soft");
        dot.SetResourceReference(Shape.FillProperty, kind);
        text.SetResourceReference(TextBlock.ForegroundProperty, kind);
        text.Text = label;
    }

    // ================= السايدبار =================

    private void ApplySidebar()
    {
        bool c = A.Settings.SidebarCollapsed;
        SideCol.Width = new GridLength(c ? 64 : 196);
        SidePanel.Margin = c ? new Thickness(10, 16, 10, 14) : new Thickness(12, 16, 12, 14);

        Brand.Margin = c ? new Thickness(0, 0, 0, 18) : new Thickness(4, 0, 4, 18);
        Brand.HorizontalAlignment = c ? HorizontalAlignment.Center : HorizontalAlignment.Stretch;
        BrandText.Visibility = c ? Visibility.Collapsed : Visibility.Visible;
        LogoBox.Width = LogoBox.Height = c ? 36 : 40;
        Grid.SetColumn(SideToggle, c ? 0 : 2);
        Grid.SetRow(SideToggle, c ? 1 : 0);
        SideToggle.Margin = c ? new Thickness(0, 10, 0, 0) : new Thickness(0);
        SideToggle.HorizontalAlignment = HorizontalAlignment.Center;
        SideToggle.Content = Loc.I.IsArabic ? "" : ""; // DockRight / DockLeft
        SideToggle.ToolTip = Loc.T(c ? "side.expand" : "side.collapse");

        foreach (var (btn, text) in new (RadioButton, TextBlock)[]
                 { (NavHome, NavHomeText), (NavShortcuts, NavShortcutsText), (NavActivity, NavActivityText),
                   (NavSettings, NavSettingsText), (NavAbout, NavAboutText) })
        {
            text.Visibility = c ? Visibility.Collapsed : Visibility.Visible;
            btn.HorizontalContentAlignment = c ? HorizontalAlignment.Center : HorizontalAlignment.Left;
            btn.ToolTip = c ? Loc.T($"tab.{btn.Tag}") : null;
        }
        StateText.Visibility = c ? Visibility.Collapsed : Visibility.Visible;
        StateRow.HorizontalAlignment = c ? HorizontalAlignment.Center : HorizontalAlignment.Left;
        StateBadge.Padding = c ? new Thickness(0, 10, 0, 10) : new Thickness(10, 8, 10, 8);
    }

    private void SideToggle_Click(object sender, RoutedEventArgs e)
    {
        A.Settings.SidebarCollapsed = !A.Settings.SidebarCollapsed;
        A.Settings.Save();
        ApplySidebar();
    }

    private void Nav_Checked(object sender, RoutedEventArgs e)
    {
        if (sender is not RadioButton { Tag: string tab } || !IsInitialized || HomeTab == null) return;
        if (_recording && tab != "shortcuts") EndRecording();
        _tab = tab;
        HomeTab.Visibility = tab == "home" ? Visibility.Visible : Visibility.Collapsed;
        ShortcutsTab.Visibility = tab == "shortcuts" ? Visibility.Visible : Visibility.Collapsed;
        ActivityTab.Visibility = tab == "activity" ? Visibility.Visible : Visibility.Collapsed;
        SettingsTab.Visibility = tab == "settings" ? Visibility.Visible : Visibility.Collapsed;
        AboutTab.Visibility = tab == "about" ? Visibility.Visible : Visibility.Collapsed;
        RefreshHeader();
        if (tab == "activity") RefreshStats();
        if (tab == "settings") RefreshSettings();
        BodyScroll.ScrollToTop();
    }

    private void ToActivity_Click(object sender, RoutedEventArgs e) => NavActivity.IsChecked = true;

    // ================= الرئيسية =================

    private void RefreshKeyboardCard()
    {
        bool ok = LayoutConverter.BothInstalled();
        SetPill(KbPill, KbDot, KbState, ok ? "Ok" : "Warn", Loc.T(ok ? "home.kb.ok" : "home.kb.off"));
        KbDesc.Text = Loc.T(ok ? "home.kb.okDesc" : "home.kb.offDesc");
        KbOpen.Visibility = ok ? Visibility.Collapsed : Visibility.Visible;
        KbCard.SetResourceReference(Border.BackgroundProperty, ok ? "Card" : "WarnSoft");
        KbCard.SetResourceReference(Border.BorderBrushProperty, ok ? "Line" : "WarnLine");
    }

    private void KbOpen_Click(object sender, RoutedEventArgs e) => Open("ms-settings:regionlanguage");

    // ---- جرّب هنا: اكتب، حدد، اضغط الاختصار ----

    private int Step => _converted ? 3 : TestBox.SelectionLength > 0 ? 2 : TestBox.Text.Length == 0 ? 0 : 1;

    private void RefreshTry()
    {
        int step = Step;
        SetStep(Step1, Step1Num, Step1NumText, Step1Text, step >= 1);
        SetStep(Step2, Step2Num, Step2NumText, Step2Text, step >= 2);
        SetStep(Step3, Step3Num, Step3NumText, Step3Text, step >= 3);
        TestPlaceholder.Visibility = TestBox.Text.Length == 0 ? Visibility.Visible : Visibility.Collapsed;

        if (_converted) SetPill(TryPill, TryDot, TryState, "Ok", Loc.T("try.state.done") + " ✓");
        else if (_noSelection) SetPill(TryPill, TryDot, TryState, "Warn", Loc.T("try.state.noSel"));
        else if (TestBox.SelectionLength > 0) SetPill(TryPill, TryDot, TryState, "Accent", Loc.T("try.state.sel"));
        else SetPill(TryPill, TryDot, TryState, "Ok", Loc.T("try.state.ready"));
    }

    private static void SetStep(Border pill, Border num, TextBlock numText, TextBlock text, bool done)
    {
        pill.SetResourceReference(Border.BackgroundProperty, done ? "OkSoft" : "Field");
        if (done) pill.BorderBrush = Brushes.Transparent; else pill.SetResourceReference(Border.BorderBrushProperty, "Line");
        num.SetResourceReference(Border.BackgroundProperty, done ? "Ok" : "Card");
        num.SetResourceReference(Border.BorderBrushProperty, done ? "Ok" : "Line");
        if (done) numText.Foreground = Brushes.White; else numText.SetResourceReference(TextBlock.ForegroundProperty, "Muted");
        text.SetResourceReference(TextBlock.ForegroundProperty, done ? "Ok" : "Muted");
    }

    private void TestBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        _converted = false;
        if (IsInitialized) RefreshTry();
    }

    private void TestBox_SelectionChanged(object sender, RoutedEventArgs e)
    {
        if (TestBox.SelectionLength > 0) { _noSelection = false; _converted = false; }
        if (IsInitialized) RefreshTry();
    }

    private void TryReset_Click(object sender, RoutedEventArgs e)
    {
        TestBox.Text = Loc.T("try.sample");
        _converted = _noSelection = false;
        TestBox.Focus();
        TestBox.SelectAll();
        RefreshTry();
    }

    /// <summary>بعد كل ضغطة اختصار: لو كانت في خانة التجربة نحدّث الخطوات والحالة</summary>
    private void OnEngineFinished(bool success)
    {
        if (A.Engine.Status == EngineStatus.NoKeyboard) RefreshKeyboardCard();
        if (!IsActive || !TestBox.IsKeyboardFocusWithin) return;
        if (success)
        {
            _converted = true;
            _noSelection = false;
            FlashTestBox();
        }
        else if (A.Engine.Status == EngineStatus.NoSelection)
        {
            _noSelection = true;
        }
        RefreshTry();
    }

    private void FlashTestBox()
    {
        TestBox.SetResourceReference(Control.BorderBrushProperty, "Ok");
        TryKeys.Opacity = 0.55;
        var t = new System.Windows.Threading.DispatcherTimer { Interval = TimeSpan.FromMilliseconds(600) };
        t.Tick += (_, _) =>
        {
            t.Stop();
            TestBox.SetResourceReference(Control.BorderBrushProperty, "Line");
            TryKeys.Opacity = 1;
        };
        t.Start();
    }

    // ================= النشاط =================

    private void RefreshStats()
    {
        var s = A.Stats;
        TodayConv.Text = Num.Grouped(s.TodayCount);
        TodayChars.Text = Num.Compact(s.TodayChars);
        TodaySaved.Text = Num.TimeSaved(s.TodayChars);

        StatTotal.Text = Num.Grouped(s.Data.Total);
        StatWeek.Text = Num.Grouped(s.WeekCount);
        StatChars.Text = Num.Compact(s.Data.Chars);
        StatTime.Text = Num.TimeSaved(s.Data.Chars);
        ClearBtn.IsEnabled = s.Data.Total > 0;

        BuildChart();

        var share = s.ToArabicShare;
        int toAr = (int)Math.Round((share ?? 0) * 100);
        DirA.Width = new GridLength(share ?? 0, GridUnitType.Star);
        DirB.Width = new GridLength(share == null ? 0 : 1 - share.Value, GridUnitType.Star);
        DirToArValue.Text = share == null ? "–" : $"{toAr}%";
        DirToEnValue.Text = share == null ? "–" : $"{100 - toAr}%";

        AppsList.Children.Clear();
        var apps = s.TopApps();
        AppsEmpty.Visibility = apps.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
        foreach (var (name, appShare) in apps)
        {
            var row = new Grid { Margin = new Thickness(0, 0, 0, 6) };
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(80) });
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(40) });
            row.Children.Add(new TextBlock { Text = name, FontSize = 12, TextTrimming = TextTrimming.CharacterEllipsis, VerticalAlignment = VerticalAlignment.Center });

            var track = new Grid { Height = 6, Margin = new Thickness(8, 0, 8, 0), VerticalAlignment = VerticalAlignment.Center };
            track.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(appShare, GridUnitType.Star) });
            track.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1 - appShare, GridUnitType.Star) });
            var bg = new Border { CornerRadius = new CornerRadius(3) };
            bg.SetResourceReference(Border.BackgroundProperty, "Field");
            Grid.SetColumnSpan(bg, 2);
            var fill = new Border { CornerRadius = new CornerRadius(3) };
            fill.SetResourceReference(Border.BackgroundProperty, "Accent");
            track.Children.Add(bg);
            track.Children.Add(fill);
            Grid.SetColumn(track, 1);
            row.Children.Add(track);

            var pct = new TextBlock { Text = $"{Math.Round(appShare * 100)}%", FontSize = 12, HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Center };
            pct.SetResourceReference(TextBlock.ForegroundProperty, "Muted");
            Grid.SetColumn(pct, 2);
            row.Children.Add(pct);
            AppsList.Children.Add(row);
        }
    }

    /// <summary>رسم آخر 7 أيام (النهارده لونه أغمق)</summary>
    private void BuildChart()
    {
        Chart.Children.Clear();
        Chart.ColumnDefinitions.Clear();
        var days = A.Stats.Last7();
        int peak = Math.Max(1, days.Max(d => d.Count));
        for (int i = 0; i < days.Count; i++)
        {
            var (date, count) = days[i];
            bool today = i == days.Count - 1;
            Chart.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

            var col = new StackPanel { VerticalAlignment = VerticalAlignment.Bottom, Margin = new Thickness(5, 0, 5, 0) };
            var value = new TextBlock { Text = count.ToString(), FontSize = 10.5, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 0, 0, 6) };
            value.SetResourceReference(TextBlock.ForegroundProperty, "Muted");
            var bar = new Border
            {
                Height = Math.Max(3, count * 62.0 / peak),
                MaxWidth = 34,
                CornerRadius = new CornerRadius(6, 6, 3, 3),
            };
            bar.SetResourceReference(Border.BackgroundProperty, today ? "Accent" : "AccentMid");
            var label = new TextBlock
            {
                Text = Loc.T($"day.{(int)date.DayOfWeek + 1}"),
                FontSize = 10.5,
                FontWeight = today ? FontWeights.SemiBold : FontWeights.Normal,
                HorizontalAlignment = HorizontalAlignment.Center,
                Margin = new Thickness(0, 6, 0, 0),
            };
            label.SetResourceReference(TextBlock.ForegroundProperty, today ? "Ink" : "Muted");
            col.Children.Add(value);
            col.Children.Add(bar);
            col.Children.Add(label);
            Grid.SetColumn(col, i);
            Chart.Children.Add(col);
        }
    }

    /// <summary>الأرقام الأربعة: جنب بعض، ولو النافذة ضيقة يبقوا 2×2</summary>
    private void AdaptStatGrid()
    {
        int cols = BodyScroll.ActualWidth < 560 ? 2 : 4;
        if (StatGrid.Columns == cols) return;
        StatGrid.Columns = cols;
        for (int i = 0; i < StatGrid.Children.Count; i++)
        {
            if (StatGrid.Children[i] is not Border b) continue;
            int c = i % cols, r = i / cols;
            b.Margin = new Thickness(c == 0 ? 0 : 6, r == 0 ? 0 : 12, c == cols - 1 ? 0 : 6, 0);
        }
    }

    private void ClearStats_Click(object sender, RoutedEventArgs e)
    {
        if (Confirm(Loc.T("act.clear.confirm"), Loc.T("act.clear.confirmDesc"))) A.Stats.Clear();
    }

    // ================= الإعدادات =================

    private void RefreshSettings()
    {
        var s = A.Settings;
        LaunchCheck.IsChecked = Settings.LaunchAtLogin;
        TrayCheck.IsChecked = s.ShowTray;
        ThemeLight.IsChecked = Theme.Mode == Theme.Light;
        ThemeDark.IsChecked = Theme.Mode == Theme.Dark;
        ThemeSystem.IsChecked = Theme.Mode == Theme.System;
        LangAr.IsChecked = Loc.I.IsArabic;
        LangEn.IsChecked = !Loc.I.IsArabic;
        SoundCheck.IsChecked = s.PlaySound;
        SwitchKbCheck.IsChecked = s.SwitchKeyboard;
        AutoUpdateCheck.IsChecked = s.AutoCheckUpdates;
        AutoInstallCheck.IsChecked = s.AutoInstallUpdates;
        AutoInstallCheck.IsEnabled = s.AutoCheckUpdates;

        var detail = Loc.F("set.check.version", Updater.Current);
        if (s.LastUpdateCheck is DateTime last) detail += " · " + Loc.F("set.check.last", Num.Ago(last));
        CheckDetail.Text = _checkMessage ?? detail;
    }

    private void Launch_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            Settings.SetLaunchAtLogin(LaunchCheck.IsChecked == true);
            LoginError.Visibility = Visibility.Collapsed;
        }
        catch { LoginError.Visibility = Visibility.Visible; }
        LaunchCheck.IsChecked = Settings.LaunchAtLogin;
    }

    private void Tray_Click(object sender, RoutedEventArgs e) => A.SetTrayVisible(TrayCheck.IsChecked == true);

    private void Theme_Click(object sender, RoutedEventArgs e)
    {
        if (sender is RadioButton { Tag: string mode }) Theme.Set(mode);
    }

    private void Lang_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not RadioButton { Tag: string lang }) return;
        A.Settings.Language = lang;
        A.Settings.Save();
        Loc.I.Lang = lang;
    }

    private void Sound_Click(object sender, RoutedEventArgs e)
    {
        A.Settings.PlaySound = SoundCheck.IsChecked == true;
        A.Settings.Save();
        if (A.Settings.PlaySound) ConvertSound.Play(); // تسمعه أول ما تفعّله
    }

    private void SwitchKb_Click(object sender, RoutedEventArgs e)
    {
        A.Settings.SwitchKeyboard = SwitchKbCheck.IsChecked == true;
        A.Settings.Save();
    }

    private void AutoUpdate_Click(object sender, RoutedEventArgs e)
    {
        A.Settings.AutoCheckUpdates = AutoUpdateCheck.IsChecked == true;
        A.Settings.Save();
        RefreshSettings();
    }

    private void AutoInstall_Click(object sender, RoutedEventArgs e)
    {
        A.Settings.AutoInstallUpdates = AutoInstallCheck.IsChecked == true;
        A.Settings.Save();
    }

    private async void Check_Click(object sender, RoutedEventArgs e)
    {
        CheckBtn.IsEnabled = false;
        _checkMessage = Loc.T("set.check.checking");
        RefreshSettings();
        var r = await A.CheckForUpdateAsync(userInitiated: true);
        _checkMessage = r switch
        {
            UpdateCheckResult.Available => Loc.T("set.check.found"),
            UpdateCheckResult.UpToDate => Loc.T("set.check.upToDate"),
            _ => Loc.T("set.check.failed"),
        };
        RefreshSettings();
        CheckBtn.IsEnabled = true;
        _checkMessage = null; // المرة الجاية يرجع لـ "عندك v… · آخر فحص…"
    }

    private void ResetAll_Click(object sender, RoutedEventArgs e)
    {
        if (!Confirm(Loc.T("set.resetAll.confirm"), Loc.T("set.resetAll.confirmDesc"))) return;
        A.Settings.ResetToDefaults();
        A.ApplySettingsAfterReset();
        Theme.Set(A.Settings.Theme);
        ApplySidebar();
        RefreshAll();
    }

    private void Quit_Click(object sender, RoutedEventArgs e) => A.Quit();

    private void Link_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: string url }) Open(url);
    }

    private static void Open(string url)
    {
        try { Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); } catch { }
    }

    private bool Confirm(string title, string body) =>
        MessageBox.Show(this, body, title, MessageBoxButton.OKCancel, MessageBoxImage.Warning, MessageBoxResult.Cancel,
            Loc.I.IsArabic ? MessageBoxOptions.RtlReading | MessageBoxOptions.RightAlign : MessageBoxOptions.None)
        == MessageBoxResult.OK;

    // ================= التحديثات =================

    private void RefreshUpdateUi()
    {
        if (_updating) return; // ما نغيّرش الرسالة وإحنا بننزّل
        UpdateProgress.Visibility = Visibility.Collapsed;
        var u = A.PendingUpdate;
        if (u == null) { UpdateCard.Visibility = Visibility.Collapsed; return; }
        bool ready = A.DownloadedInstaller != null;
        UpdateTitle.Text = Loc.F(ready ? "home.update.ready" : "home.update.title", u.Version);
        UpdateMsg.Text = Loc.T(ready ? "home.update.readyDesc" : "home.update.desc");
        UpdateBtn.Content = Loc.T("home.update.now");
        UpdateBtn.IsEnabled = true;
        UpdateCard.Visibility = Visibility.Visible;
    }

    private async void Update_Click(object sender, RoutedEventArgs e)
    {
        var info = A.PendingUpdate;
        if (info == null) return;

        _updating = true;
        UpdateBtn.IsEnabled = false;
        try
        {
            var path = A.DownloadedInstaller;
            if (path == null)
            {
                UpdateProgress.Value = 0;
                UpdateProgress.Visibility = Visibility.Visible;
                UpdateMsg.Text = Loc.T("home.update.downloading");
                var progress = new Progress<double>(p => UpdateProgress.Value = p * 100);
                path = await Updater.DownloadAsync(info, progress);
            }
            UpdateMsg.Text = Loc.T("home.update.installing");
            Updater.LaunchInstaller(path);
            A.Quit();
        }
        catch (Exception ex)
        {
            _updating = false;
            UpdateProgress.Visibility = Visibility.Collapsed;
            UpdateBtn.IsEnabled = true;
            UpdateMsg.Text = Loc.F("home.update.failed", ex.Message);
        }
    }

    // ================= تسجيل اختصار جديد =================

    private void Record_Click(object sender, RoutedEventArgs e)
    {
        _recording = true;
        A.PauseHotkey(); // علشان الاختصار الحالي ما يشتغلش وإحنا بنسجّل
        ScIdleCard.Visibility = Visibility.Collapsed;
        ScRecCard.Visibility = Visibility.Visible;
        ScConflictCard.Visibility = Visibility.Collapsed;
        ScRecDesc.Text = Loc.T("sc.rec.desc");
        ShowLiveKeys();
        Focus();
    }

    private void RecordCancel_Click(object sender, RoutedEventArgs e) => EndRecording();

    private void EndRecording()
    {
        _recording = false;
        ScIdleCard.Visibility = Visibility.Visible;
        ScRecCard.Visibility = Visibility.Collapsed;
        ScConflictCard.Visibility = Visibility.Collapsed;
        A.ResumeHotkey();
        RefreshAll();
    }

    private void ResetShortcut_Click(object sender, RoutedEventArgs e)
    {
        if (_recording) EndRecording();
        var d = new Settings();
        A.TrySetHotkey(d.HotkeyModifiers, d.HotkeyVk);
        RefreshAll();
    }

    /// <summary>الزراير اللي متضغطة دلوقتي + "?" للمفتاح اللي لسه</summary>
    private void ShowLiveKeys()
    {
        var parts = new List<string>();
        var m = Keyboard.Modifiers;
        if (m.HasFlag(ModifierKeys.Control)) parts.Add("Ctrl");
        if (m.HasFlag(ModifierKeys.Alt)) parts.Add("Alt");
        if (m.HasFlag(ModifierKeys.Shift)) parts.Add("Shift");
        if (m.HasFlag(ModifierKeys.Windows)) parts.Add("Win");
        parts.Add("?");
        var items = new List<string>();
        foreach (var p in parts) { if (items.Count > 0) items.Add("+"); items.Add(p); }
        ScLiveKeys.ItemsSource = items;
        ScLiveKeys.Opacity = parts.Count == 1 ? 0.45 : 1;
    }

    private void Window_PreviewKeyUp(object sender, KeyEventArgs e)
    {
        if (_recording) ShowLiveKeys();
    }

    private void Window_PreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (!_recording) return;
        e.Handled = true;

        var key = e.Key == Key.System ? e.SystemKey : e.Key;
        if (key is Key.LeftCtrl or Key.RightCtrl or Key.LeftAlt or Key.RightAlt or Key.LeftShift
            or Key.RightShift or Key.LWin or Key.RWin or Key.ImeProcessed or Key.DeadCharProcessed)
        {
            ShowLiveKeys(); // لسه بيضغط على مفاتيح التعديل
            return;
        }

        if (key == Key.Escape)
        {
            EndRecording();
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
            ScRecDesc.Text = Loc.T("sc.rec.needMod");
            return;
        }

        uint vk = (uint)KeyInterop.VirtualKeyFromKey(key);
        if (A.TrySetHotkey(mods, vk))
        {
            EndRecording();
            return;
        }
        // مستخدم في برنامج تاني: نوريه ونفضل بنسجّل
        A.PauseHotkey();
        ScConflictKeys.ItemsSource = HotkeyParts(mods, vk);
        ScConflictCard.Visibility = Visibility.Visible;
    }

    // ================= القفل =================

    // قفل النافذة = إخفاء (زي نسخة الماك): التطبيق يفضل شغال علشان الاختصار.
    protected override void OnClosing(CancelEventArgs e)
    {
        if (!App.Current.Quitting)
        {
            e.Cancel = true;
            if (_recording) EndRecording();
            if (App.Current.Settings.ShowTray) Hide();
            else WindowState = WindowState.Minimized; // من غير tray نسيبه في الـ taskbar
        }
        base.OnClosing(e);
    }
}

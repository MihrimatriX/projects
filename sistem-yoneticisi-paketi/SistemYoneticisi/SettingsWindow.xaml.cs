using System.Globalization;

using System.Windows;

using Microsoft.Win32;

using SistemYoneticisi.Helpers;

using SistemYoneticisi.Services;

using SistemYoneticisi.ViewModels;



namespace SistemYoneticisi;



public partial class SettingsWindow : Window

{

    private readonly MainViewModel _mainVm;



    public SettingsWindow(MainViewModel mainVm)

    {

        InitializeComponent();

        _mainVm = mainVm;

        LoadFields(SettingsService.Instance.Settings);

    }



    private void LoadFields(AppSettings s)

    {

        HistoryEnabledBox.IsChecked = s.HistoryEnabled;

        RetentionHoursBox.Text = s.HistoryRetentionHours.ToString(CultureInfo.InvariantCulture);

        AlarmsEnabledBox.IsChecked = s.AlarmsEnabled;

        CpuThresholdBox.Text = s.CpuAlarmThreshold.ToString(CultureInfo.InvariantCulture);

        RamThresholdBox.Text = s.RamAlarmThreshold.ToString(CultureInfo.InvariantCulture);

        AlarmDurationBox.Text = s.AlarmDurationSeconds.ToString(CultureInfo.InvariantCulture);

        HighContrastBox.IsChecked = s.HighContrastMode;

        StartMinimizedBox.IsChecked = s.StartMinimized;

        RunAtLoginBox.IsChecked = s.RunAtLogin;

        GlobalHotkeyEnabledBox.IsChecked = s.GlobalHotkeyEnabled;

        ShowHotkeyBox.Text = s.ShowHotkey;

    }



    private void Save_Click(object sender, RoutedEventArgs e)

    {

        if (!TryParseSettings(out var settings))

        {

            MessageBox.Show("Geçersiz ayar değeri. Sayısal alanları ve kısayol formatını kontrol edin.", "Ayarlar",

                MessageBoxButton.OK, MessageBoxImage.Warning);

            return;

        }



        SettingsService.Instance.Settings = settings;

        SettingsService.Instance.Save();

        _mainVm.OnSettingsSaved();

        DialogResult = true;

        Close();

    }



    private bool TryParseSettings(out AppSettings settings)

    {

        settings = new AppSettings();

        try

        {

            settings.HistoryEnabled = HistoryEnabledBox.IsChecked == true;

            settings.HistoryRetentionHours = int.Parse(RetentionHoursBox.Text, CultureInfo.InvariantCulture);

            settings.AlarmsEnabled = AlarmsEnabledBox.IsChecked == true;

            settings.CpuAlarmThreshold = double.Parse(CpuThresholdBox.Text, CultureInfo.InvariantCulture);

            settings.RamAlarmThreshold = double.Parse(RamThresholdBox.Text, CultureInfo.InvariantCulture);

            settings.AlarmDurationSeconds = int.Parse(AlarmDurationBox.Text, CultureInfo.InvariantCulture);

            settings.HighContrastMode = HighContrastBox.IsChecked == true;

            settings.StartMinimized = StartMinimizedBox.IsChecked == true;

            settings.RunAtLogin = RunAtLoginBox.IsChecked == true;

            settings.GlobalHotkeyEnabled = GlobalHotkeyEnabledBox.IsChecked == true;

            settings.ShowHotkey = ShowHotkeyBox.Text.Trim();

            settings.WelcomeShown = SettingsService.Instance.Settings.WelcomeShown;



            if (settings.GlobalHotkeyEnabled &&

                !HotkeyParser.TryParse(settings.ShowHotkey, out _, out _))

                return false;



            return settings.HistoryRetentionHours is > 0 and <= 168

                   && settings.AlarmDurationSeconds > 0

                   && settings.CpuAlarmThreshold is > 0 and <= 100

                   && settings.RamAlarmThreshold is > 0 and <= 100;

        }

        catch

        {

            return false;

        }

    }



    private void Export_Click(object sender, RoutedEventArgs e)

    {

        var dialog = new SaveFileDialog

        {

            Filter = "JSON|*.json",

            FileName = "sistem-yoneticisi-ayarlar.json"

        };

        if (dialog.ShowDialog() != true)

            return;



        try

        {

            if (TryParseSettings(out var current))

                SettingsService.Instance.Settings = current;

            SettingsService.Instance.ExportTo(dialog.FileName);

            MessageBox.Show("Ayarlar dışa aktarıldı.", "Ayarlar", MessageBoxButton.OK, MessageBoxImage.Information);

        }

        catch (Exception ex)

        {

            LogService.Error("Settings export failed", ex);

            MessageBox.Show("Dışa aktarma başarısız.", "Ayarlar", MessageBoxButton.OK, MessageBoxImage.Error);

        }

    }



    private void Import_Click(object sender, RoutedEventArgs e)

    {

        var dialog = new OpenFileDialog { Filter = "JSON|*.json" };

        if (dialog.ShowDialog() != true)

            return;



        if (!SettingsService.Instance.TryImportFrom(dialog.FileName))

        {

            MessageBox.Show("İçe aktarma başarısız. Dosya formatını kontrol edin.", "Ayarlar",

                MessageBoxButton.OK, MessageBoxImage.Warning);

            return;

        }



        LoadFields(SettingsService.Instance.Settings);

        _mainVm.OnSettingsSaved();

        MessageBox.Show("Ayarlar içe aktarıldı.", "Ayarlar", MessageBoxButton.OK, MessageBoxImage.Information);

    }



    private void Cancel_Click(object sender, RoutedEventArgs e)

    {

        DialogResult = false;

        Close();

    }

}



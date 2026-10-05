using System.Windows;
using System.Windows.Input;
using EkranGoruntusu.Services;
using EkranGoruntusu.ViewModels;
using Microsoft.Win32;

namespace EkranGoruntusu.Views;

public partial class SettingsWindow : Window
{
    private readonly MainViewModel _vm;

    public SettingsWindow(MainViewModel vm)
    {
        InitializeComponent();
        _vm = vm;
        HotkeyBox.ItemsSource = SettingsService.HotkeyChoices.Select(SettingsService.DisplayHotkey).ToList();
        HistoryLimitBox.ItemsSource = SettingsService.HistoryLimitChoices;
        ShowValues();
    }

    private void ShowValues()
    {
        SaveFolderBox.Text = _vm.Settings.SaveFolder;
        TemplateBox.Text = _vm.Settings.FilenameTemplate;
        HotkeyBox.SelectedIndex = Array.IndexOf(SettingsService.HotkeyChoices, _vm.Settings.Hotkey);
        HistoryLimitBox.SelectedItem = _vm.Settings.HistoryLimit;
    }

    private void Window_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape) Close();
    }

    private void Info(string text, string caption, MessageBoxImage icon) =>
        MessageBox.Show(this, text, caption, MessageBoxButton.OK, icon);

    private void TitleBar_MouseLeftButtonDown(object sender, MouseButtonEventArgs e) => DragMove();

    private void GoHistory_Click(object sender, RoutedEventArgs e)
    {
        Owner?.Activate();
        Close();
    }

    private void Close_Click(object sender, RoutedEventArgs e) => Close();

    private void Browse_Click(object sender, RoutedEventArgs e)
    {
        var dlg = new OpenFolderDialog { Title = "Kayıt klasörü seçin", InitialDirectory = SaveFolderBox.Text };
        if (dlg.ShowDialog(this) == true)
            SaveFolderBox.Text = dlg.FolderName;
    }

    private void Reset_Click(object sender, RoutedEventArgs e)
    {
        if (MessageBox.Show(this, "Tüm ayarlar varsayılana dönsün mü?", "Onay", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes)
            return;

        _vm.Settings.Reset();
        _vm.ApplySaveFolder(_vm.Settings.SaveFolder);
        if (_vm.ApplyHotkey(_vm.Settings.Hotkey) is { } warning) _vm.StatusMessage = warning;
        ShowValues();
    }

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        var template = TemplateBox.Text.Trim();
        if (!SettingsService.IsValidTemplate(template))
        {
            Info("Şablonda en az bir değişken kullanın: {yyyy}, {MM}, {dd}, {HH}, {mm}, {ss}\n" +
                 "Dosya adında geçersiz karakterler (\\ / : * ? \" < > |) kullanılamaz.",
                "Geçersiz şablon", MessageBoxImage.Warning);
            TemplateBox.Focus();
            return;
        }

        try { _vm.ApplySaveFolder(SaveFolderBox.Text.Trim()); }
        catch (Exception ex)
        {
            Info($"Klasör kullanılamıyor: {ex.Message}", "Hata", MessageBoxImage.Error);
            return;
        }
        _vm.Settings.FilenameTemplate = template;
        if (HistoryLimitBox.SelectedItem is int limit) _vm.Settings.HistoryLimit = limit;

        if (HotkeyBox.SelectedIndex >= 0 && SettingsService.HotkeyChoices[HotkeyBox.SelectedIndex] is var hotkey
            && hotkey != _vm.Settings.Hotkey && _vm.ApplyHotkey(hotkey) is { } warning)
        {
            HotkeyBox.SelectedIndex = Array.IndexOf(SettingsService.HotkeyChoices, _vm.Settings.Hotkey);
            Info(warning + "\nDiğer ayarlar kaydedildi.", "Kısayol", MessageBoxImage.Warning);
            return;
        }
        Info("Ayarlar kaydedildi.", "Ayarlar", MessageBoxImage.Information);
    }
}

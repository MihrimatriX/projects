using System;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Hardcodet.Wpf.TaskbarNotification;
using SistemYoneticisi.Services;
using SistemYoneticisi.ViewModels;

namespace SistemYoneticisi
{
    public partial class MainWindow : Window
    {
        private readonly MainViewModel _viewModel;
        private bool _isExplicitShutdown;

        public MainWindow()
        {
            InitializeComponent();
            _viewModel = new MainViewModel();
            _viewModel.RequestAbout += () => new AboutWindow { Owner = this }.ShowDialog();
            _viewModel.RequestHelp += () => new HelpWindow { Owner = this }.ShowDialog();
            _viewModel.RequestSettings += () => new SettingsWindow(_viewModel) { Owner = this }.ShowDialog();
            _viewModel.RequestShowWindow += ShowMainWindow;
            _viewModel.RequestTrayNotification += ShowTrayNotification;
            _viewModel.GlobalHotkeyService.HotkeyPressed += ToggleWindowVisibility;

            DataContext = _viewModel;
            KeyDown += MainWindow_KeyDown;
            Loaded += MainWindow_Loaded;

            BuildTrayNavigationMenu();

            try
            {
                var exePath = Environment.ProcessPath;
                if (!string.IsNullOrEmpty(exePath))
                {
                    var icon = System.Drawing.Icon.ExtractAssociatedIcon(exePath);
                    if (icon != null)
                        MyNotifyIcon.Icon = icon;
                }
            }
            catch (Exception ex)
            {
                LogService.Error("Tray icon load failed", ex);
            }
        }

        private void BuildTrayNavigationMenu()
        {
            var menu = TrayContextMenu;
            var insertIndex = 1;

            foreach (var item in _viewModel.NavigationItems)
            {
                var menuItem = new MenuItem
                {
                    Header = $"{item.Icon} {item.Title}",
                    Command = _viewModel.NavigateCommand,
                    CommandParameter = item.Id
                };
                menu.Items.Insert(insertIndex++, menuItem);
            }

            menu.Items.Insert(insertIndex, new Separator());
        }

        private void MainWindow_Loaded(object sender, RoutedEventArgs e)
        {
            if (SettingsService.Instance.Settings.StartMinimized)
                Hide();

            if (!SettingsService.Instance.Settings.WelcomeShown)
                new WelcomeWindow { Owner = this }.ShowDialog();
        }

        private void MainWindow_KeyDown(object sender, KeyEventArgs e)
        {
            if (Keyboard.Modifiers == ModifierKeys.Control && e.Key == Key.OemComma)
            {
                _viewModel.ShowSettingsCommand.Execute(null);
                e.Handled = true;
                return;
            }

            if (Keyboard.Modifiers != ModifierKeys.None)
                return;

            var digit = KeyToDigit(e.Key);
            if (digit == null)
                return;

            var module = _viewModel.ModuleRegistry.Modules
                .FirstOrDefault(m => m.ShortcutDigit == digit);
            if (module == null)
                return;

            _viewModel.NavigateCommand.Execute(module.Id);
            e.Handled = true;
        }

        private static string? KeyToDigit(Key key) => key switch
        {
            Key.D1 or Key.NumPad1 => "1",
            Key.D2 or Key.NumPad2 => "2",
            Key.D3 or Key.NumPad3 => "3",
            Key.D4 or Key.NumPad4 => "4",
            Key.D5 or Key.NumPad5 => "5",
            _ => null
        };

        private void ToggleWindowVisibility()
        {
            if (IsVisible && WindowState != WindowState.Minimized && IsActive)
                Hide();
            else
                ShowMainWindow();
        }

        private void ShowMainWindow()
        {
            Show();
            WindowState = WindowState.Normal;
            Activate();
        }

        private void ShowWindow_Click(object sender, RoutedEventArgs e) => ShowMainWindow();

        private void ExitApplication_Click(object sender, RoutedEventArgs e)
        {
            _isExplicitShutdown = true;
            Close();
        }

        private void ShowTrayNotification(string title, string message)
        {
            try
            {
                var preview = message.Length > 180 ? message[..177] + "..." : message;
                MyNotifyIcon.ShowBalloonTip(title, preview, BalloonIcon.Warning);
            }
            catch (Exception ex)
            {
                LogService.Error("Tray notification failed", ex);
            }
        }

        protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
        {
            if (!_isExplicitShutdown)
            {
                e.Cancel = true;
                Hide();
            }
            else
            {
                MyNotifyIcon.Dispose();
                _viewModel.Dispose();
                base.OnClosing(e);
            }
        }
    }
}

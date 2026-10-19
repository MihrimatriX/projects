using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
using DosyaSifreleme.ViewModels;

namespace DosyaSifreleme;

public partial class MainWindow : Window
{
    private readonly DispatcherTimer _countdownTimer;
    private int _secondsRemaining;

    public MainWindow()
    {
        InitializeComponent();
        DataContext = new MainViewModel();

        // Otomatik kilit: fare/klavye hareketi sayacı sıfırlar; süre dolunca kasa kapatılır ve anahtar bellekten silinir.
        _countdownTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
        _countdownTimer.Tick += (_, _) => TickCountdown();

        KeyDown += OnKeyDown;
        PreviewMouseMove += (_, _) => ResetIdle();
        PreviewKeyDown += (_, _) => ResetIdle();

        if (DataContext is MainViewModel vm)
        {
            vm.PropertyChanged += (_, args) =>
            {
                if (args.PropertyName != nameof(MainViewModel.CurrentViewModel)) return;
                if (vm.CurrentViewModel is DashboardViewModel dash)
                {
                    dash.AutoLockChanged += ResetIdle;
                    ResetIdle();
                    _countdownTimer.Start();
                }
                else
                {
                    _countdownTimer.Stop();
                }
            };
        }
    }

    private void TickCountdown()
    {
        if (DataContext is not MainViewModel vm || vm.ActiveDashboard is not DashboardViewModel dash) return;

        _secondsRemaining--;
        dash.UpdateAutoLock(_secondsRemaining);

        if (_secondsRemaining <= 0)
            LockVault("Boşta kalma süresi doldu, kasa otomatik kilitlendi.");
    }

    private void ResetIdle()
    {
        if (DataContext is not MainViewModel vm || vm.CurrentViewModel is not DashboardViewModel dash) return;

        _secondsRemaining = vm.Settings.AutoLockSeconds;
        dash.UpdateAutoLock(_secondsRemaining);
    }

    private void LockVault(string reason)
    {
        _countdownTimer.Stop();

        if (DataContext is not MainViewModel vm || vm.CurrentViewModel is not DashboardViewModel) return;

        vm.NavigateToLogin();
        vm.LoginVM.InfoMessage = reason;
    }

    private void OnKeyDown(object sender, KeyEventArgs e)
    {
        if (DataContext is not MainViewModel vm || vm.ActiveDashboard is not DashboardViewModel dash) return;

        if (e.Key == Key.L && Keyboard.Modifiers == ModifierKeys.Control)
        {
            LockVault("Kasa kilitlendi.");
            e.Handled = true;
        }
        else if (e.Key == Key.Escape && dash.IsExportDialogOpen && !dash.IsExporting)
        {
            dash.CancelExportCommand.Execute(null);
            e.Handled = true;
        }
        else if (dash.IsExportDialogOpen)
        {
            // Onay katmanı açıkken arkadaki liste kısayolları çalışmaz.
        }
        else if (e.Key == Key.O && Keyboard.Modifiers == ModifierKeys.Control)
        {
            dash.AddFileCommand.Execute(null);
            e.Handled = true;
        }
        else if (e.Key == Key.Delete && Keyboard.Modifiers == ModifierKeys.None
                 && e.OriginalSource is not System.Windows.Controls.TextBox)
        {
            dash.DeleteFileCommand.Execute(null);
            e.Handled = true;
        }
    }
}

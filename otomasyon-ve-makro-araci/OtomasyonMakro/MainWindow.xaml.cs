using System;
using System.ComponentModel;
using System.Windows;
using System.Windows.Input;
using OtomasyonMakro.ViewModels;

namespace OtomasyonMakro
{
    public partial class MainWindow : Window
    {
        private RecordOverlayWindow? _overlay;
        private HotkeysWindow? _hotkeys;

        public MainWindow()
        {
            InitializeComponent();
            Loaded += OnLoaded;
            KeyDown += OnKeyDown;
        }

        private void OnLoaded(object sender, RoutedEventArgs e)
        {
            if (DataContext is not MainViewModel vm) return;

            vm.PropertyChanged += (_, args) =>
            {
                if (args.PropertyName == nameof(MainViewModel.IsRecording))
                    SyncRecordOverlay(vm);
                if (args.PropertyName == nameof(MainViewModel.ShowHotkeysWindow))
                    SyncHotkeysWindow(vm);
            };
        }

        private void SyncRecordOverlay(MainViewModel vm)
        {
            if (vm.IsRecording)
            {
                _overlay ??= new RecordOverlayWindow { DataContext = vm, Owner = this };
                _overlay.Show();
            }
            else
            {
                _overlay?.Hide();
            }
        }

        private void SyncHotkeysWindow(MainViewModel vm)
        {
            if (vm.ShowHotkeysWindow)
            {
                if (_hotkeys == null)
                {
                    _hotkeys = new HotkeysWindow
                    {
                        DataContext = vm,
                        Owner = this
                    };
                    _hotkeys.Closed += (_, _) =>
                    {
                        // Kapanmış Window tekrar Show() edilemez; sonraki açılışta yenisi oluşturulur
                        _hotkeys = null;
                        vm.ShowHotkeysWindow = false;
                    };
                }

                _hotkeys.Show();
                _hotkeys.Activate();
            }
            else
            {
                _hotkeys?.Hide();
            }
        }

        private void OnKeyDown(object sender, KeyEventArgs e)
        {
            if (DataContext is not MainViewModel vm) return;
            if (e.OriginalSource is System.Windows.Controls.TextBox) return;

            if (e.Key == Key.F5 && Keyboard.Modifiers == ModifierKeys.None)
            {
                if (!vm.IsPlaying && vm.PlayMacroCommand.CanExecute(null))
                {
                    vm.PlayMacroCommand.Execute(null);
                    e.Handled = true;
                }
            }
            else if (e.Key == Key.F5 && Keyboard.Modifiers == ModifierKeys.Shift)
            {
                if (vm.StepForwardCommand.CanExecute(null))
                {
                    vm.StepForwardCommand.Execute(null);
                    e.Handled = true;
                }
            }
            else if (e.Key == Key.Escape)
            {
                if (vm.IsPlaying) vm.StopPlaybackCommand.Execute(null);
                else if (vm.IsRecording) vm.StopRecordCommand.Execute(null);
                e.Handled = true;
            }
            else if (e.Key == Key.S && Keyboard.Modifiers == ModifierKeys.Control)
            {
                vm.SaveProfileCommand.Execute(null);
                e.Handled = true;
            }
        }

        protected override void OnClosing(CancelEventArgs e)
        {
            if (DataContext is not MainViewModel vm) { base.OnClosing(e); return; }

            if (vm.IsRecording)
                vm.StopRecord(); // kayıt sürerken kapatılırsa kaydedilen adımlar kaybolmasın (StopRecord kaydeder)

            if (vm.HasUnsavedChanges())
            {
                var answer = MessageBox.Show("Kaydedilmemiş makro değişiklikleri var. Kaydedilsin mi?",
                    "Otomasyon ve Makro Aracı", MessageBoxButton.YesNoCancel, MessageBoxImage.Question);
                if (answer == MessageBoxResult.Cancel) { e.Cancel = true; return; }
                if (answer == MessageBoxResult.Yes)
                {
                    try { vm.SaveAll(); }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Kaydetme hatası: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
                        e.Cancel = true;
                        return;
                    }
                }
            }
            base.OnClosing(e);
        }

        protected override void OnClosed(EventArgs e)
        {
            if (DataContext is MainViewModel vm)
                vm.Cleanup();

            _overlay?.Close();
            _hotkeys?.Close();
            base.OnClosed(e);
        }
    }
}

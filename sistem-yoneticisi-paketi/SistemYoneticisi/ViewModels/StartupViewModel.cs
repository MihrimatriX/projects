using System;
using System.Collections.ObjectModel;
using System.Windows;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using SistemYoneticisi.Services;

namespace SistemYoneticisi.ViewModels
{
    public partial class StartupViewModel : ObservableObject
    {
        private readonly StartupService _startupService;
        private readonly MainViewModel _mainVm;

        public ObservableCollection<StartupItem> StartupItems { get; } = new();

        [ObservableProperty]
        private StartupItem? _selectedItem;

        [ObservableProperty]
        private bool _canUndo;

        public StartupViewModel(StartupService startupService, MainViewModel mainVm)
        {
            _startupService = startupService;
            _mainVm = mainVm;
            RefreshItems();
        }

        [RelayCommand]
        private void Refresh()
        {
            RefreshItems();
            _mainVm.StatusMessage = $"{StartupItems.Count} başlangıç öğesi listelendi";
        }

        [RelayCommand]
        private void Remove()
        {
            var item = SelectedItem;
            if (item == null) return;

            var result = MessageBox.Show(
                $"'{item.Name}' başlangıç listesinden kaldırılsın mı?\n\nKonum: {item.Location}\n\nÖğe yedeklenir; \"Geri Al\" ile geri yükleyebilirsiniz.",
                "Başlangıçtan Kaldır",
                MessageBoxButton.YesNo,
                MessageBoxImage.Warning,
                MessageBoxResult.No);

            if (result != MessageBoxResult.Yes) return;

            if (_startupService.RemoveStartupItem(item))
            {
                StartupItems.Remove(item);
                SelectedItem = null;
                CanUndo = true;
                _mainVm.StatusMessage = $"Başlangıçtan kaldırıldı: {item.Name} (Geri Al ile geri yüklenebilir)";
            }
            else
            {
                _mainVm.StatusMessage = item.IsCurrentUser
                    ? $"Kaldırılamadı: {item.Name}"
                    : $"Kaldırılamadı: {item.Name} (sistem geneli öğe — yönetici gerekir)";
            }
        }

        [RelayCommand]
        private void Undo()
        {
            var name = _startupService.RestoreLastRemoved();
            RefreshItems();
            _mainVm.StatusMessage = name != null
                ? $"Başlangıca geri yüklendi: {name}"
                : "Geri yüklenemedi (aynı adlı öğe var ya da yönetici gerekir)";
        }

        private void RefreshItems()
        {
            var list = _startupService.GetStartupItems();
            StartupItems.Clear();
            foreach (var item in list)
            {
                StartupItems.Add(item);
            }
            CanUndo = _startupService.HasRemovedItems;
        }
    }
}

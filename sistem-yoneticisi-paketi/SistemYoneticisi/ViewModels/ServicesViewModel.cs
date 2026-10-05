using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Windows;
using System.Windows.Data;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using SistemYoneticisi.Services;

namespace SistemYoneticisi.ViewModels
{
    public partial class ServicesViewModel : ObservableObject
    {
        private readonly ServiceManagerService _service;
        private readonly MainViewModel _mainVm;
        private readonly ObservableCollection<WindowsServiceInfo> _allServices = new();

        [ObservableProperty]
        private string _searchText = string.Empty;

        [ObservableProperty]
        private WindowsServiceInfo? _selectedService;

        public ICollectionView FilteredServices { get; }

        public ServicesViewModel(ServiceManagerService service, MainViewModel mainVm)
        {
            _service = service;
            _mainVm = mainVm;

            FilteredServices = CollectionViewSource.GetDefaultView(_allServices);
            FilteredServices.Filter = FilterServices;
            FilteredServices.SortDescriptions.Add(new SortDescription("DisplayName", ListSortDirection.Ascending));

            RefreshServices();
        }

        [RelayCommand]
        private void Refresh()
        {
            RefreshServices();
            _mainVm.StatusMessage = $"{_allServices.Count} servis listelendi";
        }

        [RelayCommand]
        private void Start()
        {
            var svc = SelectedService;
            if (svc == null || svc.IsRunning) return;

            var name = svc.DisplayName;
            bool success = _service.StartService(svc.Name);
            if (success) RefreshServices();
            _mainVm.StatusMessage = success ? $"Servis başlatıldı: {name}" : $"Servis başlatılamadı: {name} (yönetici gerekebilir)";
        }

        [RelayCommand]
        private void Stop()
        {
            var svc = SelectedService;
            if (svc == null || !svc.IsRunning || BlockIfCritical(svc)) return;
            if (!Confirm($"'{svc.DisplayName}' servisi durdurulsun mu?", "Servisi Durdur")) return;

            var name = svc.DisplayName;
            bool success = _service.StopService(svc.Name);
            if (success) RefreshServices();
            _mainVm.StatusMessage = success ? $"Servis durduruldu: {name}" : $"Servis durdurulamadı: {name} (yönetici gerekebilir)";
        }

        [RelayCommand]
        private void Restart()
        {
            var svc = SelectedService;
            if (svc == null || BlockIfCritical(svc)) return;
            if (!Confirm($"'{svc.DisplayName}' servisi yeniden başlatılsın mı?", "Servisi Yeniden Başlat")) return;

            var name = svc.DisplayName;
            bool success = _service.RestartService(svc.Name);
            if (success) RefreshServices();
            _mainVm.StatusMessage = success ? $"Servis yeniden başlatıldı: {name}" : $"Servis yeniden başlatılamadı: {name} (yönetici gerekebilir)";
        }

        private bool BlockIfCritical(WindowsServiceInfo svc)
        {
            if (!svc.IsCritical) return false;
            _mainVm.StatusMessage = $"'{svc.DisplayName}' sistem için kritik bir servis; durdurma/yeniden başlatma engellendi.";
            return true;
        }

        private static bool Confirm(string message, string title) =>
            MessageBox.Show(message, title, MessageBoxButton.YesNo, MessageBoxImage.Warning, MessageBoxResult.No)
                == MessageBoxResult.Yes;

        private void RefreshServices()
        {
            string? selectedName = SelectedService?.Name;

            var list = _service.GetServices();
            _allServices.Clear();
            foreach (var item in list)
            {
                _allServices.Add(item);
            }

            if (selectedName != null)
            {
                SelectedService = _allServices.FirstOrDefault(x => x.Name == selectedName);
            }

            FilteredServices.Refresh();
        }

        private bool FilterServices(object obj)
        {
            if (obj is not WindowsServiceInfo info) return false;
            if (string.IsNullOrWhiteSpace(SearchText)) return true;

            string query = SearchText.Trim();
            return info.DisplayName.Contains(query, StringComparison.OrdinalIgnoreCase) ||
                   info.Name.Contains(query, StringComparison.OrdinalIgnoreCase);
        }

        partial void OnSearchTextChanged(string value)
        {
            FilteredServices.Refresh();
        }
    }
}

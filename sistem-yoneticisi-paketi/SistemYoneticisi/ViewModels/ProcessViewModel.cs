using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Windows;
using System.Windows.Data;
using System.Windows.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using SistemYoneticisi.Services;

namespace SistemYoneticisi.ViewModels
{
    public partial class ProcessViewModel : ObservableObject
    {
        private readonly ProcessService _processService;
        private readonly MainViewModel _mainVm;
        private readonly DispatcherTimer _timer;
        private readonly ObservableCollection<ProcessInfo> _allProcesses = new();

        [ObservableProperty]
        private string _searchText = string.Empty;

        [ObservableProperty]
        private ProcessInfo? _selectedProcess;

        [ObservableProperty]
        private bool _canKillSelected;

        [ObservableProperty]
        private int _totalProcessCount;

        public ICollectionView FilteredProcesses { get; }

        public ProcessViewModel(ProcessService processService, MainViewModel mainVm)
        {
            _processService = processService;
            _mainVm = mainVm;

            // Setup collection view for filtering and sorting
            FilteredProcesses = CollectionViewSource.GetDefaultView(_allProcesses);
            FilteredProcesses.Filter = FilterProcesses;
            FilteredProcesses.SortDescriptions.Add(new SortDescription("CpuPercentage", ListSortDirection.Descending));

            // Refresh timer (every 3 seconds)
            _timer = new DispatcherTimer
            {
                Interval = TimeSpan.FromSeconds(3)
            };
            _timer.Tick += Timer_Tick;
            _timer.Start();

            // Initial load
            RefreshProcesses();
        }

        private void Timer_Tick(object? sender, EventArgs e)
        {
            // Pause auto-refreshing if a process is selected to prevent focus losses
            if (SelectedProcess == null)
            {
                RefreshProcesses();
            }
        }

        [RelayCommand]
        private void Refresh()
        {
            RefreshProcesses();
            _mainVm.StatusMessage = $"{TotalProcessCount} süreç listelendi";
        }

        [RelayCommand]
        private void KillProcess()
        {
            if (SelectedProcess == null || SelectedProcess.IsProtected) return;

            var result = MessageBox.Show(
                $"'{SelectedProcess.Name}' (PID {SelectedProcess.Pid}) sonlandırılsın mı?\n\nAlt süreçler de kapatılır.",
                "Süreç Sonlandır",
                MessageBoxButton.YesNo,
                MessageBoxImage.Warning,
                MessageBoxResult.No);

            if (result != MessageBoxResult.Yes) return;

            bool success = _processService.KillProcess(SelectedProcess.Pid);
            if (success)
            {
                var killed = SelectedProcess;
                _allProcesses.Remove(killed);
                SelectedProcess = null;
                TotalProcessCount = _allProcesses.Count;
                _mainVm.StatusMessage = $"Süreç sonlandırıldı: {killed.Name} (PID {killed.Pid})";
            }
            else
            {
                _mainVm.StatusMessage = $"Süreç sonlandırılamadı: {SelectedProcess.Name}";
            }
        }

        [RelayCommand]
        private void ExportCsv()
        {
            var dlg = new Microsoft.Win32.SaveFileDialog
            {
                Title = "Süreç listesini dışa aktar",
                Filter = "CSV dosyası (*.csv)|*.csv",
                FileName = $"surecler-{DateTime.Now:yyyyMMdd-HHmm}.csv"
            };
            if (dlg.ShowDialog() != true) return;

            try
            {
                // Görünen (filtrelenmiş + sıralı) liste aktarılır; BOM ile Excel Türkçe karakterleri doğru açar.
                var csv = ProcessService.ToCsv(FilteredProcesses.Cast<ProcessInfo>());
                System.IO.File.WriteAllText(dlg.FileName, csv, new System.Text.UTF8Encoding(true));
                _mainVm.StatusMessage = $"Süreç listesi kaydedildi: {dlg.FileName}";
            }
            catch (Exception ex)
            {
                LogService.Error("Process CSV export failed", ex);
                _mainVm.StatusMessage = $"Dışa aktarılamadı: {ex.Message}";
            }
        }

        private void RefreshProcesses()
        {
            // Hold selected ID to restore selection after refresh
            int? selectedPid = SelectedProcess?.Pid;

            var rawList = _processService.GetProcesses();
            
            // Sync the collection without resetting completely to prevent scroll glitches
            // 1. Remove exited processes
            var currentPids = new HashSet<int>(rawList.Select(x => x.Pid));
            for (int i = _allProcesses.Count - 1; i >= 0; i--)
            {
                if (!currentPids.Contains(_allProcesses[i].Pid))
                {
                    _allProcesses.RemoveAt(i);
                }
            }

            // 2. Add or update active processes
            foreach (var raw in rawList)
            {
                var existing = _allProcesses.FirstOrDefault(x => x.Pid == raw.Pid);
                if (existing != null)
                {
                    existing.CpuPercentage = raw.CpuPercentage;
                    existing.MemoryMb = raw.MemoryMb;
                }
                else
                {
                    _allProcesses.Add(raw);
                }
            }

            TotalProcessCount = _allProcesses.Count;

            // Restore selection if process is still active
            if (selectedPid.HasValue)
            {
                SelectedProcess = _allProcesses.FirstOrDefault(x => x.Pid == selectedPid.Value);
            }

            FilteredProcesses.Refresh();
        }

        private bool FilterProcesses(object obj)
        {
            if (obj is not ProcessInfo info) return false;
            if (string.IsNullOrWhiteSpace(SearchText)) return true;

            string query = SearchText.Trim();
            return info.Name.Contains(query, StringComparison.OrdinalIgnoreCase) ||
                   info.Pid.ToString().Contains(query) ||
                   info.Description.Contains(query, StringComparison.OrdinalIgnoreCase);
        }

        partial void OnSelectedProcessChanged(ProcessInfo? value)
        {
            CanKillSelected = value?.CanKill == true;
        }

        partial void OnSearchTextChanged(string value)
        {
            FilteredProcesses.Refresh();
        }
    }
}

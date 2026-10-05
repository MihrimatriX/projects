using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Windows.Data;
using System.Windows.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using SistemYoneticisi.Services;

namespace SistemYoneticisi.ViewModels;

public partial class NetworkViewModel : ObservableObject
{
    private readonly NetworkConnectionService _network;
    private readonly MainViewModel _mainVm;
    private readonly DispatcherTimer _timer;
    private readonly ObservableCollection<NetworkConnectionInfo> _allConnections = new();

    [ObservableProperty]
    private string _searchText = string.Empty;

    [ObservableProperty]
    private bool _showEstablishedOnly;

    [ObservableProperty]
    private int _connectionCount;

    public ICollectionView FilteredConnections { get; }

    public NetworkViewModel(NetworkConnectionService network, MainViewModel mainVm)
    {
        _network = network;
        _mainVm = mainVm;

        FilteredConnections = CollectionViewSource.GetDefaultView(_allConnections);
        FilteredConnections.Filter = FilterConnections;

        _timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(5) };
        _timer.Tick += (_, _) => RefreshConnections();
        _timer.Start();

        RefreshConnections();
    }

    [RelayCommand]
    private void Refresh()
    {
        RefreshConnections();
        _mainVm.StatusMessage = $"{ConnectionCount} ağ bağlantısı listelendi";
    }

    private void RefreshConnections()
    {
        var list = _network.GetConnections();
        _allConnections.Clear();
        foreach (var item in list)
            _allConnections.Add(item);

        ConnectionCount = _allConnections.Count;
        FilteredConnections.Refresh();
    }

    private bool FilterConnections(object obj)
    {
        if (obj is not NetworkConnectionInfo info) return false;

        if (ShowEstablishedOnly && info.State != "ESTABLISHED")
            return false;

        if (string.IsNullOrWhiteSpace(SearchText)) return true;

        var q = SearchText.Trim();
        return info.ProcessName.Contains(q, StringComparison.OrdinalIgnoreCase) ||
               info.LocalAddress.Contains(q, StringComparison.OrdinalIgnoreCase) ||
               info.RemoteAddress.Contains(q, StringComparison.OrdinalIgnoreCase) ||
               info.Pid.ToString().Contains(q);
    }

    partial void OnSearchTextChanged(string value) => FilteredConnections.Refresh();
    partial void OnShowEstablishedOnlyChanged(bool value) => FilteredConnections.Refresh();
}

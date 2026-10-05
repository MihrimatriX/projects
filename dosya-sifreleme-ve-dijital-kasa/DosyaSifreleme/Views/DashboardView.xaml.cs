using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using DosyaSifreleme.ViewModels;

namespace DosyaSifreleme.Views;

public partial class DashboardView : UserControl
{
    private Window? _host;

    public DashboardView() => InitializeComponent();

    // Kısayollar pencere düzeyinde: odak hiçbir öğede değilken (ör. diyalog kapandıktan sonra) de çalışır.
    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        _host = Window.GetWindow(this);
        if (_host != null) _host.PreviewKeyDown += OnPreviewKeyDown;
        FileList.Focus();
    }

    private void OnUnloaded(object sender, RoutedEventArgs e)
    {
        if (_host != null) _host.PreviewKeyDown -= OnPreviewKeyDown;
        _host = null;
    }

    private void OnPreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (DataContext is not DashboardViewModel vm || vm.IsExportDialogOpen) return;

        if (e.Key == Key.F && Keyboard.Modifiers == ModifierKeys.Control)
        {
            SearchBox.Focus();
            SearchBox.SelectAll();
            e.Handled = true;
        }
        else if (e.Key == Key.Escape && SearchBox.IsKeyboardFocusWithin && vm.SearchText.Length > 0)
        {
            vm.SearchText = string.Empty;
            e.Handled = true;
        }
        else if (e.Key == Key.Down && SearchBox.IsKeyboardFocusWithin && FileList.Items.Count > 0)
        {
            FileList.SelectedIndex = Math.Max(0, FileList.SelectedIndex);
            (FileList.ItemContainerGenerator.ContainerFromIndex(FileList.SelectedIndex) as ListBoxItem)?.Focus();
            e.Handled = true;
        }
        else if (e.Key == Key.Enter && FileList.IsKeyboardFocusWithin && vm.SelectedFile != null
                 && e.OriginalSource is not Button)
        {
            vm.RequestExportCommand.Execute(null);
            e.Handled = true;
        }
    }

    private void OnDragOver(object sender, DragEventArgs e)
    {
        if (e.Data.GetDataPresent(DataFormats.FileDrop))
        {
            e.Effects = DragDropEffects.Copy;
            e.Handled = true;
        }
    }

    private void OnDrop(object sender, DragEventArgs e)
    {
        if (!e.Data.GetDataPresent(DataFormats.FileDrop)) return;
        if (DataContext is DashboardViewModel vm)
            vm.DragDropAddCommand.Execute((string[])e.Data.GetData(DataFormats.FileDrop));
    }
}

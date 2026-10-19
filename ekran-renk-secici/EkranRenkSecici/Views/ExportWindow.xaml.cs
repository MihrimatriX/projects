using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using EkranRenkSecici.Helpers;
using EkranRenkSecici.Models;

namespace EkranRenkSecici.Views;

public partial class ExportWindow : Window
{
    private readonly Color _color;
    private readonly string[] _exports;
    private int _activeTab;

    public ExportWindow(Color color)
    {
        InitializeComponent();
        _color = color;
        _exports =
        [
            ColorHelper.ExportTailwind(color),
            ColorHelper.ExportFigma(color),
            ColorHelper.ExportCssVariables(color)
        ];

        var hex = ColorHelper.ToHex(color);
        BadgeDot.Background = new SolidColorBrush(color);
        BadgeHex.Text = hex;

        PalettePreview.ItemsSource = ColorHelper.GetExportPalette(color)
            .Select(c => new ColorItem(c))
            .ToList();

        SetActiveTab(0);
    }

    private void Tab_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button btn && int.TryParse(btn.Tag?.ToString(), out var idx))
            SetActiveTab(idx);
    }

    private void SetActiveTab(int index)
    {
        _activeTab = index;
        ExportText.Text = _exports[index];

        var tabs = new[] { TabTailwind, TabFigma, TabCss };
        for (var i = 0; i < tabs.Length; i++)
        {
            var active = i == index;
            tabs[i].Foreground = active
                ? (Brush)FindResource("TextBrush")
                : (Brush)FindResource("SubTextBrush");
            tabs[i].BorderBrush = active
                ? (Brush)FindResource("AccentBrush")
                : Brushes.Transparent;
        }
    }

    private void Copy_Click(object sender, RoutedEventArgs e)
    {
        try { Clipboard.SetText(_exports[_activeTab]); } catch { /* busy */ }
        DialogResult = true;
    }
}

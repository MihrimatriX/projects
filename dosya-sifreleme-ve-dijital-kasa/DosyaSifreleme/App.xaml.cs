using System.Windows;

namespace DosyaSifreleme;

public partial class App : Application
{
    // Diyaloglar ana pencereye bağlı açılır: uygulama ön planda değilken bile pencerenin arkasında kalmaz.
    internal static Window Owner => Current.MainWindow;
}

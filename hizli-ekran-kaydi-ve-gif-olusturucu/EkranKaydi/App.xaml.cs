using System.IO;
using System.Windows;
using EkranKaydi.Services;

namespace EkranKaydi;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        // Yakalanmayan hata: sessizce çökmek yerine mesaj + crash.log; ana pencere hiç açılamadıysa kapan.
        DispatcherUnhandledException += (_, args) =>
        {
            try
            {
                Directory.CreateDirectory(AppPaths.DataFolder);
                File.AppendAllText(Path.Combine(AppPaths.DataFolder, "crash.log"), $"[{DateTime.Now:u}] {args.Exception}\n\n");
            }
            catch { /* log yazılamazsa mesaj yine gösterilir */ }

            MessageBox.Show($"Beklenmeyen hata: {args.Exception.Message}\n\nAyrıntılar: {Path.Combine(AppPaths.DataFolder, "crash.log")}",
                "Hızlı Ekran Kaydı", MessageBoxButton.OK, MessageBoxImage.Error);
            args.Handled = true;
            if (MainWindow is not { IsLoaded: true }) Shutdown(1);
        };
        base.OnStartup(e);
    }
}

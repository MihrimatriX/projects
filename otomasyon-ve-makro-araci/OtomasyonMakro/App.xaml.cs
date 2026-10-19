using System;
using System.IO;
using System.Windows;
using OtomasyonMakro.Services;

namespace OtomasyonMakro;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        // Yakalanmayan hata: sessizce çökmek yerine mesaj + crash.log; ana pencere hiç açılamadıysa kapan.
        DispatcherUnhandledException += (_, args) =>
        {
            var log = Path.Combine(DatabaseService.ResolveDataFolder(), "crash.log");
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(log)!);
                File.AppendAllText(log, $"[{DateTime.Now:u}] {args.Exception}\n\n");
            }
            catch { /* log yazılamazsa mesaj yine gösterilir */ }

            MessageBox.Show($"Beklenmeyen hata: {args.Exception.Message}\n\nAyrıntılar: {log}",
                "Otomasyon ve Makro Aracı", MessageBoxButton.OK, MessageBoxImage.Error);
            args.Handled = true;
            if (MainWindow is not { IsLoaded: true }) Shutdown(1);
        };
        base.OnStartup(e);
    }
}

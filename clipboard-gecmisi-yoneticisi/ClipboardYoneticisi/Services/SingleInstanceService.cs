using System;
using System.Threading;
using System.Windows;

namespace ClipboardYoneticisi.Services
{
    public sealed class SingleInstanceService : IDisposable
    {
        // Gecici veri klasoruyle (test) calisan ornek, kullanicinin gercek ornegiyle cakismasin.
        private static string MutexName => AppPaths.IsDataDirOverridden
            ? "Global\\ClipboardGecmisiYoneticisi_" + Convert.ToHexString(
                System.Security.Cryptography.SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(AppPaths.DataFolder.ToUpperInvariant())))[..16]
            : "Global\\ClipboardGecmisiYoneticisi_SingleInstance";
        private readonly Mutex _mutex;
        public bool IsFirstInstance { get; }

        public SingleInstanceService()
        {
            _mutex = new Mutex(true, MutexName, out bool createdNew);
            IsFirstInstance = createdNew;

            if (!IsFirstInstance)
            {
                MessageBox.Show(
                    "Clipboard Geçmişi Yöneticisi zaten çalışıyor.\nSistem tepsisindeki simgeye bakın.",
                    "Zaten açık",
                    MessageBoxButton.OK,
                    MessageBoxImage.Information);
            }
        }

        public void Dispose() => _mutex.Dispose();
    }
}

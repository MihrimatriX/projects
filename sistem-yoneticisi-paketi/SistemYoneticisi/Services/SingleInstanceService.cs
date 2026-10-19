using System;
using System.Threading;
using System.Windows;

namespace SistemYoneticisi.Services;

public sealed class SingleInstanceService : IDisposable
{
    private const string MutexName = "Global\\SistemYoneticisiPaketi_SingleInstance";
    private readonly Mutex _mutex;
    public bool IsFirstInstance { get; }

    public SingleInstanceService()
    {
        // Adlandırılmış mutex'i ilk oluşturan süreç tek örnektir; uygulama kapanana kadar tutulur.
        _mutex = new Mutex(true, MutexName, out bool createdNew);
        IsFirstInstance = createdNew;

        if (!IsFirstInstance)
        {
            MessageBox.Show(
                "Sistem Yöneticisi Paketi zaten çalışıyor.\nSistem tepsisindeki simgeye bakın.",
                "Zaten açık",
                MessageBoxButton.OK,
                MessageBoxImage.Information);
        }
    }

    public void Dispose() => _mutex.Dispose();
}

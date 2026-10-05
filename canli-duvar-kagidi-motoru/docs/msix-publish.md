# MSIX yayın notları

## Gereksinimler

- Windows 10/11 SDK (Windows App SDK projesi ile gelir)
- Visual Studio 2022 veya `dotnet publish` ile MSIX oluşturma

## Debug / geliştirme

```powershell
dotnet run --project src\CanliDuvarKagidi.Shell -p:Platform=x64
```

WinApp SDK `dotnet run` paket kimliği ile debug başlatır.

## Release MSIX (imzasız — geliştirme)

```powershell
dotnet publish src\CanliDuvarKagidi.Shell `
  -c Release `
  -p:Platform=x64 `
  -p:GenerateAppxPackageOnBuild=true `
  -p:AppxPackageSigningEnabled=false
```

Çıktı: `src\CanliDuvarKagidi.Shell\AppPackages\`

## Production imzalama

1. `.pfx` sertifikası oluşturun veya EV code signing sertifikası kullanın
2. `Package.appxmanifest` publisher değerini sertifikayla eşleştirin
3. `-p:AppxPackageSigningEnabled=true -p:PackageCertificateKeyFile=...` ile publish edin

## Dağıtım alternatifi

MSIX dışında klasik kurulum için Release klasörünü (`win-x64\publish`) Inno Setup veya benzeri ile paketleyebilirsiniz. WebView2 Fixed Runtime bootstrapper eklemeyi unutmayın.

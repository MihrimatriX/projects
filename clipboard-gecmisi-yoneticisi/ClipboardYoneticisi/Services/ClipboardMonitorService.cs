using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.IO;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media.Imaging;
using ClipboardYoneticisi.Helpers;

namespace ClipboardYoneticisi.Services
{
    public class ClipboardMonitorService
    {
        private readonly DatabaseService _dbService;
        private IntPtr _hwnd;
        private bool _ignoreNextChange;

        public event EventHandler? ClipboardChanged;

        public ClipboardMonitorService(DatabaseService dbService)
        {
            _dbService = dbService;
        }

        public void AddHook(Window window)
        {
            var helper = new WindowInteropHelper(window);
            _hwnd = helper.EnsureHandle();

            HwndSource source = HwndSource.FromHwnd(_hwnd);
            source.AddHook(HwndHandler);

            // Pano dinleme: AddClipboardFormatListener ile pano her degistiginde pencereye
            // WM_CLIPBOARDUPDATE gelir (UI thread'inde). Kendi kopyalamamizin tetikledigi
            // guncelleme _ignoreNextChange ile atlanir, aksi halde gecmise tekrar yazilirdi.
            Win32Api.AddClipboardFormatListener(_hwnd);
        }

        public void RemoveHook()
        {
            if (_hwnd != IntPtr.Zero)
            {
                Win32Api.RemoveClipboardFormatListener(_hwnd);
                _hwnd = IntPtr.Zero;
            }
        }

        // Parola yoneticileri (KeePass, 1Password, Bitwarden...) bu bicimle "izleyiciler kaydetmesin" der.
        internal const string ExcludeFormat = "ExcludeClipboardContentFromMonitorProcessing";
        // UI testleri panoya bu bicimi de ekler: kullanicinin gercek ornegi test verisini kaydetmez,
        // test ornegi (AppPaths.IsTestMode) ise yalnizca bunu kaydeder.
        internal const string TestMarkerFormat = "ClipboardGecmisiYoneticisi.Test";

        internal static bool ShouldSkip(IDataObject? data, bool testMode) =>
            data != null &&
            (data.GetDataPresent(ExcludeFormat) || data.GetDataPresent(TestMarkerFormat) != testMode);

        private IntPtr HwndHandler(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            if (msg == Win32Api.WM_CLIPBOARDUPDATE)
            {
                if (_ignoreNextChange)
                    _ignoreNextChange = false;
                else
                    ProcessClipboardChange();
            }
            return IntPtr.Zero;
        }

        private void ProcessClipboardChange()
        {
            if (SensitiveAppGuard.ShouldIgnoreClipboard())
                return;

            try
            {
                if (ShouldSkip(Clipboard.GetDataObject(), AppPaths.IsTestMode))
                    return;

                if (Clipboard.ContainsFileDropList())
                {
                    SaveFiles();
                    return;
                }

                if (Clipboard.ContainsImage())
                {
                    SaveImage();
                    return;
                }

                if (Clipboard.ContainsData(DataFormats.Html))
                {
                    var html = Clipboard.GetData(DataFormats.Html) as string;
                    if (!string.IsNullOrWhiteSpace(html))
                    {
                        if (RegexFilterService.ShouldBlock(html))
                            return;

                        _dbService.SaveItem("Html", html);
                        ClipboardChanged?.Invoke(this, EventArgs.Empty);
                        return;
                    }
                }

                if (Clipboard.ContainsText())
                {
                    var text = Clipboard.GetText();
                    if (!string.IsNullOrWhiteSpace(text))
                    {
                        _dbService.SaveItem("Text", text);
                        ClipboardChanged?.Invoke(this, EventArgs.Empty);
                    }
                }
            }
            catch (Exception ex)
            {
                LogService.Warning($"Clipboard capture failed: {ex.GetType().Name}: {ex.Message}");
            }
        }

        private void SaveFiles()
        {
            var files = Clipboard.GetFileDropList();
            if (files == null || files.Count == 0)
                return;

            var filePaths = new List<string>();
            foreach (string? file in files)
            {
                if (!string.IsNullOrEmpty(file))
                    filePaths.Add(file);
            }

            if (filePaths.Count == 0)
                return;

            var content = string.Join(Environment.NewLine, filePaths);
            _dbService.SaveItem("File", content);
            ClipboardChanged?.Invoke(this, EventArgs.Empty);
        }

        private void SaveImage()
        {
            var image = Clipboard.GetImage();
            if (image == null)
                return;

            var encoder = new PngBitmapEncoder();
            encoder.Frames.Add(BitmapFrame.Create(image));
            using var png = new MemoryStream();
            encoder.Save(png);
            var bytes = png.ToArray();

            // Icerige gore dosya adi: OLE panosu tek kopyalamada iki guncelleme gonderir (SetDataObject +
            // flush); rastgele adla her gorsel iki kez kaydediliyordu. Ayni gorsel = ayni yol = tek kayit.
            var imgPath = Path.Combine(_dbService.ImageFolder,
                Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(bytes))[..32].ToLowerInvariant() + ".png");
            var isNew = !File.Exists(imgPath);
            if (isNew)
                File.WriteAllBytes(imgPath, bytes);

            _dbService.SaveItem("Image", imgPath);
            ClipboardChanged?.Invoke(this, EventArgs.Empty);

            if (isNew && SettingsService.Instance.Settings.EnableOcr)
            {
                var itemId = _dbService.GetLastImageItemId();
                if (itemId != null)
                    _ = RunOcrAsync(itemId.Value, imgPath);
            }
        }

        private async Task RunOcrAsync(int itemId, string imgPath)
        {
            var ocrText = await OcrService.Instance.ExtractTextAsync(imgPath);
            if (string.IsNullOrWhiteSpace(ocrText))
                return;

            _dbService.UpdateOcrText(itemId, ocrText);
            App.Current.Dispatcher.Invoke(() => ClipboardChanged?.Invoke(this, EventArgs.Empty));
        }

        public void CopyToClipboard(string type, string content, TransformType transform = TransformType.None)
        {
            // Tek DataObject + tek SetDataObject: pano bir kez degisir (iki Set* cagrisi ikinci
            // guncellemeyle gecmise kopya kayit ekliyordu).
            try
            {
                var data = new DataObject();
                switch (type)
                {
                    case "Text":
                    case "Html":
                        var text = type == "Html"
                            ? HtmlClipboardHelper.ExtractPlainText(content)
                            : content;
                        text = SnippetTransform.Apply(text, transform);
                        if (type == "Html" && transform == TransformType.None)
                            data.SetData(DataFormats.Html, content);
                        data.SetText(text);
                        break;

                    case "File":
                        var collection = new StringCollection();
                        foreach (var path in content.Split(['\n', '\r'], StringSplitOptions.RemoveEmptyEntries))
                            collection.Add(path);
                        data.SetFileDropList(collection);
                        break;

                    case "Image":
                        if (!File.Exists(content))
                            return; // pano degismez
                        var bitmap = new BitmapImage();
                        bitmap.BeginInit();
                        bitmap.CacheOption = BitmapCacheOption.OnLoad;
                        bitmap.UriSource = new Uri(content);
                        bitmap.EndInit();
                        data.SetImage(bitmap);
                        break;

                    default:
                        return;
                }

                if (AppPaths.IsTestMode)
                {
                    // Test ornegi: kullanicinin gercek ornegi ve Windows pano gecmisi bu icerigi kaydetmesin.
                    data.SetData(TestMarkerFormat, "1");
                    data.SetData("CanIncludeInClipboardHistory", new MemoryStream(BitConverter.GetBytes(0)));
                }

                _ignoreNextChange = true;
                Clipboard.SetDataObject(data, true);
            }
            catch (Exception ex)
            {
                _ignoreNextChange = false; // pano degismedi; kullanicinin sonraki kopyasi atlanmasin
                LogService.Warning($"Clipboard write failed: {ex.GetType().Name}: {ex.Message}");
            }
        }
    }
}

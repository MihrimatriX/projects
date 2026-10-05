using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;

namespace ClipboardYoneticisi.Services
{
    public class ExportItemDto
    {
        public required string Type { get; set; }
        public required string Content { get; set; }
        public DateTime Timestamp { get; set; }
        public bool IsPinned { get; set; }
        public string? OcrText { get; set; }
        /// <summary>Gorsel ogeler icin PNG verisi (base64); yedek baska makinede/temizlikten sonra da acilsin.</summary>
        public string? ImageData { get; set; }
    }

    public class ExportBundle
    {
        public int Version { get; set; } = 2;
        public DateTime ExportedAt { get; set; } = DateTime.Now;
        public List<ExportItemDto> Items { get; set; } = [];
    }

    public class ExportImportService
    {
        private readonly DatabaseService _dbService;

        public ExportImportService(DatabaseService dbService)
        {
            _dbService = dbService;
        }

        public async Task<int> ExportToFileAsync(string filePath)
        {
            var items = _dbService.GetItems();
            var bundle = new ExportBundle
            {
                Items = items.ConvertAll(i => new ExportItemDto
                {
                    Type = i.Type,
                    Content = i.Content,
                    Timestamp = i.Timestamp,
                    IsPinned = i.IsPinned,
                    OcrText = i.OcrText,
                    ImageData = i.Type == "Image" && File.Exists(i.Content)
                        ? Convert.ToBase64String(File.ReadAllBytes(i.Content))
                        : null
                })
            };

            var json = JsonSerializer.Serialize(bundle, new JsonSerializerOptions { WriteIndented = true });
            await File.WriteAllTextAsync(filePath, json);
            return bundle.Items.Count;
        }

        public async Task<int> ImportFromFileAsync(string filePath, bool merge)
        {
            var json = await File.ReadAllTextAsync(filePath);
            ExportBundle? bundle;
            try
            {
                bundle = JsonSerializer.Deserialize<ExportBundle>(json);
            }
            catch (JsonException ex)
            {
                throw new InvalidDataException("Geçersiz yedek dosyası.", ex);
            }
            if (bundle?.Items == null)
                throw new InvalidDataException("Geçersiz yedek dosyası.");

            // Gorsel verilerini temizlikten ONCE diske yaz: ClearHistory ayni dosyalari silebilir.
            var items = new List<ExportItemDto>();
            foreach (var item in bundle.Items)
            {
                if (item.Type == "Image")
                {
                    var exists = File.Exists(item.Content);
                    var bytes = !string.IsNullOrEmpty(item.ImageData) ? Convert.FromBase64String(item.ImageData)
                        : exists ? await File.ReadAllBytesAsync(item.Content)
                        : null;
                    if (bytes == null)
                        continue; // gorsel verisi yok, bos kayit eklemeyelim

                    // Birlestirmede mevcut dosya korunur (tekrar kayit olusmaz); aksi halde temizlik silecegi icin kopyalanir.
                    if (!(merge && exists))
                    {
                        var path = Path.Combine(_dbService.ImageFolder, $"{Guid.NewGuid()}.png");
                        await File.WriteAllBytesAsync(path, bytes);
                        item.Content = path;
                    }
                }
                items.Add(item);
            }

            if (!merge)
                _dbService.ClearHistory();

            var count = 0;
            foreach (var item in items)
            {
                if (_dbService.SaveItem(item.Type, item.Content, item.OcrText, item.Timestamp, item.IsPinned))
                    count++;
            }

            return count;
        }
    }
}

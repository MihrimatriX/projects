using System;
using System.Collections.Generic;
using System.IO;
using ClipboardYoneticisi.Helpers;
using Microsoft.Data.Sqlite;

namespace ClipboardYoneticisi.Services
{
    public class DatabaseService
    {
        private readonly string _dbFolder;
        private readonly string _dbPath;
        private readonly string _imageFolder;
        private readonly string _connectionString;
        private readonly EncryptionService _encryption;

        public DatabaseService()
        {
            AppPaths.EnsureDirectories();
            AppPaths.MigrateLegacyDataIfNeeded();

            _dbFolder = AppPaths.DataFolder;
            _dbPath = AppPaths.DbPath;
            _imageFolder = AppPaths.ImagesFolder;
            _encryption = EncryptionService.Instance;

            Directory.CreateDirectory(_imageFolder);

            _connectionString = $"Data Source={_dbPath};Mode=ReadWriteCreate;Cache=Shared";
            InitializeDatabase();
        }

        public string ImageFolder => _imageFolder;

        private void InitializeDatabase()
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            Execute(conn, "PRAGMA journal_mode=WAL;");
            Execute(conn, "PRAGMA synchronous=NORMAL;");

            Execute(conn, @"
                CREATE TABLE IF NOT EXISTS ClipboardItems (
                    Id INTEGER PRIMARY KEY AUTOINCREMENT,
                    Type TEXT NOT NULL,
                    Content TEXT NOT NULL,
                    Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                    IsPinned INTEGER DEFAULT 0,
                    OcrText TEXT
                );");

            EnsureColumn(conn, "OcrText", "TEXT");

            Execute(conn, @"
                CREATE VIRTUAL TABLE IF NOT EXISTS ClipboardItems_fts USING fts5(
                    ItemId UNINDEXED,
                    SearchBody,
                    tokenize='unicode61 remove_diacritics 2'
                );");

            Execute(conn, @"
                CREATE TRIGGER IF NOT EXISTS clipboard_items_ai AFTER INSERT ON ClipboardItems BEGIN
                    INSERT INTO ClipboardItems_fts(ItemId, SearchBody)
                    VALUES (new.Id, new.Content || ' ' || COALESCE(new.OcrText, ''));
                END;");

            Execute(conn, @"
                CREATE TRIGGER IF NOT EXISTS clipboard_items_ad AFTER DELETE ON ClipboardItems BEGIN
                    DELETE FROM ClipboardItems_fts WHERE ItemId = old.Id;
                END;");

            Execute(conn, @"
                CREATE TRIGGER IF NOT EXISTS clipboard_items_au AFTER UPDATE ON ClipboardItems BEGIN
                    DELETE FROM ClipboardItems_fts WHERE ItemId = old.Id;
                    INSERT INTO ClipboardItems_fts(ItemId, SearchBody)
                    VALUES (new.Id, new.Content || ' ' || COALESCE(new.OcrText, ''));
                END;");

            BackfillFtsIfNeeded(conn);
        }

        private static void EnsureColumn(SqliteConnection conn, string column, string type)
        {
            using var cmd = new SqliteCommand("PRAGMA table_info(ClipboardItems);", conn);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                if (reader.GetString(1).Equals(column, StringComparison.OrdinalIgnoreCase))
                    return;
            }

            Execute(conn, $"ALTER TABLE ClipboardItems ADD COLUMN {column} {type};");
        }

        private static void BackfillFtsIfNeeded(SqliteConnection conn)
        {
            using var countCmd = new SqliteCommand("SELECT COUNT(*) FROM ClipboardItems_fts;", conn);
            var ftsCount = (long)(countCmd.ExecuteScalar() ?? 0L);

            using var itemsCmd = new SqliteCommand("SELECT COUNT(*) FROM ClipboardItems;", conn);
            var itemCount = (long)(itemsCmd.ExecuteScalar() ?? 0L);

            if (ftsCount >= itemCount)
                return;

            Execute(conn, "DELETE FROM ClipboardItems_fts;");
            Execute(conn, @"
                INSERT INTO ClipboardItems_fts(ItemId, SearchBody)
                SELECT Id, Content || ' ' || COALESCE(OcrText, '') FROM ClipboardItems;");
        }

        private static void Execute(SqliteConnection conn, string sql)
        {
            using var cmd = new SqliteCommand(sql, conn);
            cmd.ExecuteNonQuery();
        }

        /// <summary>Kaydeder; regex filtresine takilirsa false. timestamp/isPinned yedekten geri yuklemede kullanilir.</summary>
        public bool SaveItem(string type, string content, string? ocrText = null, DateTime? timestamp = null, bool isPinned = false)
        {
            if (Helpers.RegexFilterService.ShouldBlock(content) ||
                (ocrText != null && Helpers.RegexFilterService.ShouldBlock(ocrText)))
            {
                return false;
            }

            var stamp = (timestamp ?? DateTime.Now).ToString("yyyy-MM-dd HH:mm:ss.fff", System.Globalization.CultureInfo.InvariantCulture); // ms: ayni saniyedeki kopyalar dogru siralansin

            var storedContent = _encryption.IsEnabled && _encryption.IsUnlocked
                ? _encryption.Encrypt(content)
                : content;

            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            int existingId = FindDuplicate(conn, type, content, storedContent);

            if (existingId != -1)
            {
                using var updateCmd = new SqliteCommand(
                    "UPDATE ClipboardItems SET Timestamp = MAX(Timestamp, @Ts), IsPinned = MAX(IsPinned, @IsPinned), OcrText = COALESCE(@OcrText, OcrText) WHERE Id = @Id;",
                    conn);
                updateCmd.Parameters.AddWithValue("@Id", existingId);
                updateCmd.Parameters.AddWithValue("@Ts", stamp);
                updateCmd.Parameters.AddWithValue("@IsPinned", isPinned ? 1 : 0);
                updateCmd.Parameters.AddWithValue("@OcrText", (object?)ocrText ?? DBNull.Value);
                updateCmd.ExecuteNonQuery();
            }
            else
            {
                using var insertCmd = new SqliteCommand(@"
                    INSERT INTO ClipboardItems (Type, Content, Timestamp, IsPinned, OcrText)
                    VALUES (@Type, @Content, @Ts, @IsPinned, @OcrText);", conn);
                insertCmd.Parameters.AddWithValue("@Type", type);
                insertCmd.Parameters.AddWithValue("@Ts", stamp);
                insertCmd.Parameters.AddWithValue("@IsPinned", isPinned ? 1 : 0);
                insertCmd.Parameters.AddWithValue("@Content", storedContent);
                insertCmd.Parameters.AddWithValue("@OcrText", (object?)ocrText ?? DBNull.Value);
                insertCmd.ExecuteNonQuery();
                EnforceLimit(conn);
            }

            return true;
        }

        /// <summary>
        /// Ayni tur + icerikte kayit. Sifreli modda her sifreleme rastgele IV kullandigi icin sifreli metinler
        /// karsilastirilamaz; cozulup karsilastirilir (aksi halde her kopya yeni kayit aciyordu).
        /// ponytail: sifreli modda O(n) cozme (n = gecmis limiti, en fazla 5000); yavaslarsa icerik ozeti sutunu ekle.
        /// </summary>
        private int FindDuplicate(SqliteConnection conn, string type, string content, string storedContent)
        {
            var encrypted = storedContent != content;
            using var cmd = new SqliteCommand(encrypted
                ? "SELECT Id, Content FROM ClipboardItems WHERE Type = @Type;"
                : "SELECT Id, Content FROM ClipboardItems WHERE Type = @Type AND Content = @Content LIMIT 1;", conn);
            cmd.Parameters.AddWithValue("@Type", type);
            cmd.Parameters.AddWithValue("@Content", storedContent);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                if (!encrypted || _encryption.DecryptIfNeeded(reader.GetString(1)) == content)
                    return reader.GetInt32(0);
            }
            return -1;
        }

        public void UpdateOcrText(int id, string ocrText)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand("UPDATE ClipboardItems SET OcrText = @OcrText WHERE Id = @Id;", conn);
            cmd.Parameters.AddWithValue("@OcrText", ocrText);
            cmd.Parameters.AddWithValue("@Id", id);
            cmd.ExecuteNonQuery();
        }

        public int? GetLastImageItemId()
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand(
                "SELECT Id FROM ClipboardItems WHERE Type = 'Image' ORDER BY Id DESC LIMIT 1;", conn);
            var result = cmd.ExecuteScalar();
            return result == null ? null : Convert.ToInt32(result);
        }

        private void EnforceLimit(SqliteConnection conn)
        {
            using var countCmd = new SqliteCommand("SELECT COUNT(*) FROM ClipboardItems WHERE IsPinned = 0;", conn);
            var nonPinnedCount = (long)(countCmd.ExecuteScalar() ?? 0L);
            var historyLimit = SettingsService.Instance.Settings.HistoryLimit;

            if (nonPinnedCount <= historyLimit)
                return;

            var itemsToDelete = new List<(int Id, string Type, string Content)>();
            using (var selectCmd = new SqliteCommand(
                "SELECT Id, Type, Content FROM ClipboardItems WHERE IsPinned = 0 ORDER BY Timestamp ASC, Id ASC LIMIT @Limit;", conn))
            {
                selectCmd.Parameters.AddWithValue("@Limit", nonPinnedCount - historyLimit);
                using var reader = selectCmd.ExecuteReader();
                while (reader.Read())
                    itemsToDelete.Add((reader.GetInt32(0), reader.GetString(1), reader.GetString(2)));
            }

            foreach (var item in itemsToDelete)
            {
                using var deleteCmd = new SqliteCommand("DELETE FROM ClipboardItems WHERE Id = @Id;", conn);
                deleteCmd.Parameters.AddWithValue("@Id", item.Id);
                deleteCmd.ExecuteNonQuery();

                if (item.Type == "Image")
                    TryDeleteImageFile(_encryption.DecryptIfNeeded(item.Content));
            }
        }

        public List<ClipboardItemData> GetItems(string? searchFilter = null)
        {
            var list = new List<ClipboardItemData>();
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            if (!string.IsNullOrWhiteSpace(searchFilter) && _encryption.IsEnabled)
            {
                LoadAllItems(conn, list);
                return FilterDecrypted(list, searchFilter);
            }

            string query;
            if (!string.IsNullOrWhiteSpace(searchFilter))
            {
                query = @"
                    SELECT c.Id, c.Type, c.Content, c.Timestamp, c.IsPinned, c.OcrText
                    FROM ClipboardItems c
                    INNER JOIN ClipboardItems_fts ON ClipboardItems_fts.ItemId = c.Id
                    WHERE ClipboardItems_fts MATCH @Search
                    ORDER BY c.IsPinned DESC, c.Timestamp DESC, c.Id DESC;";
            }
            else
            {
                query = @"
                    SELECT Id, Type, Content, Timestamp, IsPinned, OcrText
                    FROM ClipboardItems
                    ORDER BY IsPinned DESC, Timestamp DESC, Id DESC;";
            }

            using var cmd = new SqliteCommand(query, conn);
            if (!string.IsNullOrWhiteSpace(searchFilter))
                cmd.Parameters.AddWithValue("@Search", FuzzySearchHelper.BuildFtsQuery(searchFilter));

            ReadItems(cmd, list);

            if (!string.IsNullOrWhiteSpace(searchFilter) && list.Count == 0)
                return SearchWithLikeFallback(conn, searchFilter);

            return list;
        }

        private List<ClipboardItemData> SearchWithLikeFallback(SqliteConnection conn, string searchFilter)
        {
            var list = new List<ClipboardItemData>();
            using var cmd = new SqliteCommand(@"
                SELECT Id, Type, Content, Timestamp, IsPinned, OcrText
                FROM ClipboardItems
                WHERE Type != 'Image' AND (Content LIKE @Search OR OcrText LIKE @Search)
                ORDER BY IsPinned DESC, Timestamp DESC, Id DESC;", conn);
            cmd.Parameters.AddWithValue("@Search", $"%{searchFilter.Trim()}%");
            ReadItems(cmd, list);
            return list;
        }

        private void LoadAllItems(SqliteConnection conn, List<ClipboardItemData> list)
        {
            using var cmd = new SqliteCommand(
                "SELECT Id, Type, Content, Timestamp, IsPinned, OcrText FROM ClipboardItems ORDER BY IsPinned DESC, Timestamp DESC, Id DESC;",
                conn);
            ReadItems(cmd, list);
        }

        private List<ClipboardItemData> FilterDecrypted(List<ClipboardItemData> items, string searchFilter)
        {
            var filtered = new List<ClipboardItemData>();

            foreach (var item in items)
            {
                var content = _encryption.DecryptIfNeeded(item.Content);
                var ocr = item.OcrText ?? string.Empty;
                var searchable = content + " " + ocr;

                if (!FuzzySearchHelper.MatchesFuzzy(searchable, searchFilter))
                    continue;

                filtered.Add(new ClipboardItemData
                {
                    Id = item.Id,
                    Type = item.Type,
                    Content = content,
                    Timestamp = item.Timestamp,
                    IsPinned = item.IsPinned,
                    OcrText = item.OcrText
                });
            }

            return filtered;
        }

        public void DeleteItems(IEnumerable<(int Id, string Type, string Content)> items, bool deleteImageFiles = true)
        {
            foreach (var item in items)
                DeleteItem(item.Id, item.Type, item.Content, deleteImageFiles);
        }

        private void ReadItems(SqliteCommand cmd, List<ClipboardItemData> list)
        {
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                var rawContent = reader.GetString(2);
                list.Add(new ClipboardItemData
                {
                    Id = reader.GetInt32(0),
                    Type = reader.GetString(1),
                    Content = _encryption.DecryptIfNeeded(rawContent),
                    Timestamp = reader.GetDateTime(3),
                    IsPinned = reader.GetInt32(4) == 1,
                    OcrText = reader.IsDBNull(5) ? null : reader.GetString(5)
                });
            }
        }

        /// <summary>deleteImageFile=false: geri al icin gorsel dosyasi tutulur (sonra TryDeleteImageFile).</summary>
        public void DeleteItem(int id, string type, string content, bool deleteImageFile = true)
        {
            using (var conn = new SqliteConnection(_connectionString))
            {
                conn.Open();
                using var cmd = new SqliteCommand("DELETE FROM ClipboardItems WHERE Id = @Id;", conn);
                cmd.Parameters.AddWithValue("@Id", id);
                cmd.ExecuteNonQuery();
            }

            if (type == "Image" && deleteImageFile)
                TryDeleteImageFile(content);
        }

        public void TogglePin(int id, bool isPinned)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand("UPDATE ClipboardItems SET IsPinned = @IsPinned WHERE Id = @Id;", conn);
            cmd.Parameters.AddWithValue("@IsPinned", isPinned ? 1 : 0);
            cmd.Parameters.AddWithValue("@Id", id);
            cmd.ExecuteNonQuery();
        }

        public void ClearHistory()
        {
            var imagesToDelete = new List<string>();

            using (var conn = new SqliteConnection(_connectionString))
            {
                conn.Open();
                using (var selectCmd = new SqliteCommand(
                    "SELECT Content FROM ClipboardItems WHERE Type = 'Image' AND IsPinned = 0;", conn))
                using (var reader = selectCmd.ExecuteReader())
                {
                    while (reader.Read())
                        imagesToDelete.Add(_encryption.DecryptIfNeeded(reader.GetString(0)));
                }

                using var deleteCmd = new SqliteCommand("DELETE FROM ClipboardItems WHERE IsPinned = 0;", conn);
                deleteCmd.ExecuteNonQuery();
            }

            foreach (var imgPath in imagesToDelete)
                TryDeleteImageFile(imgPath);
        }

        public void PurgeOlderThan(int days)
        {
            if (days <= 0)
                return;

            var imagesToDelete = new List<string>();

            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            using (var selectCmd = new SqliteCommand(@"
                SELECT Content FROM ClipboardItems
                WHERE IsPinned = 0 AND Type = 'Image'
                AND Timestamp < datetime('now', 'localtime', @Offset);", conn))
            {
                selectCmd.Parameters.AddWithValue("@Offset", $"-{days} days");
                using var reader = selectCmd.ExecuteReader();
                while (reader.Read())
                    imagesToDelete.Add(_encryption.DecryptIfNeeded(reader.GetString(0)));
            }

            using (var deleteCmd = new SqliteCommand(@"
                DELETE FROM ClipboardItems
                WHERE IsPinned = 0
                AND Timestamp < datetime('now', 'localtime', @Offset);", conn))
            {
                deleteCmd.Parameters.AddWithValue("@Offset", $"-{days} days");
                deleteCmd.ExecuteNonQuery();
            }

            foreach (var imgPath in imagesToDelete)
                TryDeleteImageFile(imgPath);
        }

        public void ReencryptAll(bool enable)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            using var selectCmd = new SqliteCommand("SELECT Id, Content, OcrText FROM ClipboardItems;", conn);
            using var reader = selectCmd.ExecuteReader();
            var rows = new List<(int Id, string Content, string? OcrText)>();
            while (reader.Read())
            {
                rows.Add((reader.GetInt32(0), reader.GetString(1), reader.IsDBNull(2) ? null : reader.GetString(2)));
            }

            foreach (var row in rows)
            {
                // Sifreleme kapatilirken ayar zaten false oldugundan DecryptIfNeeded hicbir sey
                // cozmez ve kayitlar anahtar silindikten sonra kalici olarak okunamaz kalirdi.
                // Decrypt yalnizca anahtara bakar; duz metni oldugu gibi dondurur.
                var plain = _encryption.Decrypt(row.Content);
                var stored = enable && _encryption.IsUnlocked ? _encryption.Encrypt(plain) : plain;

                using var updateCmd = new SqliteCommand("UPDATE ClipboardItems SET Content = @Content WHERE Id = @Id;", conn);
                updateCmd.Parameters.AddWithValue("@Content", stored);
                updateCmd.Parameters.AddWithValue("@Id", row.Id);
                updateCmd.ExecuteNonQuery();
            }

            Execute(conn, "DELETE FROM ClipboardItems_fts;");
            Execute(conn, @"
                INSERT INTO ClipboardItems_fts(ItemId, SearchBody)
                SELECT Id, Content || ' ' || COALESCE(OcrText, '') FROM ClipboardItems;");
        }

        internal static void TryDeleteImageFile(string path)
        {
            if (!File.Exists(path))
                return;

            try
            {
                File.Delete(path);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to delete image file: {ex.Message}");
            }
        }
    }

    public class ClipboardItemData
    {
        public int Id { get; set; }
        public required string Type { get; set; }
        public required string Content { get; set; }
        public DateTime Timestamp { get; set; }
        public bool IsPinned { get; set; }
        public string? OcrText { get; set; }
    }
}

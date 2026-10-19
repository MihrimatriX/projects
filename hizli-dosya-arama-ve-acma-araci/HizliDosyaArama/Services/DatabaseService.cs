using System;
using System.Collections.Generic;
using System.IO;
using Microsoft.Data.Sqlite;

namespace HizliDosyaArama.Services
{
    public class DatabaseService
    {
        private readonly string _dbFolder;
        private readonly string _dbPath;
        private readonly string _connectionString;

        // Veriler exe yanına değil kullanıcı profiline yazılır; testler/taşınabilir kullanım için ortam değişkeniyle değiştirilebilir.
        public const string DataDirEnvVar = "HIZLI_DOSYA_ARAMA_DATA_DIR";

        public DatabaseService() : this(ResolveDataFolder()) { }

        public DatabaseService(string dataFolder)
        {
            _dbFolder = dataFolder;
            _dbPath = Path.Combine(_dbFolder, "search_index.db");

            Directory.CreateDirectory(_dbFolder);

            _connectionString = $"Data Source={_dbPath}";
            InitializeDatabase();
        }

        /// <summary>Veritabanı, aliases.json ve crash.log'un bulunduğu klasör.</summary>
        public string DataFolder => _dbFolder;

        public static string ResolveDataFolder()
        {
            var overrideDir = Environment.GetEnvironmentVariable(DataDirEnvVar);
            if (!string.IsNullOrWhiteSpace(overrideDir)) return overrideDir;

            var folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "HizliDosyaArama");
            MigrateLegacyData(Path.Combine(AppContext.BaseDirectory, "data"), folder);
            return folder;
        }

        // Eski sürümler veriyi exe yanındaki data\ altında tutuyordu; yeni konumda olmayan dosyalar kopyalanır (son dosyalar ve alias'lar korunur).
        internal static void MigrateLegacyData(string legacyFolder, string targetFolder)
        {
            foreach (var name in new[] { "search_index.db", "aliases.json" })
            {
                var src = Path.Combine(legacyFolder, name);
                var dst = Path.Combine(targetFolder, name);
                if (!File.Exists(src) || File.Exists(dst)) continue;
                try
                {
                    Directory.CreateDirectory(targetFolder);
                    File.Copy(src, dst);
                }
                catch (IOException) { /* ponytail: kopyalanamazsa boş başlanır, indeks yeniden kurulur */ }
                catch (UnauthorizedAccessException) { }
            }
        }

        private void InitializeDatabase()
        {
            using (var conn = new SqliteConnection(_connectionString))
            {
                conn.Open();
                
                string createTableQuery = @"
                    CREATE TABLE IF NOT EXISTS Files (
                        Id INTEGER PRIMARY KEY AUTOINCREMENT,
                        FileName TEXT NOT NULL,
                        FilePath TEXT NOT NULL UNIQUE,
                        Extension TEXT NOT NULL,
                        Size INTEGER NOT NULL,
                        LastWriteTime DATETIME NOT NULL
                    );";
                
                using (var cmd = new SqliteCommand(createTableQuery, conn))
                {
                    cmd.ExecuteNonQuery();
                }

                // Create index on FileName for fast search
                string createIndexQuery = "CREATE INDEX IF NOT EXISTS idx_files_filename ON Files(FileName);";
                using (var cmd = new SqliteCommand(createIndexQuery, conn))
                {
                    cmd.ExecuteNonQuery();
                }

                string createRecentQuery = @"
                    CREATE TABLE IF NOT EXISTS RecentFiles (
                        Id INTEGER PRIMARY KEY AUTOINCREMENT,
                        FilePath TEXT NOT NULL UNIQUE,
                        FileName TEXT NOT NULL,
                        Extension TEXT NOT NULL,
                        Size INTEGER NOT NULL,
                        LastWriteTime DATETIME NOT NULL,
                        AccessedAt DATETIME NOT NULL
                    );";
                using (var cmd = new SqliteCommand(createRecentQuery, conn))
                {
                    cmd.ExecuteNonQuery();
                }
            }
        }

        public void BulkInsertFiles(List<IndexedFileData> files)
        {
            if (files == null || files.Count == 0) return;

            using (var conn = new SqliteConnection(_connectionString))
            {
                conn.Open();
                using (var transaction = conn.BeginTransaction())
                {
                    string insertQuery = @"
                        INSERT OR REPLACE INTO Files (FileName, FilePath, Extension, Size, LastWriteTime) 
                        VALUES (@FileName, @FilePath, @Extension, @Size, @LastWriteTime);";

                    using (var cmd = new SqliteCommand(insertQuery, conn, transaction))
                    {
                        var paramName = cmd.Parameters.Add("@FileName", SqliteType.Text);
                        var paramPath = cmd.Parameters.Add("@FilePath", SqliteType.Text);
                        var paramExt = cmd.Parameters.Add("@Extension", SqliteType.Text);
                        var paramSize = cmd.Parameters.Add("@Size", SqliteType.Integer);
                        var paramTime = cmd.Parameters.Add("@LastWriteTime", SqliteType.Text);

                        foreach (var f in files)
                        {
                            paramName.Value = f.FileName;
                            paramPath.Value = f.FilePath;
                            paramExt.Value = f.Extension;
                            paramSize.Value = f.Size;
                            paramTime.Value = f.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss");

                            cmd.ExecuteNonQuery();
                        }
                    }
                    transaction.Commit();
                }
            }
        }

        public List<IndexedFileData> SearchFiles(string query)
        {
            var results = new List<IndexedFileData>();
            if (string.IsNullOrWhiteSpace(query)) return results;

            using (var conn = new SqliteConnection(_connectionString))
            {
                conn.Open();

                // Sorgu boşluklarla kelimelere ayrılır: her kelime dosya adında (sırasız) geçmeli;
                // nokta ile başlayan kelime (".pdf") uzantı filtresidir. İlk kelimeyle başlayan adlar öne alınır.
                // Not: '%q%' araması FileName indeksini kullanamaz, tablo taranır; ilk 50 sonuç döner
                var (terms, extensions) = ParseQuery(query);
                if (terms.Count == 0 && extensions.Count == 0) return results;

                using (var cmd = new SqliteCommand { Connection = conn })
                {
                    var where = new List<string>();
                    for (int i = 0; i < terms.Count; i++)
                    {
                        where.Add($"FileName LIKE @T{i} ESCAPE '\\'");
                        cmd.Parameters.AddWithValue($"@T{i}", $"%{EscapeLike(terms[i])}%");
                    }
                    if (extensions.Count > 0)
                    {
                        var names = new List<string>();
                        for (int i = 0; i < extensions.Count; i++)
                        {
                            names.Add($"@E{i}");
                            cmd.Parameters.AddWithValue($"@E{i}", extensions[i]);
                        }
                        where.Add($"Extension COLLATE NOCASE IN ({string.Join(", ", names)})");
                    }
                    cmd.Parameters.AddWithValue("@QueryPrefix", terms.Count > 0 ? $"{EscapeLike(terms[0])}%" : "");

                    cmd.CommandText = $@"
                    SELECT FileName, FilePath, Extension, Size, LastWriteTime
                    FROM Files
                    WHERE {string.Join(" AND ", where)}
                    ORDER BY
                        CASE WHEN FileName LIKE @QueryPrefix ESCAPE '\' THEN 0 ELSE 1 END,
                        FileName ASC
                    LIMIT 50;";

                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            results.Add(new IndexedFileData
                            {
                                FileName = reader.GetString(0),
                                FilePath = reader.GetString(1),
                                Extension = reader.GetString(2),
                                Size = reader.GetInt64(3),
                                LastWriteTime = reader.GetDateTime(4)
                            });
                        }
                    }
                }
            }
            return results;
        }

        /// <summary>"rapor 2024 .pdf" → kelimeler [rapor, 2024], uzantılar [.pdf].</summary>
        public static (List<string> Terms, List<string> Extensions) ParseQuery(string query)
        {
            var terms = new List<string>();
            var extensions = new List<string>();
            foreach (var token in query.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries))
            {
                if (token.Length > 1 && token[0] == '.' && token.IndexOf('.', 1) < 0) extensions.Add(token);
                else terms.Add(token);
            }
            return (terms, extensions);
        }

        // % ve _ dosya adlarında sık geçer; joker karakter sayılmasın.
        private static string EscapeLike(string s) => s.Replace(@"\", @"\\").Replace("%", @"\%").Replace("_", @"\_");

        /// <summary>Diskte artık olmayan dosyayı indeksten ve son dosyalardan çıkarır.</summary>
        public void RemoveFile(string filePath)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand("DELETE FROM Files WHERE FilePath = @P; DELETE FROM RecentFiles WHERE FilePath = @P;", conn);
            cmd.Parameters.AddWithValue("@P", filePath);
            cmd.ExecuteNonQuery();
        }

        public List<IndexedFileData> GetRecentFiles(int limit = 50)
        {
            var results = new List<IndexedFileData>();
            using (var conn = new SqliteConnection(_connectionString))
            {
                conn.Open();
                string query = @"
                    SELECT FileName, FilePath, Extension, Size, LastWriteTime
                    FROM RecentFiles
                    ORDER BY AccessedAt DESC
                    LIMIT @Limit;";
                using (var cmd = new SqliteCommand(query, conn))
                {
                    cmd.Parameters.AddWithValue("@Limit", limit);
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            results.Add(new IndexedFileData
                            {
                                FileName = reader.GetString(0),
                                FilePath = reader.GetString(1),
                                Extension = reader.GetString(2),
                                Size = reader.GetInt64(3),
                                LastWriteTime = reader.GetDateTime(4)
                            });
                        }
                    }
                }
            }
            return results;
        }

        public void RecordRecentAccess(IndexedFileData file)
        {
            using (var conn = new SqliteConnection(_connectionString))
            {
                conn.Open();
                string upsert = @"
                    INSERT INTO RecentFiles (FilePath, FileName, Extension, Size, LastWriteTime, AccessedAt)
                    VALUES (@FilePath, @FileName, @Extension, @Size, @LastWriteTime, datetime('now', 'localtime'))
                    ON CONFLICT(FilePath) DO UPDATE SET AccessedAt = datetime('now', 'localtime');";
                using (var cmd = new SqliteCommand(upsert, conn))
                {
                    cmd.Parameters.AddWithValue("@FilePath", file.FilePath);
                    cmd.Parameters.AddWithValue("@FileName", file.FileName);
                    cmd.Parameters.AddWithValue("@Extension", file.Extension);
                    cmd.Parameters.AddWithValue("@Size", file.Size);
                    cmd.Parameters.AddWithValue("@LastWriteTime", file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss"));
                    cmd.ExecuteNonQuery();
                }

                EnforceRecentLimit(conn, 50);
            }
        }

        private static void EnforceRecentLimit(SqliteConnection conn, int maxItems)
        {
            string selectExcess = @"
                SELECT Id, FilePath FROM RecentFiles
                ORDER BY AccessedAt DESC
                LIMIT -1 OFFSET @MaxItems;";
            var excessIds = new List<int>();
            using (var cmd = new SqliteCommand(selectExcess, conn))
            {
                cmd.Parameters.AddWithValue("@MaxItems", maxItems);
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        excessIds.Add(reader.GetInt32(0));
                    }
                }
            }

            foreach (var id in excessIds)
            {
                using (var cmd = new SqliteCommand("DELETE FROM RecentFiles WHERE Id = @Id;", conn))
                {
                    cmd.Parameters.AddWithValue("@Id", id);
                    cmd.ExecuteNonQuery();
                }
            }
        }

        public long GetIndexedCount()
        {
            using (var conn = new SqliteConnection(_connectionString))
            {
                conn.Open();
                string query = "SELECT COUNT(*) FROM Files;";
                using (var cmd = new SqliteCommand(query, conn))
                {
                    return (long)(cmd.ExecuteScalar() ?? 0L);
                }
            }
        }

        public void ClearDatabase()
        {
            using (var conn = new SqliteConnection(_connectionString))
            {
                conn.Open();
                string query = "DELETE FROM Files;";
                using (var cmd = new SqliteCommand(query, conn))
                {
                    cmd.ExecuteNonQuery();
                }
                
                // Shrink DB file size after deletion
                string vacuumQuery = "VACUUM;";
                using (var cmd = new SqliteCommand(vacuumQuery, conn))
                {
                    cmd.ExecuteNonQuery();
                }
            }
        }
    }

    public class IndexedFileData
    {
        public required string FileName { get; set; }
        public required string FilePath { get; set; }
        public required string Extension { get; set; }
        public long Size { get; set; }
        public DateTime LastWriteTime { get; set; }
    }
}

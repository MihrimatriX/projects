using System;
using System.Collections.Generic;
using System.IO;
using Microsoft.Data.Sqlite;

namespace UygulamaBaslatici.Services
{
    public class DatabaseService
    {
        private readonly string _dbFolder;
        private readonly string _dbPath;
        private readonly string _connectionString;

        // Veriler exe yanına değil kullanıcı profiline yazılır; testler/taşınabilir kullanım için ortam değişkeniyle değiştirilebilir.
        public const string DataDirEnvVar = "KOMUT_PALETI_DATA_DIR";

        public DatabaseService() : this(ResolveDataFolder()) { }

        public DatabaseService(string dbFolder)
        {
            _dbFolder = dbFolder;
            _dbPath = Path.Combine(_dbFolder, "launcher.db");

            Directory.CreateDirectory(_dbFolder);

            // Pooling kapalı: bağlantı kapanınca dosya kilidi kalkar.
            _connectionString = $"Data Source={_dbPath};Pooling=False";
            InitializeDatabase();
        }

        public static string ResolveDataFolder()
        {
            var overrideDir = Environment.GetEnvironmentVariable(DataDirEnvVar);
            if (!string.IsNullOrWhiteSpace(overrideDir)) return overrideDir;

            var folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "KomutPaleti");
            MigrateLegacyData(Path.Combine(AppContext.BaseDirectory, "data"), folder);
            return folder;
        }

        // Eski sürümler veritabanını exe yanındaki data\ altında tutuyordu; yeni konumda yoksa kopyalanır (kullanım sayıları korunur).
        internal static void MigrateLegacyData(string legacyFolder, string targetFolder)
        {
            var legacyDb = Path.Combine(legacyFolder, "launcher.db");
            var targetDb = Path.Combine(targetFolder, "launcher.db");
            if (!File.Exists(legacyDb) || File.Exists(targetDb)) return;
            try
            {
                Directory.CreateDirectory(targetFolder);
                File.Copy(legacyDb, targetDb);
            }
            catch (IOException) { /* ponytail: kopyalanamazsa boş veritabanıyla başlanır */ }
            catch (UnauthorizedAccessException) { }
        }

        private void InitializeDatabase()
        {
            using (var conn = new SqliteConnection(_connectionString))
            {
                conn.Open();
                string createTableQuery = @"
                    CREATE TABLE IF NOT EXISTS Apps (
                        Id INTEGER PRIMARY KEY AUTOINCREMENT,
                        Name TEXT NOT NULL,
                        Path TEXT NOT NULL UNIQUE,
                        Type TEXT NOT NULL,
                        UsageCount INTEGER DEFAULT 0
                    );";
                using (var cmd = new SqliteCommand(createTableQuery, conn))
                {
                    cmd.ExecuteNonQuery();
                }

                // Index on Name for fast prefix searches
                string createIndexQuery = "CREATE INDEX IF NOT EXISTS idx_apps_name ON Apps(Name);";
                using (var cmd = new SqliteCommand(createIndexQuery, conn))
                {
                    cmd.ExecuteNonQuery();
                }
            }
        }

        /// <summary>
        /// Taranan kısayollarla tabloyu eşitler: yenileri ekler, mevcutların kullanım sayısını korur,
        /// artık bulunmayan (kaldırılmış uygulama) kayıtları siler. Boş tarama hiçbir şeyi silmez.
        /// </summary>
        public void BulkInsertApps(List<AppScannerData> apps)
        {
            if (apps == null || apps.Count == 0) return;

            using (var conn = new SqliteConnection(_connectionString))
            {
                conn.Open();
                using (var transaction = conn.BeginTransaction())
                {
                    // Using INSERT OR IGNORE to prevent duplicates but keep the existing UsageCount!
                    string insertQuery = @"
                        INSERT OR IGNORE INTO Apps (Name, Path, Type, UsageCount) 
                        VALUES (@Name, @Path, @Type, 0);";

                    using (var cmd = new SqliteCommand(insertQuery, conn, transaction))
                    {
                        var paramName = cmd.Parameters.Add("@Name", SqliteType.Text);
                        var paramPath = cmd.Parameters.Add("@Path", SqliteType.Text);
                        var paramType = cmd.Parameters.Add("@Type", SqliteType.Text);

                        foreach (var app in apps)
                        {
                            paramName.Value = app.Name;
                            paramPath.Value = app.Path;
                            paramType.Value = app.Type;

                            cmd.ExecuteNonQuery();
                        }
                    }
                    using (var temp = new SqliteCommand("CREATE TEMP TABLE IF NOT EXISTS Scanned (Path TEXT PRIMARY KEY); DELETE FROM Scanned;", conn, transaction))
                        temp.ExecuteNonQuery();
                    using (var mark = new SqliteCommand("INSERT OR IGNORE INTO Scanned (Path) VALUES (@Path);", conn, transaction))
                    {
                        var p = mark.Parameters.Add("@Path", SqliteType.Text);
                        foreach (var app in apps)
                        {
                            p.Value = app.Path;
                            mark.ExecuteNonQuery();
                        }
                    }
                    using (var prune = new SqliteCommand("DELETE FROM Apps WHERE Path NOT IN (SELECT Path FROM Scanned);", conn, transaction))
                        prune.ExecuteNonQuery();
                    transaction.Commit();
                }
            }
        }

        public List<AppScannerData> SearchApps(string query)
        {
            var list = new List<AppScannerData>();
            if (string.IsNullOrWhiteSpace(query)) return list;

            using (var conn = new SqliteConnection(_connectionString))
            {
                conn.Open();

                // Order by UsageCount (highest popularity first) then prefix matching
                string searchQuery = @"
                    SELECT Name, Path, Type, UsageCount 
                    FROM Apps 
                    WHERE Name LIKE @Query ESCAPE '\'
                    ORDER BY
                        UsageCount DESC,
                        CASE WHEN Name LIKE @QueryPrefix ESCAPE '\' THEN 0 ELSE 1 END,
                        Name ASC
                    LIMIT 9;";

                using (var cmd = new SqliteCommand(searchQuery, conn))
                {
                    // % ve _ kullanıcı metninde joker karakter sayılmasın.
                    var escaped = query.Replace(@"\", @"\\").Replace("%", @"\%").Replace("_", @"\_");
                    cmd.Parameters.AddWithValue("@Query", $"%{escaped}%");
                    cmd.Parameters.AddWithValue("@QueryPrefix", $"{escaped}%");

                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            list.Add(new AppScannerData
                            {
                                Name = reader.GetString(0),
                                Path = reader.GetString(1),
                                Type = reader.GetString(2),
                                UsageCount = reader.GetInt32(3)
                            });
                        }
                    }
                }
            }
            return list;
        }

        public List<AppScannerData> GetTopApps(int limit = 12)
        {
            var list = new List<AppScannerData>();
            using (var conn = new SqliteConnection(_connectionString))
            {
                conn.Open();
                string query = @"
                    SELECT Name, Path, Type, UsageCount
                    FROM Apps
                    ORDER BY UsageCount DESC, Name ASC
                    LIMIT @Limit;";
                using (var cmd = new SqliteCommand(query, conn))
                {
                    cmd.Parameters.AddWithValue("@Limit", limit);
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            list.Add(new AppScannerData
                            {
                                Name = reader.GetString(0),
                                Path = reader.GetString(1),
                                Type = reader.GetString(2),
                                UsageCount = reader.GetInt32(3)
                            });
                        }
                    }
                }
            }
            return list;
        }

        public void IncrementUsage(string path)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand("UPDATE Apps SET UsageCount = UsageCount + 1 WHERE Path = @Path;", conn);
            cmd.Parameters.AddWithValue("@Path", path);
            cmd.ExecuteNonQuery();
        }

        public void RemoveApp(string path)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand("DELETE FROM Apps WHERE Path = @Path;", conn);
            cmd.Parameters.AddWithValue("@Path", path);
            cmd.ExecuteNonQuery();
        }
    }

    public class AppScannerData
    {
        public required string Name { get; set; }
        public required string Path { get; set; }
        public required string Type { get; set; }
        public int UsageCount { get; set; }
    }
}

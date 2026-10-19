using System.IO;
using Microsoft.Data.Sqlite;

namespace EkranKaydi.Services;

public class DatabaseService
{
    private readonly string _connectionString;
    private readonly string _recordingsFolder;

    public DatabaseService() : this(MigrateLegacy(Path.Combine(AppContext.BaseDirectory, "data"), AppPaths.DataFolder)) { }

    // Eski sürümler geçmişi exe yanındaki data\ altında tutuyordu (kayıt dosyaları yerinde kalır, db mutlak yol saklar).
    internal static string MigrateLegacy(string legacyFolder, string targetFolder)
    {
        var legacyDb = Path.Combine(legacyFolder, "recordings.db");
        var targetDb = Path.Combine(targetFolder, "recordings.db");
        if (!File.Exists(legacyDb) || File.Exists(targetDb)) return targetFolder;
        try
        {
            Directory.CreateDirectory(targetFolder);
            File.Copy(legacyDb, targetDb);
            var thumbs = Path.Combine(legacyFolder, "thumbnails");
            if (Directory.Exists(thumbs))
            {
                var targetThumbs = Directory.CreateDirectory(Path.Combine(targetFolder, "thumbnails")).FullName;
                foreach (var f in Directory.EnumerateFiles(thumbs))
                    File.Copy(f, Path.Combine(targetThumbs, Path.GetFileName(f)), overwrite: false);
            }
        }
        catch (IOException) { /* taşıma başarısızsa boş geçmişle devam */ }
        return targetFolder;
    }

    public DatabaseService(string dbFolder)
    {
        _recordingsFolder = Path.Combine(dbFolder, "Recordings");
        Directory.CreateDirectory(dbFolder);
        Directory.CreateDirectory(_recordingsFolder);
        _connectionString = $"Data Source={Path.Combine(dbFolder, "recordings.db")}";
        InitDb();
    }

    public string RecordingsFolder => _recordingsFolder;

    private void InitDb()
    {
        using var conn = Open();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = """
            CREATE TABLE IF NOT EXISTS Recordings (
                Id INTEGER PRIMARY KEY AUTOINCREMENT,
                FilePath TEXT NOT NULL UNIQUE,
                Type TEXT NOT NULL,
                DurationSeconds REAL,
                Width INTEGER,
                Height INTEGER,
                Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            );
            """;
        cmd.ExecuteNonQuery();
    }

    private SqliteConnection Open()
    {
        var conn = new SqliteConnection(_connectionString);
        conn.Open();
        return conn;
    }

    public long SaveRecording(string filePath, string type, double durationSeconds, int width, int height)
    {
        using var conn = Open();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = """
            INSERT INTO Recordings (FilePath, Type, DurationSeconds, Width, Height, Timestamp)
            VALUES (@FilePath, @Type, @DurationSeconds, @Width, @Height, datetime('now', 'localtime'));
            SELECT last_insert_rowid();
            """;
        cmd.Parameters.AddWithValue("@FilePath", filePath);
        cmd.Parameters.AddWithValue("@Type", type);
        cmd.Parameters.AddWithValue("@DurationSeconds", durationSeconds);
        cmd.Parameters.AddWithValue("@Width", width);
        cmd.Parameters.AddWithValue("@Height", height);
        var newId = Convert.ToInt64(cmd.ExecuteScalar());
        TrimHistory(conn);
        return newId;
    }

    public const int HistoryLimit = 10;

    // Geçmiş listesi son 10 kayıtla sınırlı; daha eski kayıtların DOSYALARI silinmez (kullanıcının
    // dışa aktardığı GIF/MP4'ler sessizce kaybolmasın), kayıt klasöründe kalır.
    private static void TrimHistory(SqliteConnection conn)
    {
        using var cmd = conn.CreateCommand();
        cmd.CommandText = $"DELETE FROM Recordings WHERE Id NOT IN (SELECT Id FROM Recordings ORDER BY Timestamp DESC, Id DESC LIMIT {HistoryLimit});";
        cmd.ExecuteNonQuery();
    }

    public List<RecordingData> GetRecordings()
    {
        var list = new List<RecordingData>();
        using var conn = Open();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT Id, FilePath, Type, DurationSeconds, Width, Height, Timestamp FROM Recordings ORDER BY Timestamp DESC, Id DESC;";
        using var reader = cmd.ExecuteReader();
        while (reader.Read())
        {
            list.Add(new RecordingData
            {
                Id = reader.GetInt32(0),
                FilePath = reader.GetString(1),
                Type = reader.GetString(2),
                DurationSeconds = reader.GetDouble(3),
                Width = reader.GetInt32(4),
                Height = reader.GetInt32(5),
                Timestamp = reader.GetDateTime(6)
            });
        }
        return list;
    }

    public void DeleteRecording(int id, string filePath)
    {
        using (var conn = Open())
        using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = "DELETE FROM Recordings WHERE Id = @Id;";
            cmd.Parameters.AddWithValue("@Id", id);
            cmd.ExecuteNonQuery();
        }
        TryDeleteFile(filePath);
    }

    public void ClearHistory()
    {
        var files = new List<string>();
        using (var conn = Open())
        {
            using (var select = conn.CreateCommand())
            {
                select.CommandText = "SELECT FilePath FROM Recordings;";
                using var reader = select.ExecuteReader();
                while (reader.Read()) files.Add(reader.GetString(0));
            }
            using var del = conn.CreateCommand();
            del.CommandText = "DELETE FROM Recordings;";
            del.ExecuteNonQuery();
        }
        foreach (var file in files) TryDeleteFile(file);
    }

    private static void TryDeleteFile(string path)
    {
        if (!File.Exists(path)) return;
        try { File.Delete(path); } catch { /* ponytail: orphan file ok */ }
    }
}

public class RecordingData
{
    public int Id { get; set; }
    public required string FilePath { get; set; }
    public required string Type { get; set; }
    public double DurationSeconds { get; set; }
    public int Width { get; set; }
    public int Height { get; set; }
    public DateTime Timestamp { get; set; }
}

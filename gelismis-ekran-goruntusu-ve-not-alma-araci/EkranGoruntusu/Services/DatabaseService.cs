using System.Collections.Generic;
using System.IO;
using Microsoft.Data.Sqlite;

namespace EkranGoruntusu.Services;

public sealed class DatabaseService
{
    private readonly string _dbPath;
    private string _screenshotsFolder;
    private readonly string _connectionString;

    public DatabaseService(string dataFolder, string screenshotsFolder)
    {
        Directory.CreateDirectory(dataFolder);
        _screenshotsFolder = screenshotsFolder;
        Directory.CreateDirectory(_screenshotsFolder);
        _dbPath = Path.Combine(dataFolder, "screenshots.db");
        _connectionString = $"Data Source={_dbPath};Pooling=False"; // dosya kilidi kalmasın
        InitializeDatabase();
    }

    public string ScreenshotsFolder
    {
        get => _screenshotsFolder;
        set
        {
            _screenshotsFolder = value;
            Directory.CreateDirectory(value);
        }
    }

    private void InitializeDatabase()
    {
        using var conn = new SqliteConnection(_connectionString);
        conn.Open();
        using var cmd = new SqliteCommand("""
            CREATE TABLE IF NOT EXISTS Screenshots (
                Id INTEGER PRIMARY KEY AUTOINCREMENT,
                ImagePath TEXT NOT NULL UNIQUE,
                OcrText TEXT,
                Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            );
            """, conn);
        cmd.ExecuteNonQuery();
    }

    public void SaveScreenshot(string imagePath, string ocrText, int historyLimit = 20)
    {
        using var conn = new SqliteConnection(_connectionString);
        conn.Open();
        using var cmd = new SqliteCommand("""
            INSERT INTO Screenshots (ImagePath, OcrText, Timestamp)
            VALUES (@ImagePath, @OcrText, datetime('now', 'localtime'));
            """, conn);
        cmd.Parameters.AddWithValue("@ImagePath", imagePath);
        cmd.Parameters.AddWithValue("@OcrText", string.IsNullOrWhiteSpace(ocrText) ? DBNull.Value : ocrText);
        cmd.ExecuteNonQuery();
        // Geçmiş en fazla historyLimit kayıt tutar (Ayarlar); daha eski kayıtların PNG dosyaları da diskten silinir
        EnforceHistoryLimit(conn, historyLimit);
    }

    private static void EnforceHistoryLimit(SqliteConnection conn, int maxItems)
    {
        var excess = new List<(int Id, string Path)>();
        using (var cmd = new SqliteCommand("""
            SELECT Id, ImagePath FROM Screenshots
            ORDER BY Timestamp DESC, Id DESC LIMIT -1 OFFSET @Max;
            """, conn))
        {
            cmd.Parameters.AddWithValue("@Max", maxItems);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
                excess.Add((reader.GetInt32(0), reader.GetString(1)));
        }

        foreach (var (id, path) in excess)
        {
            using var del = new SqliteCommand("DELETE FROM Screenshots WHERE Id = @Id;", conn);
            del.Parameters.AddWithValue("@Id", id);
            del.ExecuteNonQuery();
            TryDeleteFile(path);
        }
    }

    public List<ScreenshotData> GetScreenshots()
    {
        var list = new List<ScreenshotData>();
        using var conn = new SqliteConnection(_connectionString);
        conn.Open();
        using var cmd = new SqliteCommand(
            "SELECT Id, ImagePath, OcrText, Timestamp FROM Screenshots ORDER BY Timestamp DESC, Id DESC;", conn);
        using var reader = cmd.ExecuteReader();
        while (reader.Read())
        {
            list.Add(new ScreenshotData
            {
                Id = reader.GetInt32(0),
                ImagePath = reader.GetString(1),
                OcrText = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                Timestamp = reader.GetDateTime(3)
            });
        }
        return list;
    }

    public void DeleteScreenshot(int id, string imagePath)
    {
        using var conn = new SqliteConnection(_connectionString);
        conn.Open();
        using var cmd = new SqliteCommand("DELETE FROM Screenshots WHERE Id = @Id;", conn);
        cmd.Parameters.AddWithValue("@Id", id);
        cmd.ExecuteNonQuery();
        TryDeleteFile(imagePath);
    }

    public void ClearHistory()
    {
        var files = new List<string>();
        using (var conn = new SqliteConnection(_connectionString))
        {
            conn.Open();
            using var select = new SqliteCommand("SELECT ImagePath FROM Screenshots;", conn);
            using var reader = select.ExecuteReader();
            while (reader.Read()) files.Add(reader.GetString(0));
            using var del = new SqliteCommand("DELETE FROM Screenshots;", conn);
            del.ExecuteNonQuery();
        }
        foreach (var file in files) TryDeleteFile(file);
    }

    private static void TryDeleteFile(string path)
    {
        if (!File.Exists(path)) return;
        try { File.Delete(path); }
        catch (Exception ex) { System.Diagnostics.Debug.WriteLine($"Delete failed: {ex.Message}"); }
    }
}

public sealed class ScreenshotData
{
    public int Id { get; init; }
    public required string ImagePath { get; init; }
    public required string OcrText { get; init; }
    public DateTime Timestamp { get; init; }
}

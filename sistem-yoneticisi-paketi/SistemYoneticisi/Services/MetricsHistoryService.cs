using Microsoft.Data.Sqlite;

namespace SistemYoneticisi.Services;

public class MetricsHistoryService : IDisposable
{
    private readonly SqliteConnection _connection;

    public MetricsHistoryService() : this(AppPaths.HistoryDb) { }

    internal MetricsHistoryService(string dbPath)
    {
        AppPaths.EnsureDirectories();
        var dir = Path.GetDirectoryName(dbPath);
        if (!string.IsNullOrEmpty(dir))
            Directory.CreateDirectory(dir);

        _connection = new SqliteConnection($"Data Source={dbPath}");
        _connection.Open();
        EnsureSchema();
    }

    private void EnsureSchema()
    {
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = """
            CREATE TABLE IF NOT EXISTS metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                recorded_at TEXT NOT NULL,
                cpu REAL NOT NULL,
                ram REAL NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_metrics_recorded_at ON metrics(recorded_at);
            """;
        cmd.ExecuteNonQuery();
    }

    public void RecordSample(double cpu, double ram)
    {
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "INSERT INTO metrics (recorded_at, cpu, ram) VALUES ($at, $cpu, $ram)";
        cmd.Parameters.AddWithValue("$at", DateTime.UtcNow.ToString("O"));
        cmd.Parameters.AddWithValue("$cpu", cpu);
        cmd.Parameters.AddWithValue("$ram", ram);
        cmd.ExecuteNonQuery();
    }

    public void PruneOlderThanHours(int hours)
    {
        var cutoff = DateTime.UtcNow.AddHours(-hours).ToString("O");
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "DELETE FROM metrics WHERE recorded_at < $cutoff";
        cmd.Parameters.AddWithValue("$cutoff", cutoff);
        cmd.ExecuteNonQuery();
    }

    public List<MetricSample> GetRecentMinutes(int minutes)
    {
        var cutoff = DateTime.UtcNow.AddMinutes(-minutes).ToString("O");
        var list = new List<MetricSample>();

        using var cmd = _connection.CreateCommand();
        cmd.CommandText = """
            SELECT recorded_at, cpu, ram FROM metrics
            WHERE recorded_at >= $cutoff
            ORDER BY recorded_at ASC
            """;
        cmd.Parameters.AddWithValue("$cutoff", cutoff);

        using var reader = cmd.ExecuteReader();
        while (reader.Read())
        {
            list.Add(new MetricSample
            {
                RecordedAt = DateTime.Parse(reader.GetString(0), null, System.Globalization.DateTimeStyles.RoundtripKind),
                Cpu = reader.GetDouble(1),
                Ram = reader.GetDouble(2)
            });
        }

        return list;
    }

    public void ExportCsv(string filePath, int hours = 24)
    {
        var cutoff = DateTime.UtcNow.AddHours(-hours).ToString("O");
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = """
            SELECT recorded_at, cpu, ram FROM metrics
            WHERE recorded_at >= $cutoff
            ORDER BY recorded_at ASC
            """;
        cmd.Parameters.AddWithValue("$cutoff", cutoff);

        using var writer = new StreamWriter(filePath);
        writer.WriteLine("recorded_at_utc,cpu_percent,ram_percent");

        using var reader = cmd.ExecuteReader();
        while (reader.Read())
        {
            writer.WriteLine($"{reader.GetString(0)},{reader.GetDouble(1)},{reader.GetDouble(2)}");
        }
    }

    public void Dispose()
    {
        _connection.Close();
        _connection.Dispose();
        SqliteConnection.ClearAllPools();
    }
}

public class MetricSample
{
    public DateTime RecordedAt { get; set; }
    public double Cpu { get; set; }
    public double Ram { get; set; }
}

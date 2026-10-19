using System.Diagnostics;
using System.IO;
using HizliDosyaArama.Helpers;
using HizliDosyaArama.Services;
using Microsoft.Data.Sqlite;
using Xunit;

namespace HizliDosyaArama.Tests;

public sealed class TempDir : IDisposable
{
    public string Path { get; } = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "hizli-test-" + Guid.NewGuid().ToString("N"));
    public TempDir() => Directory.CreateDirectory(Path);
    public string Combine(params string[] parts) => System.IO.Path.Combine([Path, .. parts]);
    public string Write(string relative, string content = "x")
    {
        var p = Combine(relative);
        Directory.CreateDirectory(System.IO.Path.GetDirectoryName(p)!);
        File.WriteAllText(p, content);
        return p;
    }
    public void Dispose()
    {
        SqliteConnection.ClearAllPools();
        try { Directory.Delete(Path, true); } catch (IOException) { }
    }
}

public class DatabaseServiceTests : IDisposable
{
    private readonly TempDir _tmp = new();
    public void Dispose() => _tmp.Dispose();

    private static IndexedFileData F(string path) => new()
    {
        FileName = Path.GetFileName(path),
        FilePath = path,
        Extension = Path.GetExtension(path),
        Size = 1,
        LastWriteTime = new DateTime(2025, 1, 2, 3, 4, 5)
    };

    private DatabaseService Seeded()
    {
        var db = new DatabaseService(_tmp.Path);
        db.BulkInsertFiles([
            F(@"C:\d\Rapor 2024.pdf"), F(@"C:\d\rapor 2024.docx"), F(@"C:\d\yillik rapor.pdf"),
            F(@"C:\d\2024 butce.xlsx"), F(@"C:\d\my_notes.txt"), F(@"C:\d\mynotes.txt"), F(@"C:\d\100% done.md")
        ]);
        return db;
    }

    private static string[] Names(IEnumerable<IndexedFileData> r) => r.Select(x => x.FileName).ToArray();

    [Fact]
    public void Single_word_matches_substring_with_prefix_first()
    {
        var hits = Names(Seeded().SearchFiles("rapor"));
        Assert.Equal(3, hits.Length);
        Assert.Equal("yillik rapor.pdf", hits[^1]);
        Assert.Equal(new DateTime(2025, 1, 2, 3, 4, 5), Seeded().SearchFiles("yillik")[0].LastWriteTime);
    }

    [Fact]
    public void Multiple_words_match_in_any_order()
    {
        Assert.Equal(["2024 butce.xlsx"], Names(Seeded().SearchFiles("butce 2024")));
        Assert.Equal(2, Seeded().SearchFiles("2024 rapor").Count);
    }

    [Fact]
    public void Dot_word_filters_by_extension_case_insensitively()
    {
        var db = Seeded();
        Assert.Equal(["Rapor 2024.pdf", "yillik rapor.pdf"], Names(db.SearchFiles("rapor .PDF")).Order().ToArray());
        Assert.Equal(["2024 butce.xlsx"], Names(db.SearchFiles(".xlsx")));
        Assert.Equal(3, db.SearchFiles("rapor .pdf .docx").Count);
    }

    [Fact]
    public void Like_wildcards_are_literal()
    {
        var db = Seeded();
        Assert.Equal(["my_notes.txt"], Names(db.SearchFiles("my_")));
        Assert.Equal(["100% done.md"], Names(db.SearchFiles("%")));
        Assert.Empty(db.SearchFiles("   "));
    }

    [Fact]
    public void Recent_files_are_ordered_unique_and_capped_at_50()
    {
        var db = new DatabaseService(_tmp.Path);
        for (var i = 0; i < 55; i++)
            db.RecordRecentAccess(F($@"C:\r\f{i}.txt"));
        db.RecordRecentAccess(F(@"C:\r\f54.txt"));

        var recent = db.GetRecentFiles(100);
        Assert.Equal(50, recent.Count);
        Assert.Equal(50, recent.Select(r => r.FilePath).Distinct().Count());
    }

    [Fact]
    public void Remove_file_drops_it_from_index_and_recent()
    {
        var db = Seeded();
        var path = @"C:\d\mynotes.txt";
        db.RecordRecentAccess(F(path));

        db.RemoveFile(path);
        Assert.DoesNotContain(db.SearchFiles("mynotes"), r => r.FilePath == path);
        Assert.Empty(db.GetRecentFiles());
        Assert.Equal(6, db.GetIndexedCount());
    }

    [Fact]
    public void Clear_empties_index_but_keeps_recent()
    {
        var db = Seeded();
        db.RecordRecentAccess(F(@"C:\d\mynotes.txt"));
        db.ClearDatabase();
        Assert.Equal(0, db.GetIndexedCount());
        Assert.Single(db.GetRecentFiles());
    }

    [Fact]
    public void Legacy_data_is_copied_once_and_never_overwritten()
    {
        var legacy = Directory.CreateDirectory(_tmp.Combine("legacy")).FullName;
        var target = _tmp.Combine("new");
        File.WriteAllText(Path.Combine(legacy, "search_index.db"), "eski-db");
        File.WriteAllText(Path.Combine(legacy, "aliases.json"), "[]");

        DatabaseService.MigrateLegacyData(legacy, target);
        Assert.Equal("eski-db", File.ReadAllText(Path.Combine(target, "search_index.db")));
        Assert.Equal("[]", File.ReadAllText(Path.Combine(target, "aliases.json")));

        File.WriteAllText(Path.Combine(target, "search_index.db"), "yeni-db");
        DatabaseService.MigrateLegacyData(legacy, target);
        Assert.Equal("yeni-db", File.ReadAllText(Path.Combine(target, "search_index.db")));
    }

    [Fact]
    public void Data_folder_honours_env_override()
    {
        var old = Environment.GetEnvironmentVariable(DatabaseService.DataDirEnvVar);
        try
        {
            Environment.SetEnvironmentVariable(DatabaseService.DataDirEnvVar, _tmp.Path);
            Assert.Equal(_tmp.Path, DatabaseService.ResolveDataFolder());
            Environment.SetEnvironmentVariable(DatabaseService.DataDirEnvVar, null);
            Assert.EndsWith("HizliDosyaArama", DatabaseService.ResolveDataFolder());
        }
        finally { Environment.SetEnvironmentVariable(DatabaseService.DataDirEnvVar, old); }
    }
}

public class IndexerServiceTests : IDisposable
{
    private readonly TempDir _tmp = new();
    public void Dispose() => _tmp.Dispose();

    [Fact]
    public async Task Indexes_folder_tree_skipping_noise_and_replacing_old_index()
    {
        var root = _tmp.Combine("kaynak");
        _tmp.Write(@"kaynak\rapor.pdf");
        _tmp.Write(@"kaynak\alt\derin\not.md");
        _tmp.Write(@"kaynak\node_modules\paket.js");
        _tmp.Write(@"kaynak\.git\config");
        _tmp.Write(@"kaynak\bin\app.dll");
        for (var i = 0; i < 1500; i++) _tmp.Write($@"kaynak\cok\dosya{i}.txt"); // toplu yazma sınırını (1000) aşar

        var db = new DatabaseService(_tmp.Combine("data"));
        db.BulkInsertFiles([new IndexedFileData { FileName = "eski.txt", FilePath = @"C:\yok\eski.txt", Extension = ".txt" }]);

        var indexer = new IndexerService(db, [root, _tmp.Combine("olmayan-klasor")]);
        var done = new TaskCompletionSource();
        indexer.IndexingCompleted += () => done.TrySetResult();
        indexer.StartIndexing();
        await done.Task.WaitAsync(TimeSpan.FromSeconds(60));

        Assert.Equal(1502, db.GetIndexedCount());
        Assert.Single(db.SearchFiles("not.md"));
        Assert.Empty(db.SearchFiles("paket"));
        Assert.Empty(db.SearchFiles("eski"));
        Assert.Equal(".pdf", db.SearchFiles("rapor")[0].Extension);
    }
}

public class FileHelperTests
{
    [Fact]
    public void Highlight_splits_name_case_insensitively()
    {
        FileHelper.ApplyHighlight("Yillik Rapor.pdf", "rapor", out var before, out var hl, out var after);
        Assert.Equal(("Yillik ", "Rapor", ".pdf"), (before, hl, after));

        FileHelper.ApplyHighlight("abc.txt", "z", out before, out hl, out after);
        Assert.Equal(("abc.txt", null, ""), (before, hl, after));
    }

    [Fact]
    public void Icon_kind_and_short_path()
    {
        Assert.Equal(FileIconKind.Code, FileHelper.GetIconKind(".CS"));
        Assert.Equal(FileIconKind.Config, FileHelper.GetIconKind(".json"));
        Assert.Equal(FileIconKind.Folder, FileHelper.GetIconKind(""));
        Assert.Equal(FileIconKind.Doc, FileHelper.GetIconKind(".bilinmeyen"));

        var longPath = @"C:\" + new string('a', 100);
        Assert.Equal(51, FileHelper.ShortenPath(longPath).Length);
        Assert.StartsWith("...", FileHelper.ShortenPath(longPath));
        Assert.Equal(@"C:\kisa", FileHelper.ShortenPath(@"C:\kisa"));
    }
}

public class StartupSmokeTests : IDisposable
{
    private readonly TempDir _tmp = new();
    public void Dispose() => _tmp.Dispose();

    [Fact]
    public void App_starts_with_temp_data_dir_and_second_instance_exits()
    {
        // Kullanıcının açık bir örneği varsa (tek örnek + Alt+F) atla.
        if (Process.GetProcessesByName("HizliDosyaArama").Length > 0)
            return;

        var exe = Path.Combine(AppContext.BaseDirectory, "HizliDosyaArama.exe");
        Assert.True(File.Exists(exe), $"exe yok: {exe}");

        ProcessStartInfo Psi()
        {
            var psi = new ProcessStartInfo(exe) { UseShellExecute = false };
            psi.Environment[DatabaseService.DataDirEnvVar] = _tmp.Path;
            return psi;
        }

        using var proc = Process.Start(Psi())!;
        try
        {
            Assert.False(proc.WaitForExit(5000), "Uygulama erken kapandi");
            Assert.True(File.Exists(_tmp.Combine("search_index.db")), "Veri klasoru gecersiz kilinamadi");
            Assert.True(File.Exists(_tmp.Combine("aliases.json")));

            using var second = Process.Start(Psi())!;
            Assert.True(second.WaitForExit(10000), "Ikinci ornek kapanmadi (tek ornek calismiyor)");
            Assert.False(proc.HasExited);
        }
        finally
        {
            if (!proc.HasExited) { proc.Kill(entireProcessTree: true); proc.WaitForExit(5000); }
        }
    }
}

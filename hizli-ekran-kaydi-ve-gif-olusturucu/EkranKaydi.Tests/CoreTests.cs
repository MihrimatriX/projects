using System.Diagnostics;
using System.Globalization;
using System.IO;
using EkranKaydi.Services;
using EkranKaydi.ViewModels;
using Microsoft.Data.Sqlite;
using Xunit;

namespace EkranKaydi.Tests;

public sealed class TempDir : IDisposable
{
    public string Path { get; } = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "ekrankaydi-test-" + Guid.NewGuid().ToString("N"));
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

    [Fact]
    public void Save_and_list_newest_first()
    {
        var db = new DatabaseService(_tmp.Path);
        db.SaveRecording(_tmp.Write("a.mp4"), "MP4", 1.5, 640, 480);
        db.SaveRecording(_tmp.Write("b.gif"), "GIF", 2, 320, 240);

        var list = db.GetRecordings();
        Assert.Equal(2, list.Count);
        Assert.EndsWith("b.gif", list[0].FilePath);
        Assert.Equal("GIF", list[0].Type);
        Assert.Equal(320, list[0].Width);
        Assert.Equal(1.5, list[1].DurationSeconds);
        Assert.True(Directory.Exists(db.RecordingsFolder));
    }

    [Fact]
    public void History_is_capped_but_old_files_are_kept()
    {
        var db = new DatabaseService(_tmp.Path);
        var files = Enumerable.Range(0, DatabaseService.HistoryLimit + 3).Select(i => _tmp.Write($"r{i}.mp4")).ToList();
        foreach (var f in files) db.SaveRecording(f, "MP4", 1, 100, 100);

        var list = db.GetRecordings();
        Assert.Equal(DatabaseService.HistoryLimit, list.Count);
        Assert.Equal(files[^1], list[0].FilePath);
        Assert.DoesNotContain(list, r => r.FilePath == files[0]);
        Assert.All(files, f => Assert.True(File.Exists(f), $"Geçmişten düşen dosya silinmemeli: {f}"));
    }

    [Fact]
    public void Delete_removes_row_and_file_clear_removes_all()
    {
        var db = new DatabaseService(_tmp.Path);
        var a = _tmp.Write("a.mp4");
        var b = _tmp.Write("b.mp4");
        var idA = (int)db.SaveRecording(a, "MP4", 1, 10, 10);
        db.SaveRecording(b, "MP4", 1, 10, 10);

        db.DeleteRecording(idA, a);
        Assert.False(File.Exists(a));
        Assert.Single(db.GetRecordings());

        db.ClearHistory();
        Assert.Empty(db.GetRecordings());
        Assert.False(File.Exists(b));
    }

    [Fact]
    public void Legacy_history_next_to_exe_is_migrated_once()
    {
        var legacy = _tmp.Combine("eski");
        new DatabaseService(legacy).SaveRecording(_tmp.Write("a.mp4"), "MP4", 1, 10, 10);
        _tmp.Write(@"eski\thumbnails\thumb_1.png");
        SqliteConnection.ClearAllPools();

        var target = _tmp.Combine("yeni");
        Assert.Equal(target, DatabaseService.MigrateLegacy(legacy, target));
        Assert.True(File.Exists(Path.Combine(target, "thumbnails", "thumb_1.png")));
        var db = new DatabaseService(target);
        Assert.Single(db.GetRecordings());

        db.ClearHistory(); // hedefte db varsa tekrar kopyalanmaz
        DatabaseService.MigrateLegacy(legacy, target);
        Assert.Empty(new DatabaseService(target).GetRecordings());
    }

    [Fact]
    public void Data_persists_across_instances()
    {
        new DatabaseService(_tmp.Path).SaveRecording(_tmp.Write("a.mp4"), "MP4", 3, 10, 10);
        Assert.Single(new DatabaseService(_tmp.Path).GetRecordings());
    }
}

public class PathAndHelperTests : IDisposable
{
    private readonly TempDir _tmp = new();
    public void Dispose() => _tmp.Dispose();

    [Fact]
    public void Data_dir_env_override_and_default_is_localappdata()
    {
        var old = Environment.GetEnvironmentVariable(AppPaths.DataDirEnvVar);
        try
        {
            Environment.SetEnvironmentVariable(AppPaths.DataDirEnvVar, _tmp.Path);
            Assert.Equal(_tmp.Path, AppPaths.DataFolder);
            Assert.StartsWith(_tmp.Path, AppPaths.TempRecordingPath);

            Environment.SetEnvironmentVariable(AppPaths.DataDirEnvVar, null);
            Assert.Equal(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "EkranKaydi"), AppPaths.DataFolder);
        }
        finally { Environment.SetEnvironmentVariable(AppPaths.DataDirEnvVar, old); }
    }

    [Fact]
    public void Ffmpeg_locator_returns_null_when_missing_and_finds_folder_when_present()
    {
        var empty = _tmp.Combine("bos");
        Directory.CreateDirectory(empty);
        Assert.Null(FfmpegService.FindBinaryFolder([empty, "", "   ", _tmp.Combine("yok")]));

        var bin = Path.GetDirectoryName(_tmp.Write(@"kurulu\bin\ffmpeg.exe"))!;
        Assert.Equal(bin, FfmpegService.FindBinaryFolder([empty, bin]));
    }

    [Fact]
    public void Ffmpeg_candidates_include_bundled_and_winget_locations()
    {
        var c = FfmpegService.CandidateFolders().ToList();
        Assert.Equal(Path.Combine(AppContext.BaseDirectory, "ffmpeg"), c[0]);
        Assert.Contains(c, f => f.EndsWith(@"WinGet\Links", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void Missing_message_is_turkish_and_has_winget_command()
    {
        Assert.Contains("winget install Gyan.FFmpeg", FfmpegService.MissingMessage);
        Assert.Contains("bulunamadı", FfmpegService.MissingMessage);
    }

    [Theory]
    [InlineData(641, 640)]
    [InlineData(640, 640)]
    [InlineData(0, 640)]
    [InlineData(-5, 640)]
    public void NormalizeEvenWidth(int input, int expected) => Assert.Equal(expected, FfmpegService.NormalizeEvenWidth(input));

    [Theory]
    [InlineData(@"C:\a\klip.MP4", true)]
    [InlineData(@"C:\a\klip.webm", true)]
    [InlineData(@"C:\a\resim.gif", false)]
    [InlineData(@"C:\a\metin.txt", false)]
    public void Supported_video_extensions(string path, bool expected) => Assert.Equal(expected, MainViewModel.IsSupportedVideo(path));

    [Fact]
    public async Task Media_info_of_missing_file_is_empty()
    {
        var info = await FfmpegService.GetMediaInfoAsync(_tmp.Combine("yok.mp4"));
        Assert.Equal(0, info.DurationSeconds);
    }
}

/// <summary>Depodaki ffmpeg ile gerçek kırp + GIF + küçük resim akışı (ekran yakalamadan, lavfi test videosu).</summary>
public class FfmpegPipelineTests : IDisposable
{
    private readonly TempDir _tmp = new();
    public void Dispose() => _tmp.Dispose();

    [Fact]
    public async Task Trim_gif_and_thumbnail_with_bundled_ffmpeg_under_turkish_culture()
    {
        var folder = FfmpegService.BinaryFolder;
        Assert.True(folder != null, "Test çıktısında ffmpeg bulunamadı (EkranKaydi\\ffmpeg.exe depoda olmalı).");

        var src = _tmp.Combine("kaynak.mp4");
        using (var p = Process.Start(new ProcessStartInfo(Path.Combine(folder!, "ffmpeg.exe"),
                   $"-y -f lavfi -i testsrc=duration=3:size=320x240:rate=15 -c:v libx264 -pix_fmt yuv420p \"{src}\"")
               { UseShellExecute = false, CreateNoWindow = true, RedirectStandardError = true })!)
        {
            await p.StandardError.ReadToEndAsync();
            await p.WaitForExitAsync();
            Assert.Equal(0, p.ExitCode);
        }

        var info = await FfmpegService.GetMediaInfoAsync(src);
        Assert.InRange(info.DurationSeconds, 2.5, 3.5);
        Assert.Equal(320, info.Width);

        var oldCulture = CultureInfo.CurrentCulture;
        CultureInfo.CurrentCulture = new CultureInfo("tr-TR"); // "0,500" üretirse ffmpeg reddeder
        try
        {
            var trimmed = _tmp.Combine("kirp.mp4");
            await FfmpegService.TrimVideoAsync(src, trimmed, 0.5, 1.5);
            var trimmedInfo = await FfmpegService.GetMediaInfoAsync(trimmed);
            Assert.InRange(trimmedInfo.DurationSeconds, 0.8, 1.3);

            var gif = _tmp.Combine("out.gif");
            await FfmpegService.ConvertMp4ToGifAsync(trimmed, gif, 10, 161);
            var header = new byte[6];
            await using (var fs = File.OpenRead(gif)) fs.ReadExactly(header);
            Assert.Equal("GIF89a", System.Text.Encoding.ASCII.GetString(header));
            Assert.Equal(160, (await FfmpegService.GetMediaInfoAsync(gif)).Width);

            var thumb = _tmp.Combine("thumbs", "t.png");
            await FfmpegService.GenerateFirstFrameThumbnailAsync(trimmed, thumb);
            Assert.True(new FileInfo(thumb).Length > 100);
        }
        finally { CultureInfo.CurrentCulture = oldCulture; }
    }

    [Fact]
    public async Task Ffmpeg_failure_surfaces_as_exception()
    {
        Assert.NotNull(FfmpegService.BinaryFolder);
        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            FfmpegService.TrimVideoAsync(_tmp.Combine("yok.mp4"), _tmp.Combine("o.mp4"), 0, 1));
    }
}

public class StartupSmokeTests : IDisposable
{
    private readonly TempDir _tmp = new();
    public void Dispose() => _tmp.Dispose();

    [Fact]
    public void App_starts_with_temp_data_dir()
    {
        // Kullanıcının açık bir örneği varsa (Ctrl+Alt+R kısayolu ona ait) atla.
        if (Process.GetProcessesByName("EkranKaydi").Length > 0)
            return;

        var exe = Path.Combine(AppContext.BaseDirectory, "EkranKaydi.exe");
        Assert.True(File.Exists(exe), $"exe yok: {exe}");

        var psi = new ProcessStartInfo(exe) { UseShellExecute = false };
        psi.Environment[AppPaths.DataDirEnvVar] = _tmp.Path;
        using var proc = Process.Start(psi)!;
        try
        {
            Assert.False(proc.WaitForExit(5000), "Uygulama erken kapandı");
            Assert.True(File.Exists(_tmp.Combine("recordings.db")), "Veri klasörü ortam değişkeniyle değiştirilemedi");
            Assert.False(File.Exists(_tmp.Combine("crash.log")), "Açılışta yakalanmayan hata oluştu");
        }
        finally
        {
            if (!proc.HasExited) { proc.Kill(entireProcessTree: true); proc.WaitForExit(5000); }
        }
    }
}

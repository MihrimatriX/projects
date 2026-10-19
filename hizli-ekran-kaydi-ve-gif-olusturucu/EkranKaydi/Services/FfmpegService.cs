using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text;
using FFMpegCore;

namespace EkranKaydi.Services;

public class FfmpegService
{
    private Process? _recordingProcess;

    public const string MissingMessage =
        "ffmpeg bulunamadı. Kayıt, kırpma ve GIF/MP4 dışa aktarma için ffmpeg gerekir.\n\n" +
        "Kurmak için PowerShell'de şunu çalıştırın:\n\n    winget install Gyan.FFmpeg\n\n" +
        "Kurulumdan sonra işlemi yeniden deneyin. Geçmiş, önizleme, dosyayı açma/kopyalama ve silme ffmpeg olmadan da çalışır.";

    private static string? _binaryFolder;

    public bool IsRecording => _recordingProcess is { HasExited: false };

    /// <summary>ffmpeg.exe'nin bulunduğu klasör ya da null. Bulunamazsa her çağrıda yeniden aranır
    /// (uygulama açıkken winget ile kurulursa yeniden başlatmadan algılanır).</summary>
    public static string? BinaryFolder
    {
        get
        {
            if (_binaryFolder != null) return _binaryFolder;
            _binaryFolder = FindBinaryFolder(CandidateFolders());
            if (_binaryFolder != null)
                GlobalFFOptions.Configure(new FFOptions { BinaryFolder = _binaryFolder });
            return _binaryFolder;
        }
    }

    public static bool IsAvailable => BinaryFolder != null;

    internal static string? FindBinaryFolder(IEnumerable<string> folders) =>
        folders.FirstOrDefault(f => !string.IsNullOrWhiteSpace(f) && File.Exists(Path.Combine(f, "ffmpeg.exe")));

    // Sıra: uygulamayla gelen kopya (ffmpeg\ alt klasörü veya exe yanı), PATH, winget kurulum konumları.
    internal static IEnumerable<string> CandidateFolders()
    {
        var baseDir = AppContext.BaseDirectory;
        yield return Path.Combine(baseDir, "ffmpeg");
        yield return baseDir;

        foreach (var p in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            yield return p.Trim('"');

        var winget = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Microsoft", "WinGet");
        yield return Path.Combine(winget, "Links");
        yield return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "WinGet", "Links");

        // PATH bu süreçte eski olabilir: Packages\Gyan.FFmpeg_...\ffmpeg-7.x-full_build\bin\ffmpeg.exe
        var packages = Path.Combine(winget, "Packages");
        if (!Directory.Exists(packages)) yield break;
        foreach (var pkg in Directory.EnumerateDirectories(packages, "Gyan.FFmpeg*"))
        foreach (var build in Directory.EnumerateDirectories(pkg))
            yield return Path.Combine(build, "bin");
    }

    private static string FfmpegPath =>
        Path.Combine(BinaryFolder ?? throw new FileNotFoundException(MissingMessage), "ffmpeg.exe");

    public static void EnsureAvailable()
    {
        if (!IsAvailable) throw new FileNotFoundException(MissingMessage);
    }

    public void StartRecording(string outputMp4Path, int x, int y, int w, int h, int fps, bool drawMouse)
    {
        EnsureAvailable();
        if (IsRecording) return;

        // libx264 + yuv420p tek sayılı genişlik/yükseklik kabul etmez
        if (w % 2 != 0) w--;
        if (h % 2 != 0) h--;

        var args = $"-y -f gdigrab -framerate {fps} -draw_mouse {(drawMouse ? 1 : 0)} " +
                   $"-offset_x {x} -offset_y {y} -video_size {w}x{h} -i desktop " +
                   $"-c:v libx264 -preset ultrafast -pix_fmt yuv420p \"{outputMp4Path}\"";

        _recordingProcess = Process.Start(new ProcessStartInfo
        {
            FileName = FfmpegPath,
            Arguments = args,
            UseShellExecute = false,
            CreateNoWindow = true,
            // stdin: durdurmak için 'q' yazılır, ffmpeg MP4'ü düzgün kapatır (Kill dosyayı bozar).
            // stderr yönlendirilmez: okunmayan pipe dolunca ffmpeg bloklanır ve kayıt donar.
            RedirectStandardInput = true
        }) ?? throw new InvalidOperationException("ffmpeg kayıt başlatılamadı.");
    }

    public async Task StopRecordingAsync()
    {
        if (_recordingProcess == null) return;

        try
        {
            if (!_recordingProcess.HasExited)
            {
                await _recordingProcess.StandardInput.WriteAsync("q");
                await _recordingProcess.StandardInput.FlushAsync();
                using var cts = new CancellationTokenSource(8000);
                await _recordingProcess.WaitForExitAsync(cts.Token);
            }
        }
        catch
        {
            if (!_recordingProcess.HasExited)
                _recordingProcess.Kill();
        }
        finally
        {
            _recordingProcess.Dispose();
            _recordingProcess = null;
        }
    }

    public static Task ConvertMp4ToGifAsync(string mp4Path, string gifPath, int fps, int width)
    {
        EnsureAvailable();
        width = NormalizeEvenWidth(width);

        // ponytail: two-pass palette; stats_mode=diff keeps GIF size sane
        var filter = $"fps={fps},scale={width}:-1:flags=lanczos:force_original_aspect_ratio=decrease," +
                     $"split[s0][s1];[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3";
        return RunFfmpegAsync($"-y -i \"{mp4Path}\" -filter_complex \"{filter}\" \"{gifPath}\"");
    }

    public static Task TrimVideoAsync(string inputPath, string outputPath, double startSec, double endSec)
    {
        EnsureAvailable();
        var ss = startSec.ToString("F3", CultureInfo.InvariantCulture);
        var to = endSec.ToString("F3", CultureInfo.InvariantCulture);
        // InvariantCulture şart: tr-TR "1,500" üretir, ffmpeg ondalık nokta bekler.
        // Re-encode: -c copy often breaks short gdigrab clips at non-keyframes
        var args = $"-y -ss {ss} -to {to} -i \"{inputPath}\" " +
                   $"-c:v libx264 -preset ultrafast -pix_fmt yuv420p -movflags +faststart \"{outputPath}\"";
        return RunFfmpegAsync(args);
    }

    public static Task GenerateFirstFrameThumbnailAsync(string videoPath, string outputPath)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);
        return RunFfmpegAsync($"-y -i \"{videoPath}\" -vframes 1 -f image2 \"{outputPath}\"");
    }

    public static async Task<MediaInfoData> GetMediaInfoAsync(string filePath)
    {
        if (!File.Exists(filePath))
            return new MediaInfoData();

        try
        {
            if (!IsAvailable) return new MediaInfoData(); // çağıran MediaElement'e düşer
            var analysis = await FFProbe.AnalyseAsync(filePath);
            return new MediaInfoData
            {
                DurationSeconds = analysis.Duration.TotalSeconds,
                Width = analysis.PrimaryVideoStream?.Width ?? 0,
                Height = analysis.PrimaryVideoStream?.Height ?? 0
            };
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"FFProbe failed: {ex.Message}");
            return new MediaInfoData();
        }
    }

    public static int NormalizeEvenWidth(int width) =>
        width > 0 ? (width % 2 == 0 ? width : width - 1) : 640;

    private static Task RunFfmpegAsync(string arguments) =>
        Task.Run(() =>
        {
            EnsureAvailable();
            var stderr = new StringBuilder();
            using var process = Process.Start(new ProcessStartInfo
            {
                FileName = FfmpegPath,
                Arguments = arguments,
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardError = true
            }) ?? throw new InvalidOperationException("ffmpeg başlatılamadı.");

            process.ErrorDataReceived += (_, e) => { if (e.Data != null) stderr.AppendLine(e.Data); };
            process.BeginErrorReadLine();
            process.WaitForExit();

            if (process.ExitCode != 0)
            {
                var tail = stderr.Length > 600 ? stderr.ToString()[^600..] : stderr.ToString();
                throw new InvalidOperationException($"ffmpeg hata ({process.ExitCode}): {tail.Trim()}");
            }
        });
}

public class MediaInfoData
{
    public double DurationSeconds { get; set; }
    public int Width { get; set; }
    public int Height { get; set; }
}

using System.Diagnostics;
using FlaUI.Core;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Definitions;
using FlaUI.Core.Tools;
using FlaUI.UIA3;

[assembly: AssemblyFixture(typeof(CanliDuvarKagidi.UiTests.AppFixture))]

namespace CanliDuvarKagidi.UiTests;

/// <summary>
/// Uygulamayi bir kez, gecici veri klasoru (CANLI_DUVAR_DATA) ve test kipiyle (CANLI_DUVAR_UITEST=1) acar.
/// Test kipinde "uygula" masaustune pencere gommez ve baslangic kayit anahtarina yazilmaz.
/// </summary>
public sealed class AppFixture : IDisposable
{
    public static readonly TimeSpan Wait = TimeSpan.FromSeconds(15);

    public string DataDir { get; } = Path.Combine(Path.GetTempPath(), "cdk-uitest-" + Guid.NewGuid().ToString("N"));
    public string RepoRoot { get; } = FindRepoRoot();
    public UIA3Automation Automation { get; } = new();
    public Application App { get; }
    public Window Window { get; }

    public AppFixture()
    {
        var exe = Environment.GetEnvironmentVariable("CDK_UITEST_EXE");
        if (string.IsNullOrEmpty(exe))
            exe = Path.Combine(RepoRoot, @"src\CanliDuvarKagidi.Shell\bin\x64\Debug\net10.0-windows10.0.26100.0\win-x64\CanliDuvarKagidi.exe");
        if (!File.Exists(exe))
            throw new FileNotFoundException("Uygulama derlenmemis; once .\\run.ps1 -UiTest (derler) calistirin.", exe);

        var psi = new ProcessStartInfo(exe) { WorkingDirectory = Path.GetDirectoryName(exe)!, UseShellExecute = false };
        psi.Environment["CANLI_DUVAR_DATA"] = DataDir;
        psi.Environment["CANLI_DUVAR_UITEST"] = "1";
        App = Application.Launch(psi);
        Window = App.GetMainWindow(Automation, TimeSpan.FromSeconds(30))
                 ?? throw new InvalidOperationException("Ana pencere acilmadi.");

        // Ilk acilis ornekleri kurar; sayac 0'dan cikinca hazir
        Retry.WhileTrue(() => Text("InstalledCount") is "0" or "", Wait, throwOnTimeout: true);
    }

    public AutomationElement Find(string automationId) =>
        Retry.WhileNull(() => Window.FindFirstDescendant(cf => cf.ByAutomationId(automationId)), Wait, throwOnTimeout: true,
            timeoutMessage: $"Bulunamadi: {automationId}").Result!;

    public string Text(string automationId) =>
        Window.FindFirstDescendant(cf => cf.ByAutomationId(automationId))?.Name ?? "";

    /// <summary>Ogenin ve alt ogelerinin adlari (InfoBar mesaji gibi).</summary>
    public static string AllText(AutomationElement e) =>
        string.Join(" | ", new[] { e.Properties.Name.ValueOrDefault ?? "" }.Concat(e.FindAllDescendants().Select(d => d.Properties.Name.ValueOrDefault ?? "")));

    public void Navigate(string tag, string expectedTitle)
    {
        Find("Nav_" + tag).Patterns.SelectionItem.Pattern.Select();
        Retry.WhileFalse(() => Text("PageTitle") == expectedTitle, Wait, throwOnTimeout: true,
            timeoutMessage: $"Sayfa basligi '{expectedTitle}' olmadi (simdiki: {Text("PageTitle")})");
    }

    /// <summary>InfoBar'da beklenen metin gorunene kadar bekler; tum metni dondurur.</summary>
    public string WaitInfo(string infoBarId, string contains)
    {
        string last = "";
        var ok = Retry.WhileFalse(() =>
        {
            var bar = Window.FindFirstDescendant(cf => cf.ByAutomationId(infoBarId));
            last = bar == null ? "" : AllText(bar);
            return last.Contains(contains, StringComparison.CurrentCulture);
        }, Wait).Result;
        Assert.True(ok, $"{infoBarId} icinde '{contains}' yok. Gorunen: {last}");
        return last;
    }

    public AutomationElement[] GridItems(string gridId) =>
        Find(gridId).FindAllChildren(cf => cf.ByControlType(ControlType.ListItem));

    public void Dispose()
    {
        try
        {
            // Test kipinde pencereyi kapatmak sureci kapatir (tepsi simgesi temizlenir)
            Window.Close();
            var sw = Stopwatch.StartNew();
            while (!App.HasExited && sw.Elapsed < TimeSpan.FromSeconds(10))
                Thread.Sleep(200);
        }
        catch
        {
            // pencere zaten kapanmis olabilir
        }
        finally
        {
            if (!App.HasExited)
                App.Kill();
            App.Dispose();
            Automation.Dispose();
            for (var i = 0; i < 10 && Directory.Exists(DataDir); i++)
            {
                try { Directory.Delete(DataDir, recursive: true); }
                catch (IOException) { Thread.Sleep(300); }
                catch (UnauthorizedAccessException) { Thread.Sleep(300); }
            }
        }
    }

    private static string FindRepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !File.Exists(Path.Combine(dir.FullName, "CanliDuvarKagidi.sln")))
            dir = dir.Parent;
        return dir?.FullName ?? throw new InvalidOperationException("CanliDuvarKagidi.sln bulunamadi.");
    }
}

/// <summary>
/// Gercek klavye/odak gerektiren adimlar icin monorepo ortak kilidi (5 agent ayni masaustunu paylasiyor).
/// </summary>
public sealed class GuiLock : IDisposable
{
    private readonly FileStream _stream;

    private GuiLock(FileStream stream) => _stream = stream;

    public static GuiLock Acquire(string repoRoot)
    {
        var path = Path.Combine(Path.GetDirectoryName(repoRoot)!, ".gui.lock");
        var sw = Stopwatch.StartNew();
        while (true)
        {
            try
            {
                return new GuiLock(new FileStream(path, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None));
            }
            catch (IOException) when (sw.Elapsed < TimeSpan.FromMinutes(5))
            {
                Thread.Sleep(500);
            }
        }
    }

    public void Dispose() => _stream.Dispose();
}

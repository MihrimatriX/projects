using System.Reflection;

namespace SistemYoneticisi.Services;

public static class AppVersion
{
    public static string Version { get; } =
        Assembly.GetExecutingAssembly().GetName().Version?.ToString(3) ?? "1.0.0";

    public static string DisplayName => "Sistem Yöneticisi Paketi";
}

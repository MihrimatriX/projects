using System.Reflection;

namespace ClipboardYoneticisi.Services
{
    public static class AppVersion
    {
        public static Version Current =>
            Assembly.GetExecutingAssembly().GetName().Version ?? new Version(1, 0, 0);

        public static string Display => $"{Current.Major}.{Current.Minor}.{Current.Build}";
    }
}

using System;
using System.IO;

namespace ClipboardYoneticisi.Services
{
    public static class LogService
    {
        private static readonly object Lock = new();

        public static void Info(string message) => Write("INFO", message);
        public static void Warning(string message) => Write("WARN", message);
        public static void Error(string message, Exception? ex = null)
        {
            var detail = ex == null ? message : $"{message} | {ex.GetType().Name}: {ex.Message}";
            Write("ERROR", detail);
        }

        private static void Write(string level, string message)
        {
            try
            {
                AppPaths.EnsureDirectories();
                var line = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss} [{level}] {message}";
                lock (Lock)
                {
                    File.AppendAllText(
                        Path.Combine(AppPaths.LogsFolder, "app.log"),
                        line + Environment.NewLine);
                }
            }
            catch
            {
                // Logging must never crash the app.
            }
        }
    }
}

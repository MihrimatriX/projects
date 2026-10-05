using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using CommunityToolkit.Mvvm.ComponentModel;

namespace SistemYoneticisi.Services
{
    public class ProcessService
    {
        private readonly Dictionary<int, ProcessCpuTracker> _cpuTrackers = new();
        private DateTime _lastCheckTime = DateTime.Now;

        public List<ProcessInfo> GetProcesses()
        {
            var result = new List<ProcessInfo>();
            var processes = Process.GetProcesses();
            var now = DateTime.Now;
            double timeElapsed = (now - _lastCheckTime).TotalMilliseconds;
            _lastCheckTime = now;

            // Get processor count to normalize process CPU usage
            double processorCount = Environment.ProcessorCount;

            foreach (var p in processes)
            {
                // Skip the Idle process
                if (p.Id == 0) continue;

                try
                {
                    double ramMb = Math.Round(p.WorkingSet64 / (1024.0 * 1024.0), 1);
                    string name = p.ProcessName;
                    
                    // Handle CPU calculation
                    double cpuPercentage = 0;
                    try
                    {
                        TimeSpan totalProcessorTime = p.TotalProcessorTime;
                        if (_cpuTrackers.TryGetValue(p.Id, out var tracker))
                        {
                            double cpuTimeMs = (totalProcessorTime - tracker.LastCpuTime).TotalMilliseconds;
                            if (timeElapsed > 0)
                            {
                                // CPU% = (iki ölçüm arası harcanan işlemci süresi / geçen duvar saati) / çekirdek sayısı.
                                // İlk görülen süreç için önceki örnek olmadığından 0 gösterilir.
                                cpuPercentage = Math.Round((cpuTimeMs / timeElapsed / processorCount) * 100.0, 1);
                                if (cpuPercentage < 0) cpuPercentage = 0;
                                if (cpuPercentage > 100) cpuPercentage = 100;
                            }
                            tracker.LastCpuTime = totalProcessorTime;
                            tracker.UpdateTime = now;
                        }
                        else
                        {
                            _cpuTrackers[p.Id] = new ProcessCpuTracker
                            {
                                LastCpuTime = totalProcessorTime,
                                UpdateTime = now
                            };
                        }
                    }
                    catch
                    {
                        // Some processes don't allow reading CPU times
                    }

                    string path = AccessDenied;
                    string description = "Sistem Süreci";

                    try
                    {
                        path = p.MainModule?.FileName ?? "N/A";
                        var versionInfo = p.MainModule?.FileVersionInfo;
                        description = versionInfo?.FileDescription ?? name;
                    }
                    catch
                    {
                        // Access denied on protected processes
                    }

                    result.Add(new ProcessInfo
                    {
                        Pid = p.Id,
                        Name = name,
                        CpuPercentage = cpuPercentage,
                        MemoryMb = ramMb,
                        Path = path,
                        Description = description,
                        IsProtected = IsProtectedProcess(p.Id, name, path)
                    });
                }
                catch
                {
                    // Process exited or protected
                }
                finally
                {
                    p.Dispose();
                }
            }

            // Cleanup trackers for exited processes to prevent memory leak
            var activePids = new HashSet<int>(result.Select(r => r.Pid));
            var deadPids = _cpuTrackers.Keys.Where(pid => !activePids.Contains(pid)).ToList();
            foreach (var pid in deadPids)
            {
                _cpuTrackers.Remove(pid);
            }

            return result;
        }

        public bool KillProcess(int pid)
        {
            try
            {
                using (var p = Process.GetProcessById(pid))
                {
                    // Koruma burada da denetlenir: listedeki PID bayat olabilir (süreç kapanıp PID yeniden kullanılmış olabilir).
                    string path;
                    try { path = p.MainModule?.FileName ?? "N/A"; }
                    catch { path = AccessDenied; }
                    if (IsProtectedProcess(p.Id, p.ProcessName, path))
                    {
                        LogService.Info($"Korunan süreç sonlandırılmadı: {p.ProcessName} ({pid})");
                        return false;
                    }

                    p.Kill(true); // Kill tree to clean up child processes
                    return true;
                }
            }
            catch (Exception ex)
            {
                LogService.Error($"Failed to kill process {pid}", ex);
                return false;
            }
        }

        internal const string AccessDenied = "Erişim Engellendi";

        // Sonlandırılması oturumu/sistemi çökertecek veya güvenliği kapatacak süreçler.
        private static readonly HashSet<string> CriticalProcessNames = new(StringComparer.OrdinalIgnoreCase)
        {
            "System", "Registry", "Secure System", "Memory Compression", "smss", "csrss", "wininit",
            "winlogon", "services", "lsass", "LsaIso", "svchost", "dwm", "fontdrvhost", "MsMpEng", "SgrmBroker"
        };

        internal static bool IsProtectedProcess(int pid, string name, string path)
        {
            if (pid <= 4 || pid == Environment.ProcessId) return true;
            return CriticalProcessNames.Contains(name) || path == AccessDenied;
        }

        /// <summary>Süreç listesini CSV (Excel uyumlu, ; ayraçlı) metnine çevirir.</summary>
        public static string ToCsv(IEnumerable<ProcessInfo> processes)
        {
            static string Q(string v) => "\"" + v.Replace("\"", "\"\"") + "\"";
            var sb = new System.Text.StringBuilder("PID;Ad;CPU %;RAM MB;Açıklama;Yol\r\n");
            foreach (var p in processes)
            {
                sb.Append(p.Pid).Append(';').Append(Q(p.Name)).Append(';')
                  .Append(p.CpuPercentage.ToString(System.Globalization.CultureInfo.InvariantCulture)).Append(';')
                  .Append(p.MemoryMb.ToString(System.Globalization.CultureInfo.InvariantCulture)).Append(';')
                  .Append(Q(p.Description)).Append(';').Append(Q(p.Path)).Append("\r\n");
            }
            return sb.ToString();
        }

        private class ProcessCpuTracker
        {
            public TimeSpan LastCpuTime { get; set; }
            public DateTime UpdateTime { get; set; }
        }
    }

    public partial class ProcessInfo : ObservableObject
    {
        public int Pid { get; set; }
        public string Name { get; set; } = string.Empty;

        [ObservableProperty]
        private double _cpuPercentage;

        [ObservableProperty]
        private double _memoryMb;

        public string Path { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public bool IsProtected { get; set; }
        public bool CanKill => !IsProtected;
        public string DisplayName => IsProtected ? $"🔒 {Name}" : Name;
        public bool IsHighCpu => CpuPercentage >= 50;

        partial void OnCpuPercentageChanged(double value) =>
            OnPropertyChanged(nameof(IsHighCpu));
    }
}

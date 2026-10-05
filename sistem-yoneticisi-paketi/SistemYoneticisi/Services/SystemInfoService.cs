using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Management;
using System.Net.NetworkInformation;
using SistemYoneticisi.Helpers;

namespace SistemYoneticisi.Services
{
    public class SystemInfoService
    {
        private volatile PerformanceCounter? _cpuCounter;
        private volatile PerformanceCounter? _ramCounter;

        // RAM tracking
        private double _totalRamGb;

        // Network tracking
        private long _lastBytesReceived;
        private long _lastBytesSent;
        private DateTime _lastNetworkCheckTime;

        public SystemInfoService()
        {
            // Sayaç oluşturma + WMI sorgusu soğuk açılışta saniyeler sürer ve pencereyi bekletiyordu;
            // arka planda hazırlanır, hazır olana kadar ölçümler 0 döner.
            Task.Run(InitCounters);

            // Initialize Network tracking values
            ResetNetworkMetrics();
        }

        private void InitCounters()
        {
            try
            {
                var cpu = new PerformanceCounter("Processor", "% Processor Time", "_Total");
                // Pre-warm the counter (first call always returns 0)
                cpu.NextValue();
                _cpuCounter = cpu;
            }
            catch (Exception ex)
            {
                LogService.Error("CPU counter initialization error", ex);
            }

            // Toplam RAM, RAM sayacından SONRA atanır: aksi halde sayaç yokken kullanım %100 görünürdü.
            var totalRam = GetTotalPhysicalRamGb();
            try
            {
                _ramCounter = new PerformanceCounter("Memory", "Available MBytes");
            }
            catch (Exception ex)
            {
                LogService.Error("RAM counter initialization error", ex);
            }
            Volatile.Write(ref _totalRamGb, totalRam);
        }

        public double GetCpuUsage()
        {
            try
            {
                return _cpuCounter != null ? Math.Round(_cpuCounter.NextValue(), 1) : 0;
            }
            catch
            {
                return 0;
            }
        }

        public (double UsedGb, double AvailableGb, double TotalGb, double UsagePercentage) GetRamUsage()
        {
            try
            {
                double availableMb = _ramCounter != null ? _ramCounter.NextValue() : 0;
                double availableGb = Math.Round(availableMb / 1024.0, 2);
                double usedGb = Math.Round(_totalRamGb - availableGb, 2);
                if (usedGb < 0) usedGb = 0;
                
                double usagePercent = _totalRamGb > 0 ? Math.Round((usedGb / _totalRamGb) * 100.0, 1) : 0;
                return (usedGb, availableGb, _totalRamGb, usagePercent);
            }
            catch
            {
                return (0, 0, _totalRamGb, 0);
            }
        }

        public List<DiskDriveInfo> GetDiskDrives()
        {
            var drives = new List<DiskDriveInfo>();
            try
            {
                foreach (var drive in DriveInfo.GetDrives())
                {
                    if (drive.IsReady && (drive.DriveType == DriveType.Fixed || drive.DriveType == DriveType.Removable))
                    {
                        double totalGb = Math.Round(drive.TotalSize / (1024.0 * 1024.0 * 1024.0), 1);
                        double freeGb = Math.Round(drive.TotalFreeSpace / (1024.0 * 1024.0 * 1024.0), 1);
                        double usedGb = Math.Round(totalGb - freeGb, 1);
                        double usagePercent = totalGb > 0 ? Math.Round((usedGb / totalGb) * 100.0, 1) : 0;

                        drives.Add(new DiskDriveInfo
                        {
                            Name = drive.Name,
                            VolumeLabel = drive.VolumeLabel,
                            DriveFormat = drive.DriveFormat,
                            TotalGb = totalGb,
                            UsedGb = usedGb,
                            FreeGb = freeGb,
                            UsagePercentage = usagePercent
                        });
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Disk listing error: {ex.Message}");
            }
            return drives;
        }

        public (double DownloadKbps, double UploadKbps) GetNetworkSpeed()
        {
            try
            {
                var interfaces = NetworkInterface.GetAllNetworkInterfaces()
                    .Where(nic => nic.OperationalStatus == OperationalStatus.Up && 
                                  nic.NetworkInterfaceType != NetworkInterfaceType.Loopback && 
                                  nic.NetworkInterfaceType != NetworkInterfaceType.Tunnel)
                    .ToList();

                long currentBytesReceived = 0;
                long currentBytesSent = 0;

                foreach (var nic in interfaces)
                {
                    try
                    {
                        var stats = nic.GetIPStatistics();
                        currentBytesReceived += stats.BytesReceived;
                        currentBytesSent += stats.BytesSent;
                    }
                    catch { /* Ignore errors on interfaces that do not support stats */ }
                }

                DateTime now = DateTime.Now;
                double secondsElapsed = (now - _lastNetworkCheckTime).TotalSeconds;

                if (secondsElapsed <= 0.1) // Avoid division by zero/very small numbers
                {
                    return (0, 0);
                }

                double downloadSpeed = 0;
                double uploadSpeed = 0;

                if (_lastBytesReceived > 0 && _lastBytesSent > 0)
                {
                    long diffReceived = currentBytesReceived - _lastBytesReceived;
                    long diffSent = currentBytesSent - _lastBytesSent;

                    if (diffReceived >= 0)
                    {
                        // Convert bytes to Kilobits per second (Kbps)
                        downloadSpeed = Math.Round(((diffReceived * 8.0) / 1024.0) / secondsElapsed, 1);
                    }
                    if (diffSent >= 0)
                    {
                        uploadSpeed = Math.Round(((diffSent * 8.0) / 1024.0) / secondsElapsed, 1);
                    }
                }

                _lastBytesReceived = currentBytesReceived;
                _lastBytesSent = currentBytesSent;
                _lastNetworkCheckTime = now;

                return (downloadSpeed, uploadSpeed);
            }
            catch
            {
                return (0, 0);
            }
        }

        private void ResetNetworkMetrics()
        {
            _lastBytesReceived = 0;
            _lastBytesSent = 0;
            _lastNetworkCheckTime = DateTime.Now;
        }

        private double GetTotalPhysicalRamGb()
        {
            try
            {
                using (var searcher = new ManagementObjectSearcher("SELECT TotalPhysicalMemory FROM Win32_ComputerSystem"))
                {
                    foreach (var obj in searcher.Get())
                    {
                        double bytes = Convert.ToDouble(obj["TotalPhysicalMemory"]);
                        return Math.Round(bytes / (1024.0 * 1024.0 * 1024.0), 2);
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Failed to get RAM size via WMI: {ex.Message}");
            }

            // Fallback: Default to 8GB if query fails
            return 8.0;
        }
    }

    public class DiskDriveInfo
    {
        public string Name { get; set; } = string.Empty;
        public string VolumeLabel { get; set; } = string.Empty;
        public string DriveFormat { get; set; } = string.Empty;
        public double TotalGb { get; set; }
        public double UsedGb { get; set; }
        public double FreeGb { get; set; }
        public double UsagePercentage { get; set; }

        public bool IsCritical => UsagePercentage >= 90;
        public string DisplayName => string.IsNullOrWhiteSpace(VolumeLabel) ? Name : $"{VolumeLabel} ({Name})";
        public string SizeSummary => FormatHelpers.FormatDiskSummary(UsedGb, TotalGb);
    }
}

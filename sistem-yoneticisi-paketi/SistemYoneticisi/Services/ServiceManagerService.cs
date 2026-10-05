using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Management;

namespace SistemYoneticisi.Services
{
    public class ServiceManagerService
    {
        public List<WindowsServiceInfo> GetServices()
        {
            var services = new List<WindowsServiceInfo>();
            try
            {
                using (var searcher = new ManagementObjectSearcher("SELECT Name, DisplayName, State, StartMode FROM Win32_Service"))
                {
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        services.Add(new WindowsServiceInfo
                        {
                            Name = obj["Name"]?.ToString() ?? string.Empty,
                            DisplayName = obj["DisplayName"]?.ToString() ?? string.Empty,
                            State = obj["State"]?.ToString() ?? string.Empty,
                            StartMode = obj["StartMode"]?.ToString() ?? string.Empty
                        });
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"WMI Services query error: {ex.Message}");
            }
            return services;
        }

        public bool StartService(string serviceName)
        {
            return InvokeServiceMethod(serviceName, "StartService");
        }

        public bool StopService(string serviceName)
        {
            if (IsCriticalService(serviceName)) return false;
            return InvokeServiceMethod(serviceName, "StopService");
        }

        // Durdurulması oturumu düşüren, ağı/RPC'yi kesen veya güvenliği kapatan servisler.
        private static readonly HashSet<string> CriticalServiceNames = new(StringComparer.OrdinalIgnoreCase)
        {
            "RpcSs", "RpcEptMapper", "DcomLaunch", "LSM", "SamSs", "EventLog", "PlugPlay", "Power",
            "ProfSvc", "gpsvc", "BFE", "mpssvc", "WinDefend", "CryptSvc", "Schedule", "SystemEventsBroker",
            "BrokerInfrastructure", "CoreMessagingRegistrar", "Winmgmt", "Dhcp", "Dnscache", "nsi",
            "AudioEndpointBuilder", "Themes", "UserManager", "StateRepository", "TrustedInstaller", "wscsvc"
        };

        public static bool IsCriticalService(string serviceName) => CriticalServiceNames.Contains(serviceName);

        public bool RestartService(string serviceName)
        {
            if (IsCriticalService(serviceName)) return false;
            try
            {
                if (StopService(serviceName))
                {
                    // WMI StopService yalnızca durdurma isteği gönderir; servis gerçekten
                    // "Stopped" olana kadar bekle (en fazla ~15 sn), yoksa StartService başarısız olur.
                    var path = new ManagementPath($"Win32_Service.Name='{serviceName}'");
                    for (var i = 0; i < 60; i++)
                    {
                        using var obj = new ManagementObject(path);
                        obj.Get();
                        if (string.Equals(obj["State"]?.ToString(), "Stopped", StringComparison.OrdinalIgnoreCase))
                            break;
                        System.Threading.Thread.Sleep(250);
                    }
                    return StartService(serviceName);
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error restarting service {serviceName}: {ex.Message}");
            }
            return false;
        }

        private bool InvokeServiceMethod(string serviceName, string methodName)
        {
            try
            {
                var path = new ManagementPath($"Win32_Service.Name='{serviceName}'");
                using (var obj = new ManagementObject(path))
                {
                    var result = obj.InvokeMethod(methodName, null);
                    int returnCode = Convert.ToInt32(result);
                    return returnCode == 0 || returnCode == 10; // 0 = Success, 10 = Service already running/stopped
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error invoking {methodName} on service {serviceName}: {ex.Message}");
            }
            return false;
        }
    }

    public class WindowsServiceInfo
    {
        public string Name { get; set; } = string.Empty;
        public string DisplayName { get; set; } = string.Empty;
        public string State { get; set; } = string.Empty;
        public string StartMode { get; set; } = string.Empty;

        public bool IsRunning => string.Equals(State, "Running", StringComparison.OrdinalIgnoreCase);
        public bool IsCritical => ServiceManagerService.IsCriticalService(Name);
        public string ListName => IsCritical ? $"🔒 {DisplayName}" : DisplayName;
        public string DisplayState => IsRunning ? "Çalışıyor" : "Durduruldu";
    }
}

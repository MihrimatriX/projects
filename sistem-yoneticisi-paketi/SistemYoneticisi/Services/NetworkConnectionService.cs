using System.Diagnostics;
using System.Net;
using System.Runtime.InteropServices;

namespace SistemYoneticisi.Services;

public class NetworkConnectionService
{
    public List<NetworkConnectionInfo> GetConnections()
    {
        var pidNames = BuildProcessNameMap();
        var list = new List<NetworkConnectionInfo>();

        try
        {
            list.AddRange(ReadTcpTable(pidNames));
            list.AddRange(ReadUdpTable(pidNames));
        }
        catch (Exception ex)
        {
            LogService.Error("Network connection scan failed", ex);
        }

        return list.OrderByDescending(c => c.State == "ESTABLISHED")
            .ThenBy(c => c.ProcessName)
            .ToList();
    }

    private static Dictionary<int, string> BuildProcessNameMap()
    {
        var map = new Dictionary<int, string>();
        foreach (var p in Process.GetProcesses())
        {
            try
            {
                map[p.Id] = p.ProcessName;
            }
            catch { /* ignore */ }
            finally
            {
                p.Dispose();
            }
        }
        return map;
    }

    private static IEnumerable<NetworkConnectionInfo> ReadTcpTable(Dictionary<int, string> pidNames)
    {
        var rows = NativeTcp.GetTcpRows();
        foreach (var row in rows)
        {
            var local = FormatEndpoint(row.LocalAddr, row.LocalPort);
            var remote = row.State == (byte)NativeTcp.MibTcpState.Listen
                ? "*:*"
                : FormatEndpoint(row.RemoteAddr, row.RemotePort);

            pidNames.TryGetValue(row.OwningPid, out var name);

            yield return new NetworkConnectionInfo
            {
                Protocol = "TCP",
                LocalAddress = local,
                RemoteAddress = remote,
                State = NativeTcp.StateToString(row.State),
                Pid = row.OwningPid,
                ProcessName = name ?? "—"
            };
        }
    }

    private static IEnumerable<NetworkConnectionInfo> ReadUdpTable(Dictionary<int, string> pidNames)
    {
        var rows = NativeTcp.GetUdpRows();
        foreach (var row in rows)
        {
            pidNames.TryGetValue(row.OwningPid, out var name);
            yield return new NetworkConnectionInfo
            {
                Protocol = "UDP",
                LocalAddress = FormatEndpoint(row.LocalAddr, row.LocalPort),
                RemoteAddress = "*:*",
                State = "—",
                Pid = row.OwningPid,
                ProcessName = name ?? "—"
            };
        }
    }

    private static string FormatEndpoint(uint addr, uint port)
    {
        var ip = new IPAddress(addr);
        var portNum = (ushort)((port >> 8) | ((port & 0xFF) << 8));
        return $"{ip}:{portNum}";
    }
}

public class NetworkConnectionInfo
{
    public string Protocol { get; set; } = string.Empty;
    public string LocalAddress { get; set; } = string.Empty;
    public string RemoteAddress { get; set; } = string.Empty;
    public string State { get; set; } = string.Empty;
    public int Pid { get; set; }
    public string ProcessName { get; set; } = string.Empty;
}

internal static class NativeTcp
{
    private const int AfInet = 2;

    internal enum MibTcpState : byte
    {
        Closed = 1,
        Listen = 2,
        SynSent = 3,
        SynReceived = 4,
        Established = 5,
        FinWait1 = 6,
        FinWait2 = 7,
        CloseWait = 8,
        Closing = 9,
        LastAck = 10,
        TimeWait = 11,
        DeleteTcb = 12
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct MibTcpRowOwnerPid
    {
        public uint State;
        public uint LocalAddr;
        public uint LocalPort;
        public uint RemoteAddr;
        public uint RemotePort;
        public int OwningPid;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct MibUdpRowOwnerPid
    {
        public uint LocalAddr;
        public uint LocalPort;
        public int OwningPid;
    }

    [DllImport("iphlpapi.dll", SetLastError = true)]
    private static extern uint GetExtendedTcpTable(IntPtr pTcpTable, ref int dwOutBufLen, bool sort, int ipVersion, int tblClass, uint reserved);

    [DllImport("iphlpapi.dll", SetLastError = true)]
    private static extern uint GetExtendedUdpTable(IntPtr pUdpTable, ref int dwOutBufLen, bool sort, int ipVersion, int tblClass, uint reserved);

    internal static List<MibTcpRowOwnerPid> GetTcpRows()
    {
        var size = 0;
        _ = GetExtendedTcpTable(IntPtr.Zero, ref size, true, AfInet, 5, 0);
        var ptr = Marshal.AllocHGlobal(size);
        try
        {
            if (GetExtendedTcpTable(ptr, ref size, true, AfInet, 5, 0) != 0)
                return [];

            var count = Marshal.ReadInt32(ptr);
            var rows = new List<MibTcpRowOwnerPid>(count);
            // Tablo düzeni: DWORD dwNumEntries + satır dizisi. Satırlar yalnızca DWORD
            // içerdiği için hizalama 4 bayttır; x64'te de ilk satır ofset 4'tedir.
            var offset = 4;
            var rowPtr = ptr + offset;
            var rowSize = Marshal.SizeOf<MibTcpRowOwnerPid>();

            for (var i = 0; i < count; i++)
            {
                rows.Add(Marshal.PtrToStructure<MibTcpRowOwnerPid>(rowPtr + (i * rowSize)));
            }

            return rows;
        }
        finally
        {
            Marshal.FreeHGlobal(ptr);
        }
    }

    internal static List<MibUdpRowOwnerPid> GetUdpRows()
    {
        var size = 0;
        _ = GetExtendedUdpTable(IntPtr.Zero, ref size, true, AfInet, 1, 0);
        var ptr = Marshal.AllocHGlobal(size);
        try
        {
            if (GetExtendedUdpTable(ptr, ref size, true, AfInet, 1, 0) != 0)
                return [];

            var count = Marshal.ReadInt32(ptr);
            var rows = new List<MibUdpRowOwnerPid>(count);
            var offset = 4;
            var rowPtr = ptr + offset;
            var rowSize = Marshal.SizeOf<MibUdpRowOwnerPid>();

            for (var i = 0; i < count; i++)
            {
                rows.Add(Marshal.PtrToStructure<MibUdpRowOwnerPid>(rowPtr + (i * rowSize)));
            }

            return rows;
        }
        finally
        {
            Marshal.FreeHGlobal(ptr);
        }
    }

    internal static string StateToString(uint state) =>
        Enum.IsDefined(typeof(MibTcpState), (byte)state)
            ? ((MibTcpState)state).ToString().ToUpperInvariant()
            : state.ToString();
}

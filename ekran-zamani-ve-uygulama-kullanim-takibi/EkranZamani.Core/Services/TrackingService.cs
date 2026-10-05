using System;
using System.Timers;
using EkranZamani.Helpers;
using EkranZamani.Models;

namespace EkranZamani.Services
{
    public class TrackingService
    {
        // Tikler arasında bu kadar saniyeden uzun boşluk = bilgisayar uyudu / hazırda bekledi; o süre sayılmaz.
        internal const double SleepGapSeconds = 15;
        // Uzun oturumlar bu aralıkla DB'ye yazılır (çökme / kapanmada en fazla bu kadar veri kaybolur).
        internal const double FlushSeconds = 30;

        private readonly DatabaseService _dbService;
        private readonly Func<AppSettings> _settings;
        private readonly System.Timers.Timer _timer;
        private readonly object _sync = new();

        private IntPtr _lastHwnd = IntPtr.Zero;
        private string _currentProcessName = "System Idle";
        private string _currentTitle = string.Empty;
        private DateTime _sessionStartTime = DateTime.Now;
        private DateTime _lastTick = DateTime.MinValue;
        private bool _isIdle = false;
        private bool _isActive = false;

        private double IdleThresholdSeconds =>
            Math.Clamp(_settings().IdleThresholdMinutes, 1, 120) * 60.0;

        public event Action<string, int>? Ticked;
        public event Action? ActiveAppChanged;

        public TrackingService(DatabaseService dbService, Func<AppSettings>? settings = null)
        {
            _dbService = dbService;
            _settings = settings ?? (() => AppServices.Settings.Current);

            _timer = new System.Timers.Timer(1000); // 1 second
            _timer.Elapsed += Timer_Elapsed;
        }

        public string CurrentProcessName => _currentProcessName;
        public string CurrentTitle => _currentTitle;
        public bool IsTracking => _isActive;

        public void Start()
        {
            lock (_sync)
            {
                if (_isActive) return;
                StartInternal(DateTime.Now);
            }
            _timer.Start();
        }

        internal void StartInternal(DateTime now)
        {
            _isActive = true;
            _sessionStartTime = now;
            _lastTick = now;
            _isIdle = false;
            _lastHwnd = IntPtr.Zero;
            _currentProcessName = string.Empty;
        }

        public void Stop() => Stop(DateTime.Now);

        internal void Stop(DateTime now)
        {
            lock (_sync)
            {
                if (!_isActive) return;
                _isActive = false;
                _timer.Stop();
                SaveCurrentSession(now);
            }
        }

        // System.Timers.Timer iş parçacığı havuzunda çalışır ve tikler üst üste binebilir; durum _sync ile korunur.
        private void Timer_Elapsed(object? sender, ElapsedEventArgs e)
        {
            try
            {
                IntPtr hwnd = Win32Api.GetForegroundWindow();
                string processName = Win32Api.GetProcessNameByHwnd(hwnd);
                // Başlık kaydı kapalıysa başlık hiç okunmaz.
                string title = _settings().LogWindowTitles ? Win32Api.GetActiveWindowTitle(hwnd) : string.Empty;
                bool locked = Win32Api.IsWorkstationLocked() ||
                              processName.Equals("LockApp", StringComparison.OrdinalIgnoreCase);
                double idle = Win32Api.GetIdleTime();

                lock (_sync) Tick(DateTime.Now, idle, locked, hwnd, processName, title);
            }
            catch (Exception ex)
            {
                // Tek bir hatalı tik (ör. DB kilitli) izlemeyi durdurmasın.
                System.Diagnostics.Debug.WriteLine($"Tracking tick: {ex.Message}");
            }
        }

        /// <summary>Bir ölçüm adımı. Girdiler dışarıdan verilir; böylece uyku/kilit/boşta mantığı test edilebilir.</summary>
        internal void Tick(DateTime now, double idleSeconds, bool locked, IntPtr currentHwnd, string processName, string title)
        {
            if (!_isActive) return;

            // 0. Uyku / hazırda bekleme: zamanlayıcı durur, uyanınca ilk tik büyük bir boşluk görür.
            // Oturumu son tik anında kapat; uyku süresi önceki uygulamaya yazılmasın.
            if (_lastTick != DateTime.MinValue && (now - _lastTick).TotalSeconds > SleepGapSeconds)
            {
                SaveCurrentSession(_lastTick);
                _sessionStartTime = now;
            }
            _lastTick = now;

            // 1. Boşta / kilitli: kilit ekranı anında boşta sayılır.
            if (locked || idleSeconds >= IdleThresholdSeconds)
            {
                if (!_isIdle)
                {
                    // Win+L ile kilitte son girdi ~0 sn önce; otomatik kilitte (hareketsizlik) ise girdi kesildiği an.
                    DateTime idleStart = now.AddSeconds(-Math.Max(0, idleSeconds));
                    // Şimdiye kadarki oturumu yaz, sonra eşik süresince periyodik yazılmış boşta süresini geri al.
                    SaveCurrentSession(now);
                    _dbService.TrimWindowUsageAfter(idleStart);
                    _isIdle = true;
                    _lastHwnd = IntPtr.Zero;
                    _currentProcessName = string.Empty;
                    ActiveAppChanged?.Invoke();
                }
                Ticked?.Invoke(locked ? "Kilitli" : "Idle / Boşta", 0);
                return;
            }
            if (_isIdle)
            {
                _isIdle = false;
                _sessionStartTime = now;
            }

            // 2. Ön plan penceresi
            if (string.IsNullOrWhiteSpace(processName) || processName == "Unknown")
                processName = "System";

            if (SensitiveAppFilter.ShouldSkipLogging(processName, _settings().AppBlacklist))
            {
                // Önceki oturumu kapat; yoksa gizli uygulamada geçen süre önceki uygulamaya yazılırdı.
                SaveCurrentSession(now);
                _lastHwnd = IntPtr.Zero;
                _currentProcessName = string.Empty;
                Ticked?.Invoke("Gizli uygulama", 0);
                return;
            }

            if (!_settings().LogWindowTitles) title = string.Empty;
            title = SensitiveAppFilter.SanitizeTitle(processName, title);

            if (currentHwnd != _lastHwnd || processName != _currentProcessName)
            {
                SaveCurrentSession(now);

                _lastHwnd = currentHwnd;
                _currentProcessName = processName;
                _currentTitle = title;
                _sessionStartTime = now;

                ActiveAppChanged?.Invoke();
            }
            else if ((now - _sessionStartTime).TotalSeconds >= FlushSeconds)
            {
                SaveCurrentSession(now);
                _sessionStartTime = now;
                _currentTitle = title;
            }

            Ticked?.Invoke(_currentProcessName, (int)(now - _sessionStartTime).TotalSeconds);
        }

        private void SaveCurrentSession(DateTime end)
        {
            if (_isIdle || string.IsNullOrEmpty(_currentProcessName)) return;

            int duration = (int)(end - _sessionStartTime).TotalSeconds;
            if (duration > 0)
            {
                _dbService.SaveUsageRecord(_currentProcessName, _currentTitle, _sessionStartTime, end, duration);
                _sessionStartTime = end;
            }
        }
    }
}

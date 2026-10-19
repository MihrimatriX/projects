using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Threading;
using OtomasyonMakro.Models;

namespace OtomasyonMakro.Services
{
    public class ScheduleService : IDisposable
    {
        private readonly DatabaseService _dbService;
        private readonly Action<MacroProfile> _onTrigger;
        private readonly Timer _timer;
        private readonly Dictionary<int, string> _lastFired = new();
        private readonly object _lock = new();

        public ScheduleService(DatabaseService dbService, Action<MacroProfile> onTrigger)
        {
            _dbService = dbService;
            _onTrigger = onTrigger;
            // Timer thread-pool'da çalışır; buradan kaçan bir hata tüm süreci çökertir.
            _timer = new Timer(_ => { try { CheckSchedules(); } catch { } }, null, TimeSpan.FromSeconds(10), TimeSpan.FromSeconds(30));
        }

        public void CheckSchedules()
        {
            lock (_lock)
            {
                var now = DateTime.Now;
                foreach (var profile in _dbService.GetProfiles())
                {
                    if (!profile.ScheduleEnabled || profile.Steps.Count == 0)
                    {
                        continue;
                    }

                    if (!IsScheduledDay(profile.ScheduleDays, now))
                    {
                        continue;
                    }

                    if (!TimeMatches(profile.ScheduleTime, now))
                    {
                        continue;
                    }

                    var slotKey = $"{now:yyyy-MM-dd}|{profile.ScheduleTime}";
                    if (_lastFired.TryGetValue(profile.Id, out var last) && last == slotKey)
                    {
                        continue;
                    }

                    _lastFired[profile.Id] = slotKey;
                    _onTrigger(profile);
                }
            }
        }

        public static bool IsScheduledDay(string scheduleDays, DateTime now)
        {
            if (string.IsNullOrWhiteSpace(scheduleDays))
            {
                return true;
            }

            var dayIndex = ((int)now.DayOfWeek).ToString(CultureInfo.InvariantCulture);
            var tokens = scheduleDays.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            return tokens.Any(t => t.Equals(dayIndex, StringComparison.OrdinalIgnoreCase));
        }

        public static bool TimeMatches(string scheduleTime, DateTime now)
        {
            if (string.IsNullOrWhiteSpace(scheduleTime))
            {
                return false;
            }

            if (!TimeSpan.TryParse(scheduleTime, CultureInfo.InvariantCulture, out var target))
            {
                return false;
            }

            var current = now.TimeOfDay;
            // 30 sn'lik timer hedef dakikanın içinde en az bir kez denk gelir; erken tetiklenmez.
            // Aynı gün tekrar çalışmayı _lastFired engeller.
            var diff = (current - target).TotalMinutes;
            return diff >= 0 && diff < 1.0;
        }

        public void Dispose()
        {
            _timer.Dispose();
        }
    }
}

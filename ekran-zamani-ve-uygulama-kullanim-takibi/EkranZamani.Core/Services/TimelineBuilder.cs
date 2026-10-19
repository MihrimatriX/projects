using System;
using System.Collections.Generic;
using System.Linq;
using EkranZamani.Helpers;
using EkranZamani.Models;

namespace EkranZamani.Services
{
    public static class TimelineBuilder
    {
        private const int MergeGapSeconds = 120;
        private const int MinSegmentSeconds = 15;
        private const int IdleGapSeconds = 300;

        public static List<TimelineSegment> Build(
            IEnumerable<UsageRecord> records,
            Func<string, UsageCategory> categorize,
            int daysAgo = 0)
        {
            var dayStart = DateTime.Today.AddDays(-daysAgo);
            var dayEnd = dayStart.AddDays(1);
            const double daySeconds = 86400.0;
            var parsed = records
                .Select(r => new ParsedRecord(
                    r.ProcessName,
                    ParseDateTime(r.StartTime),
                    ParseDateTime(r.EndTime),
                    r.DurationSeconds))
                .Where(r => r.Start != default && r.Duration > 0)
                .OrderBy(r => r.Start)
                .ToList();

            if (parsed.Count == 0)
                return new List<TimelineSegment>();

            var merged = new List<ParsedRecord>();
            foreach (var current in parsed)
            {
                if (merged.Count == 0)
                {
                    merged.Add(current);
                    continue;
                }

                var last = merged[^1];
                bool sameApp = string.Equals(last.ProcessName, current.ProcessName, StringComparison.OrdinalIgnoreCase);
                bool closeInTime = (current.Start - last.End).TotalSeconds <= MergeGapSeconds;

                if (sameApp && closeInTime)
                {
                    merged[^1] = last with
                    {
                        End = current.End,
                        Duration = last.Duration + current.Duration
                    };
                }
                else
                {
                    merged.Add(current);
                }
            }

            var filtered = merged.Where(m => m.Duration >= MinSegmentSeconds).ToList();
            if (filtered.Count == 0)
                filtered = merged;

            var timeline = new List<ParsedRecord>();
            for (int i = 0; i < filtered.Count; i++)
            {
                if (i > 0)
                {
                    var gapSec = (int)(filtered[i].Start - filtered[i - 1].End).TotalSeconds;
                    if (gapSec >= IdleGapSeconds)
                    {
                        timeline.Add(new ParsedRecord(
                            "Boşta",
                            filtered[i - 1].End,
                            filtered[i].Start,
                            gapSec));
                    }
                }
                timeline.Add(filtered[i]);
            }

            int totalSeconds = timeline.Sum(m => m.Duration);
            if (totalSeconds <= 0)
                return new List<TimelineSegment>();

            return timeline.Select(m =>
            {
                bool idle = string.Equals(m.ProcessName, "Boşta", StringComparison.OrdinalIgnoreCase);
                var category = idle ? UsageCategory.Neutral : categorize(m.ProcessName);
                var displayName = idle ? "Boşta" : ProcessDisplayNames.GetFriendlyName(m.ProcessName);
                var clipStart = m.Start < dayStart ? dayStart : m.Start;
                var clipEnd = m.End > dayEnd ? dayEnd : m.End;
                var clipDuration = Math.Max(0, (int)(clipEnd - clipStart).TotalSeconds);
                var leftPercent = Math.Clamp((clipStart - dayStart).TotalSeconds / daySeconds * 100.0, 0, 100);
                var widthPercent = Math.Clamp(clipDuration / daySeconds * 100.0, 0.15, 100 - leftPercent);
                return new TimelineSegment
                {
                    ProcessName = displayName,
                    DurationSeconds = m.Duration,
                    WidthWeight = (double)m.Duration / totalSeconds,
                    LeftPercent = leftPercent,
                    WidthPercent = widthPercent,
                    IsIdle = idle,
                    Category = category,
                    SegmentColorHex = idle ? CategoryColorHelper.IdleHex : CategoryColorHelper.ToHex(category),
                    ToolTipText = idle
                        ? $"Boşta · {FormatDuration(m.Duration)}"
                        : $"{displayName} · {FormatDuration(m.Duration)} · {CategoryService.GetLabel(category)}"
                };
            }).ToList();
        }

        private static DateTime ParseDateTime(string value)
        {
            if (DateTime.TryParse(value, out var dt))
                return dt;
            return default;
        }

        private static string FormatDuration(int seconds)
        {
            var t = TimeSpan.FromSeconds(seconds);
            if (t.TotalHours >= 1)
                return $"{(int)t.TotalHours} sa {t.Minutes} dk";
            if (t.TotalMinutes >= 1)
                return $"{t.Minutes} dk";
            return $"{t.Seconds} sn";
        }

        private sealed record ParsedRecord(string ProcessName, DateTime Start, DateTime End, int Duration);
    }
}

using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Text.Json;

namespace OtomasyonMakro.Models
{
    public class MacroProfile
    {
        public const string FocusOnlyTarget = "*";

        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string Hotkey { get; set; } = string.Empty;
        public string TargetProcessName { get; set; } = FocusOnlyTarget;

        public int SchemaVersion { get; set; } = 2;

        public bool ScheduleEnabled { get; set; }
        public string ScheduleTime { get; set; } = "09:00";
        public string ScheduleDays { get; set; } = "1,2,3,4,5";

        /// <summary>Kaç tur oynatılacağı; 0 = acil durdurmaya (ESC) kadar tekrar.</summary>
        public int RepeatCount { get; set; } = 1;

        public ObservableCollection<MacroStep> Steps { get; set; } = new();

        public bool IsSafetyLockEnabled =>
            !string.IsNullOrWhiteSpace(TargetProcessName);

        public string SafeModeHint => TargetProcessName == FocusOnlyTarget
            ? "Güvenli mod: yalnızca odaklı pencerede çalışır"
            : IsSafetyLockEnabled
                ? $"Güvenli mod: hedef süreç «{TargetProcessName}»"
                : "Uyarı: tüm pencerelerde çalışır — dikkatli kullanın";

        /// <summary>
        /// Adımları 1..N olarak yeniden numaralar ve koşul/atlama hedeflerini taşınan adımı izleyecek şekilde
        /// günceller. Hedef adım silinmişse hedef 0 olur (atlama yapılmaz) — yanlış adıma atlamaz.
        /// </summary>
        public void RenumberSteps()
        {
            var newSeq = new Dictionary<int, int>();
            for (int i = 0; i < Steps.Count; i++)
                if (Steps[i].Sequence > 0) newSeq.TryAdd(Steps[i].Sequence, i + 1);

            foreach (var step in Steps)
            {
                if (step.ActionType is MacroActionType.IfWindowTitle or MacroActionType.JumpToStep)
                    step.JumpToSequence = newSeq.TryGetValue(step.JumpToSequence, out var target) ? target : 0;
            }

            for (int i = 0; i < Steps.Count; i++)
                Steps[i].Sequence = i + 1;
        }

        public MacroProfile Clone() =>
            JsonSerializer.Deserialize<MacroProfile>(JsonSerializer.Serialize(this))!;

        /// <summary>Kaydedilmemiş değişiklik kontrolü için içerik özeti (boş hedef süreç = "*" sayılır).</summary>
        public static string Snapshot(IEnumerable<MacroProfile> profiles) =>
            JsonSerializer.Serialize(profiles.Select(p =>
            {
                var c = p.Clone();
                if (string.IsNullOrWhiteSpace(c.TargetProcessName)) c.TargetProcessName = FocusOnlyTarget;
                c.SchemaVersion = 2;
                return c;
            }));

        public string ScheduleDisplayText => ScheduleEnabled
            ? $"Zamanlayıcı: {ScheduleTime} ({ScheduleDays})"
            : "Zamanlayıcı kapalı";
    }
}

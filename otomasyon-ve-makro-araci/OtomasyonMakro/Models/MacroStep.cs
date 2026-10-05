using System;

namespace OtomasyonMakro.Models
{
    public enum MacroActionType
    {
        MouseClick = 0,
        KeyPress = 1,
        TextDelay = 2,
        WriteText = 3,
        UiElementClick = 4,
        IfWindowTitle = 5,
        JumpToStep = 6
    }

    public class MacroStep
    {
        public int Sequence { get; set; }
        public MacroActionType ActionType { get; set; }
        public int MouseX { get; set; }
        public int MouseY { get; set; }
        public string? Text { get; set; }
        public int DelayMs { get; set; }

        public string? UiElementName { get; set; }
        public string? UiAutomationId { get; set; }
        public string? UiClassName { get; set; }
        public int JumpToSequence { get; set; }

        public string StepTitle => ActionType switch
        {
            MacroActionType.MouseClick => "Tıkla (koordinat)",
            MacroActionType.KeyPress => "Tuş bas",
            MacroActionType.TextDelay => "Bekle",
            MacroActionType.WriteText => "Metin yaz",
            MacroActionType.UiElementClick => "Tıkla (UI element)",
            MacroActionType.IfWindowTitle => "Koşul: pencere başlığı",
            MacroActionType.JumpToStep => "Atla",
            _ => "Bilinmeyen adım"
        };

        public string StepDetail => ActionType switch
        {
            MacroActionType.MouseClick => $"({MouseX}, {MouseY})",
            MacroActionType.KeyPress => Text ?? "",
            MacroActionType.TextDelay => $"{DelayMs} ms",
            MacroActionType.WriteText => $"\"{Text}\"",
            MacroActionType.UiElementClick => BuildUiDetail(),
            MacroActionType.IfWindowTitle => $"\"{Text}\" → #{JumpToSequence}",
            MacroActionType.JumpToStep => $"→ adım {JumpToSequence}",
            _ => ""
        };

        public string DelayLabel => DelayMs > 0 && ActionType != MacroActionType.TextDelay
            ? $"+{DelayMs} ms"
            : "";

        public string DetailTargetType => ActionType switch
        {
            MacroActionType.MouseClick => "Koordinat",
            MacroActionType.KeyPress => "Klavye · Tuş",
            MacroActionType.TextDelay => "Gecikme",
            MacroActionType.WriteText => "Klavye · Metin",
            MacroActionType.UiElementClick => "UIAutomation · Button",
            MacroActionType.IfWindowTitle => "Koşul · Pencere",
            MacroActionType.JumpToStep => "Akış · Atlama",
            _ => "—"
        };

        public string DetailTargetName => ActionType switch
        {
            MacroActionType.MouseClick => $"({MouseX}, {MouseY})",
            MacroActionType.KeyPress or MacroActionType.WriteText or MacroActionType.IfWindowTitle => Text ?? "",
            MacroActionType.TextDelay => $"{DelayMs} ms",
            MacroActionType.UiElementClick => $"{UiElementName ?? "—"} / {UiAutomationId ?? "—"}",
            MacroActionType.JumpToStep => $"Adım {JumpToSequence}",
            _ => ""
        };

        public bool IsRisky =>
            ActionType == MacroActionType.WriteText ||
            ActionType == MacroActionType.UiElementClick ||
            (ActionType == MacroActionType.KeyPress && IsRiskyKey(Text));

        private string BuildUiDetail()
        {
            var name = UiElementName ?? "—";
            var id = UiAutomationId ?? "—";
            return $"\"{name}\" · AutomationId={id}";
        }

        private static bool IsRiskyKey(string? text)
        {
            if (string.IsNullOrWhiteSpace(text)) return false;
            var key = text.Trim().ToUpperInvariant();
            return key is "ENTER" or "RETURN" or "DELETE" or "BACK" or "BACKSPACE" or "TAB";
        }
    }
}

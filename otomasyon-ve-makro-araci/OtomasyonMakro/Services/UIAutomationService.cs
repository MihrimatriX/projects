using System;
using System.Linq;
using FlaUI.Core.AutomationElements;
using FlaUI.UIA3;
using OtomasyonMakro.Models;

namespace OtomasyonMakro.Services
{
    public class UIAutomationService : IDisposable
    {
        private readonly UIA3Automation _automation = new();

        public UiElementInfo? PickElementAt(int x, int y)
        {
            AutomationElement? element;
            try
            {
                element = _automation.FromPoint(new System.Drawing.Point(x, y));
            }
            catch
            {
                return null;
            }

            if (element == null)
            {
                return null;
            }

            return new UiElementInfo
            {
                Name = element.Name ?? string.Empty,
                AutomationId = element.AutomationId ?? string.Empty,
                ClassName = element.ClassName ?? string.Empty
            };
        }

        public void ClickElement(string? name, string? automationId, string? className)
        {
            var foreground = GetForegroundWindowElement();
            if (foreground == null)
            {
                throw new InvalidOperationException("UIAutomation: Odaklanmış pencere bulunamadı.");
            }

            var target = FindElement(foreground, name, automationId, className);
            if (target == null)
            {
                throw new InvalidOperationException(
                    $"UIAutomation: Öğe bulunamadı (Ad='{name}', Id='{automationId}', Sınıf='{className}').");
            }

            if (target.Patterns.Invoke.IsSupported)
            {
                target.Patterns.Invoke.Pattern.Invoke();
                return;
            }

            var rect = target.BoundingRectangle;
            if (rect.IsEmpty)
            {
                throw new InvalidOperationException("UIAutomation: Öğe tıklanabilir sınır kutusu yok.");
            }

            int cx = (int)(rect.X + rect.Width / 2);
            int cy = (int)(rect.Y + rect.Height / 2);
            Helpers.Win32Api.SetCursorPos(cx, cy);
            System.Threading.Thread.Sleep(50);
            Helpers.Win32Api.mouse_event(
                Helpers.Win32Api.MOUSEEVENTF_LEFTDOWN | Helpers.Win32Api.MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
        }

        private AutomationElement? GetForegroundWindowElement()
        {
            IntPtr hwnd = Helpers.Win32Api.GetForegroundWindow();
            if (hwnd == IntPtr.Zero)
            {
                return null;
            }

            return _automation.FromHandle(hwnd);
        }

        private static AutomationElement? FindElement(
            AutomationElement root,
            string? name,
            string? automationId,
            string? className)
        {
            var candidates = root.FindAllDescendants();

            AutomationElement? best = null;
            int bestScore = -1;

            foreach (var el in candidates)
            {
                int score = 0;
                if (!string.IsNullOrWhiteSpace(automationId) &&
                    string.Equals(el.AutomationId, automationId, StringComparison.OrdinalIgnoreCase))
                {
                    score += 4;
                }

                if (!string.IsNullOrWhiteSpace(name) &&
                    string.Equals(el.Name, name, StringComparison.OrdinalIgnoreCase))
                {
                    score += 3;
                }

                if (!string.IsNullOrWhiteSpace(className) &&
                    string.Equals(el.ClassName, className, StringComparison.OrdinalIgnoreCase))
                {
                    score += 2;
                }

                if (score > bestScore)
                {
                    bestScore = score;
                    best = el;
                }
            }

            if (bestScore <= 0)
            {
                return null;
            }

            return best;
        }

        public void Dispose()
        {
            _automation.Dispose();
        }
    }
}

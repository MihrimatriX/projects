using System;
using System.Text.RegularExpressions;

namespace ClipboardYoneticisi.Helpers
{
    public static partial class SensitiveContentDetector
    {
        [GeneratedRegex(@"(?i)(password|parola|şifre|cvv|cvc|pin\s*code|secret|token|api[_-]?key)", RegexOptions.Compiled)]
        private static partial Regex SensitiveKeywordRegex();

        [GeneratedRegex(@"\b(?:\d[ -]*?){13,16}\b", RegexOptions.Compiled)]
        private static partial Regex CardNumberRegex();

        public static bool LooksSensitive(string? text)
        {
            if (string.IsNullOrWhiteSpace(text))
                return false;

            if (SensitiveKeywordRegex().IsMatch(text))
                return true;

            return CardNumberRegex().IsMatch(text);
        }

        public static string Blur(string text) =>
            new string('•', Math.Min(text.Length, 12));
    }
}

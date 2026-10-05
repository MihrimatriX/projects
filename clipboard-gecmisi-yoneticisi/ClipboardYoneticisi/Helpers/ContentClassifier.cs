using System.Linq;
using System.Text.RegularExpressions;

namespace ClipboardYoneticisi.Helpers
{
    public enum TextCategory
    {
        Plain,
        Url,
        Email,
        Code
    }

    public static class ContentClassifier
    {
        private static readonly Regex UrlRegex = new(
            @"^https?://[^\s]+$",
            RegexOptions.IgnoreCase | RegexOptions.Compiled);

        private static readonly Regex EmailRegex = new(
            @"^[^\s@]+@[^\s@]+\.[^\s@]+$",
            RegexOptions.Compiled);

        public static TextCategory Classify(string text)
        {
            if (string.IsNullOrWhiteSpace(text))
                return TextCategory.Plain;

            var trimmed = text.Trim();

            if (UrlRegex.IsMatch(trimmed))
                return TextCategory.Url;

            if (EmailRegex.IsMatch(trimmed))
                return TextCategory.Email;

            if (LooksLikeCode(trimmed))
                return TextCategory.Code;

            return TextCategory.Plain;
        }

        private static bool LooksLikeCode(string text)
        {
            if (text.Contains('{') && text.Contains('}'))
                return true;

            if (text.Contains("function ") || text.Contains("const ") || text.Contains("=>"))
                return true;

            if (text.Contains("def ") || text.Contains("class ") || text.Contains("import "))
                return true;

            if (text.Contains("public ") && text.Contains("void "))
                return true;

            if (text.StartsWith("#include") || text.Contains("<?php"))
                return true;

            var lines = text.Split('\n');
            if (lines.Length >= 3 &&
                lines.All(line => line.StartsWith("    ") || line.StartsWith('\t')))
            {
                return true;
            }

            return false;
        }
    }
}

using System;
using System.Linq;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace ClipboardYoneticisi.Helpers
{
    public enum TransformType
    {
        None,
        Lowercase,
        Uppercase,
        Trim,
        JsonPretty,
        MarkdownLink,
        RemoveLineBreaks
    }

    public static class SnippetTransform
    {
        public static string Apply(string input, TransformType type)
        {
            return type switch
            {
                TransformType.Lowercase => input.ToLowerInvariant(),
                TransformType.Uppercase => input.ToUpperInvariant(),
                TransformType.Trim => input.Trim(),
                TransformType.JsonPretty => PrettyJson(input),
                TransformType.MarkdownLink => ToMarkdownLink(input),
                TransformType.RemoveLineBreaks => input.Replace("\r", " ").Replace("\n", " ").Trim(),
                _ => input
            };
        }

        public static bool CanTransform(string type) =>
            type is "Text" or "Html";

        private static string PrettyJson(string input)
        {
            try
            {
                using var doc = JsonDocument.Parse(input);
                return JsonSerializer.Serialize(doc, new JsonSerializerOptions { WriteIndented = true });
            }
            catch
            {
                return input;
            }
        }

        private static string ToMarkdownLink(string input)
        {
            var trimmed = input.Trim();
            if (Regex.IsMatch(trimmed, @"^https?://", RegexOptions.IgnoreCase))
                return $"[{trimmed}]({trimmed})";
            return trimmed;
        }
    }
}

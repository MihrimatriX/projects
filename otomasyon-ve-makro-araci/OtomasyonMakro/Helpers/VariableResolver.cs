using System;
using System.Text.RegularExpressions;
using System.Windows;

namespace OtomasyonMakro.Helpers
{
    public static partial class VariableResolver
    {
        [GeneratedRegex(@"\{\{([^}]+)\}\}", RegexOptions.Compiled)]
        private static partial Regex TokenRegex();

        public static string Expand(string? input)
        {
            if (string.IsNullOrEmpty(input))
            {
                return input ?? string.Empty;
            }

            return TokenRegex().Replace(input, match => EvaluateToken(match.Groups[1].Value.Trim()));
        }

        private static string EvaluateToken(string token)
        {
            if (token.Equals("clipboard", StringComparison.OrdinalIgnoreCase))
            {
                try
                {
                    return Clipboard.ContainsText() ? Clipboard.GetText() : string.Empty;
                }
                catch
                {
                    return string.Empty;
                }
            }

            if (token.StartsWith("env:", StringComparison.OrdinalIgnoreCase))
            {
                var name = token[4..];
                return Environment.GetEnvironmentVariable(name) ?? string.Empty;
            }

            return token.ToLowerInvariant() switch
            {
                "date" => DateTime.Now.ToString("yyyy-MM-dd"),
                "time" => DateTime.Now.ToString("HH:mm:ss"),
                "datetime" => DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"),
                "user" => Environment.UserName,
                _ => "{{" + token + "}}"
            };
        }
    }
}
